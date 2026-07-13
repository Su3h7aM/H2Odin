package h2odin

import "core:fmt"
import "core:strings"

// Scratch plan resolved against C names before renaming and consumed
// immediately afterward to create the arena-owned Wrapper_Decl.
Wrapper_Plan :: struct {
	c_name:              string, // C spelling (config key); for @(link_name) when hiding
	rule:                Wrapper_Rule, // config rule (not owned; lives on Policy)
	out_param_indices:   []int, // same order as rule.out_params
	slice_param_indices: [][2]int, // [pointer_index, count_index] per slice rule
}

// Phase 1: C names still on funcs. The returned plans and their index slices
// are temporary and remain valid until materialization in transform.
resolve_wrapper_plans :: proc(ir: ^IR, policy: ^Policy, type_mode: Type_Mode) -> map[u32]Wrapper_Plan {
	plans: map[u32]Wrapper_Plan
	if type_mode != .Idiomatic || policy.proc_wrappers == nil || len(policy.proc_wrappers) == 0 {
		return plans
	}
	plans = make(map[u32]Wrapper_Plan, context.temp_allocator)

	function_by_c_name := make(map[string]u32, context.temp_allocator)
	for ref in ir.order {
		if ref.kind != .Func {
			continue
		}
		function := ir.funcs[ref.index]
		if function.name != "" {
			function_by_c_name[function.name] = ref.index
		}
	}

	for c_name, rule in policy.proc_wrappers {
		function_index, found := function_by_c_name[c_name]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: no live procedure with that C name", c_name)
			continue
		}
		function := &ir.funcs[function_index]
		plan, plan_ok := plan_wrapper_for_function(ir, function, rule, c_name)
		if !plan_ok {
			continue
		}
		plan.c_name = c_name
		plans[function_index] = plan
	}
	return plans
}

// Phase 2: after renames — public names final; insert Wrapper_Decl and hide foreign.
materialize_wrapper_plans :: proc(ir: ^IR, plans: map[u32]Wrapper_Plan) {
	if len(plans) == 0 {
		return
	}

	// Build new order with wrappers inserted immediately after their targets.
	ordered_declarations := make([dynamic]Decl_Ref, 0, len(ir.order) + len(plans), context.temp_allocator)

	for ref in ir.order {
		append(&ordered_declarations, ref)
		if ref.kind != .Func {
			continue
		}
		plan, found := plans[ref.index]
		if !found {
			continue
		}
		target_function := &ir.funcs[ref.index]
		public_name := target_function.name
		// Hide faithful foreign under a non-colliding internal name.
		internal_name := strings.clone(fmt.tprintf("_%s", public_name))
		// Always bind the real C symbol after the public name moves to the wrapper.
		if target_function.link_name == "" {
			target_function.link_name = strings.clone(plan.c_name)
		}
		target_function.name = internal_name

		// Build out_params with final param names as result names.
		out_params := make([]Wrapper_Out_Param, len(plan.out_param_indices))
		for parameter_index, result_index in plan.out_param_indices {
			parameter_name := target_function.params[parameter_index].name
			if parameter_name == "" {
				parameter_name = fmt.tprintf("out_%d", result_index)
			}
			out_params[result_index] = Wrapper_Out_Param {
				param_index = parameter_index,
				result_name = strings.clone(parameter_name),
			}
		}
		slices := make([]Wrapper_Slice, len(plan.slice_param_indices))
		for parameter_indices, slice_index in plan.slice_param_indices {
			public_slice_name := ""
			if slice_index < len(plan.rule.slices) {
				public_slice_name = plan.rule.slices[slice_index].name
			}
			if public_slice_name == "" {
				public_slice_name = target_function.params[parameter_indices[0]].name
			}
			if public_slice_name == "" {
				public_slice_name = "data"
			}
			slices[slice_index] = Wrapper_Slice {
				pointer_index = parameter_indices[0],
				count_index   = parameter_indices[1],
				public_name   = strings.clone(public_slice_name),
			}
		}

		// require_results on multi-result wrappers (vendor:cgltf style).
		require_results := len(out_params) > 0 || (plan.rule.keep_c_return && !type_is_void(ir, target_function.return_type))
		// Also honor foreign require_results intent.
		if target_function.require_results {
			require_results = true
		}

		wrapper := Wrapper_Decl {
			name            = strings.clone(public_name),
			target          = Decl_Handle(ref.index),
			home            = target_function.home,
			require_results = require_results,
			out_params      = out_params,
			slices          = slices,
			keep_c_return   = plan.rule.keep_c_return,
			doc             = target_function.doc,
		}
		wrapper_handle := ir_add_wrapper(ir, wrapper)
		append(&ordered_declarations, Decl_Ref{kind = .Wrapper, index = u32(wrapper_handle)})
	}

	clear(&ir.order)
	for ref in ordered_declarations {
		append(&ir.order, ref)
	}
}

plan_wrapper_for_function :: proc(ir: ^IR, function: ^Func_Decl, rule: Wrapper_Rule, c_name: string) -> (Wrapper_Plan, bool) {
	if function.is_variadic {
		ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: variadic procedures cannot have wrappers", c_name)
		return {}, false
	}

	// Param name → index (C names still).
	parameter_by_name := make(map[string]int, context.temp_allocator)
	for parameter, parameter_index in function.params {
		if parameter.name != "" {
			parameter_by_name[parameter.name] = parameter_index
		}
	}

	out_param_indices := make([dynamic]int, context.temp_allocator)
	used_parameters := make(map[int]bool, context.temp_allocator)

	for parameter_name in rule.out_params {
		parameter_index, found := parameter_by_name[parameter_name]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params names unknown parameter %q", c_name, parameter_name)
			return {}, false
		}
		if used_parameters[parameter_index] {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: parameter %q used more than once", c_name, parameter_name)
			return {}, false
		}
		if !parameter_is_single_data_pointer(ir, function.params[parameter_index]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params %q must be a single data pointer (^T), not multipointer", c_name, parameter_name)
			return {}, false
		}
		if function.params[parameter_index].by_ptr {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params %q cannot be #by_ptr (call-borrowed input)", c_name, parameter_name)
			return {}, false
		}
		used_parameters[parameter_index] = true
		append(&out_param_indices, parameter_index)
	}

	slice_param_indices := make([dynamic][2]int, context.temp_allocator)
	for slice_rule in rule.slices {
		pointer_index, pointer_found := parameter_by_name[slice_rule.pointer]
		count_index, count_found := parameter_by_name[slice_rule.count]
		if !pointer_found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.pointer unknown parameter %q", c_name, slice_rule.pointer)
			return {}, false
		}
		if !count_found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.count unknown parameter %q", c_name, slice_rule.count)
			return {}, false
		}
		if used_parameters[pointer_index] || used_parameters[count_index] {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slice parameters overlap out_params or another slice", c_name)
			return {}, false
		}
		if !parameter_is_data_pointer_for_slice(ir, function.params[pointer_index]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.pointer %q must be a data pointer", c_name, slice_rule.pointer)
			return {}, false
		}
		if !parameter_is_integer_like(ir, function.params[count_index]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.count %q must be an integer type", c_name, slice_rule.count)
			return {}, false
		}
		used_parameters[pointer_index] = true
		used_parameters[count_index] = true
		append(&slice_param_indices, [2]int{pointer_index, count_index})
	}

	return Wrapper_Plan{rule = rule, out_param_indices = out_param_indices[:], slice_param_indices = slice_param_indices[:]}, true
}

parameter_is_single_data_pointer :: proc(ir: ^IR, parameter: Param) -> bool {
	if parameter.type_spelling != "" {
		// Explicit spelling: allow if it looks like a pointer; conservative.
		return strings.has_prefix(parameter.type_spelling, "^") || strings.has_prefix(parameter.type_spelling, "[^]")
	}
	lowered, ok := ir_type(ir, parameter.type).variant.(Type_Lowered_Pointer)
	return ok && lowered.kind == .Single
}

parameter_is_data_pointer_for_slice :: proc(ir: ^IR, parameter: Param) -> bool {
	if parameter.by_ptr {
		return false
	}
	if parameter.type_spelling != "" {
		return strings.has_prefix(parameter.type_spelling, "^") || strings.has_prefix(parameter.type_spelling, "[^]")
	}
	lowered, ok := ir_type(ir, parameter.type).variant.(Type_Lowered_Pointer)
	return ok && (lowered.kind == .Single || lowered.kind == .Multi)
}

parameter_is_integer_like :: proc(ir: ^IR, parameter: Param) -> bool {
	// Prefer IR type; spelling-only is best-effort.
	if parameter.type_spelling != "" {
		// Common integer spellings.
		spelling := parameter.type_spelling
		if strings.contains(spelling, "int") ||
		   strings.contains(spelling, "size") ||
		   strings.contains(spelling, "i32") ||
		   strings.contains(spelling, "u32") ||
		   strings.contains(spelling, "i64") ||
		   strings.contains(spelling, "u64") ||
		   strings.contains(spelling, "uint") {
			return true
		}
	}
	return type_is_integer_like(ir, parameter.type)
}
