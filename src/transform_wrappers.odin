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
resolve_wrapper_plans :: proc(ir: ^IR, policy: ^Policy, type_mode: Type_Mode) -> map[Decl_Handle]Wrapper_Plan {
	plans: map[Decl_Handle]Wrapper_Plan
	if type_mode != .Idiomatic || policy.proc_wrappers == nil || len(policy.proc_wrappers) == 0 {
		return plans
	}
	plans = make(map[Decl_Handle]Wrapper_Plan, context.temp_allocator)

	function_by_c_name := make(map[string]Decl_Handle, context.temp_allocator)
	for declaration in ir.order {
		if declaration.kind != .Func {
			continue
		}
		function := ir.funcs[declaration.index]
		if function.name != "" {
			function_by_c_name[function.name] = Decl_Handle(declaration.index)
		}
	}

	for c_name, rule in policy.proc_wrappers {
		function_handle, found := function_by_c_name[c_name]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: no live procedure with that C name", c_name)
			continue
		}
		function := ir.funcs[function_handle]
		plan, plan_ok := plan_wrapper_for_function(ir, function, rule, c_name)
		if !plan_ok {
			continue
		}
		plan.c_name = c_name
		plans[function_handle] = plan
	}
	return plans
}

// Phase 2: after renames — public names final; insert Wrapper_Decl and hide foreign.
materialize_wrapper_plans :: proc(ir: ^IR, plans: map[Decl_Handle]Wrapper_Plan) {
	if len(plans) == 0 {
		return
	}

	// Build new order with wrappers inserted immediately after their targets.
	ordered_declarations := make([dynamic]Decl_Ref, 0, len(ir.order) + len(plans), context.temp_allocator)

	for declaration in ir.order {
		append(&ordered_declarations, declaration)
		if declaration.kind != .Func {
			continue
		}
		function_handle := Decl_Handle(declaration.index)
		plan, found := plans[function_handle]
		if !found {
			continue
		}
		wrapper_handle := materialize_wrapper_plan(ir, function_handle, plan)
		append(&ordered_declarations, Decl_Ref{kind = .Wrapper, index = u32(wrapper_handle)})
	}

	clear(&ir.order)
	for declaration in ordered_declarations {
		append(&ir.order, declaration)
	}
}

// Create one arena-owned wrapper from a scratch plan and move the faithful
// foreign procedure behind its internal name.
materialize_wrapper_plan :: proc(ir: ^IR, function_handle: Decl_Handle, plan: Wrapper_Plan) -> Decl_Handle {
	target_function := &ir.funcs[function_handle]
	public_name := target_function.name
	target_function.name = strings.clone(fmt.tprintf("_%s", public_name))
	if target_function.link_name == "" {
		target_function.link_name = strings.clone(plan.c_name)
	}

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
		public_slice_name := plan.rule.slices[slice_index].name
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

	require_results := target_function.require_results || len(out_params) > 0 || (plan.rule.keep_c_return && function_has_result(ir, target_function^))
	wrapper := Wrapper_Decl {
		name            = strings.clone(public_name),
		target          = function_handle,
		home            = target_function.home,
		require_results = require_results,
		out_params      = out_params,
		slices          = slices,
		keep_c_return   = plan.rule.keep_c_return,
		doc             = target_function.doc,
	}
	return ir_add_wrapper(ir, wrapper)
}

plan_wrapper_for_function :: proc(ir: ^IR, function: Func_Decl, rule: Wrapper_Rule, c_name: string) -> (Wrapper_Plan, bool) {
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
	used_parameters := make(map[int]struct{}, context.temp_allocator)

	for parameter_name in rule.out_params {
		parameter_index, found := parameter_by_name[parameter_name]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params names unknown parameter %q", c_name, parameter_name)
			return {}, false
		}
		if parameter_index in used_parameters {
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
		used_parameters[parameter_index] = {}
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
		if pointer_index in used_parameters || count_index in used_parameters {
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
		used_parameters[pointer_index] = {}
		used_parameters[count_index] = {}
		append(&slice_param_indices, [2]int{pointer_index, count_index})
	}

	return Wrapper_Plan{rule = rule, out_param_indices = out_param_indices[:], slice_param_indices = slice_param_indices[:]}, true
}

parameter_is_single_data_pointer :: proc(ir: ^IR, parameter: Param) -> bool {
	if parameter.type_spelling != "" {
		return strings.has_prefix(parameter.type_spelling, "^")
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
	if parameter.type_spelling != "" {
		return known_integer_spelling(parameter.type_spelling)
	}
	return type_is_integer_like(ir, parameter.type)
}

// Configured type spellings replace the structural IR type, so wrapper
// planning accepts only spellings whose integer semantics are known exactly.
known_integer_spelling :: proc(spelling: string) -> bool {
	if builtin_kind, known := builtin_kind_for_abi_spelling(spelling); known {
		return builtin_is_integer(builtin_kind)
	}
	for mapping in std_mappings {
		if mapping.abi == spelling {
			return true
		}
	}
	switch spelling {
	case "int", "uint", "uintptr", "i8", "i16", "i32", "i64", "i128", "u8", "u16", "u32", "u64", "u128":
		return true
	}
	return false
}
