package h2odin

import "core:fmt"
import "core:strings"

// Provisional wrapper plan resolved against C names (before renames).
// Materialized into Wrapper_Decl after renames finalize public names.
Provisional_Wrapper :: struct {
	c_name:        string, // C spelling (config key); for @(link_name) when hiding
	rule:          Wrapper_Rule, // config rule (not owned; lives on Policy)
	out_indices:   []int, // param indices for out_params (same order as rule)
	slice_indices: [][2]int, // [pointer_index, count_index] per slice rule
}

// Phase 1: C names still on funcs. Returns a temp map func_index → provisional.
resolve_wrapper_plans :: proc(ir: ^IR, policy: ^Policy, mode: Type_Mode) -> map[u32]Provisional_Wrapper {
	out: map[u32]Provisional_Wrapper
	if mode != .Idiomatic || policy.proc_wrappers == nil || len(policy.proc_wrappers) == 0 {
		return out
	}
	out = make(map[u32]Provisional_Wrapper, context.temp_allocator)

	by_c_name := make(map[string]u32, context.temp_allocator)
	for ref in ir.order {
		if ref.kind != .Func {
			continue
		}
		fn := ir.funcs[ref.index]
		if fn.name != "" {
			by_c_name[fn.name] = ref.index
		}
	}

	for c_name, rule in policy.proc_wrappers {
		idx, found := by_c_name[c_name]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: no live procedure with that C name", c_name)
			continue
		}
		fn := &ir.funcs[idx]
		prov, plan_ok := plan_wrapper_for_func(ir, fn, rule, c_name)
		if !plan_ok {
			continue
		}
		prov.c_name = c_name
		out[idx] = prov
	}
	return out
}

// Phase 2: after renames — public names final; insert Wrapper_Decl and hide foreign.
materialize_wrapper_plans :: proc(ir: ^IR, policy: ^Policy, provisional: map[u32]Provisional_Wrapper) {
	if len(provisional) == 0 {
		return
	}

	// Build new order with wrappers inserted immediately after their targets.
	new_order: [dynamic]Decl_Ref
	new_order.allocator = context.allocator

	for ref in ir.order {
		append(&new_order, ref)
		if ref.kind != .Func {
			continue
		}
		prov, has := provisional[ref.index]
		if !has {
			continue
		}
		fn := &ir.funcs[ref.index]
		public_name := fn.name
		// Hide faithful foreign under a non-colliding internal name.
		internal := strings.clone(fmt.tprintf("_%s", public_name))
		// Always bind the real C symbol after the public name moves to the wrapper.
		if fn.link_name == "" {
			fn.link_name = strings.clone(prov.c_name)
		}
		fn.name = internal

		// Build out_params with final param names as result names.
		out_params := make([]Wrapper_Out_Param, len(prov.out_indices))
		for pidx, i in prov.out_indices {
			pname := fn.params[pidx].name
			if pname == "" {
				pname = fmt.tprintf("out_%d", i)
			}
			out_params[i] = Wrapper_Out_Param {
				param_index = pidx,
				result_name = strings.clone(pname),
			}
		}
		slices := make([]Wrapper_Slice, len(prov.slice_indices))
		for pair, i in prov.slice_indices {
			pub := ""
			if i < len(prov.rule.slices) {
				pub = prov.rule.slices[i].name
			}
			if pub == "" {
				pub = fn.params[pair[0]].name
			}
			if pub == "" {
				pub = "data"
			}
			slices[i] = Wrapper_Slice {
				pointer_index = pair[0],
				count_index   = pair[1],
				public_name   = strings.clone(pub),
			}
		}

		// require_results on multi-result wrappers (vendor:cgltf style).
		req := len(out_params) > 0 || (prov.rule.keep_c_return && !type_is_void(ir, fn.return_type))
		// Also honor foreign require_results intent.
		if fn.require_results {
			req = true
		}

		w := Wrapper_Decl {
			name            = strings.clone(public_name),
			target          = Decl_Handle(ref.index),
			home            = fn.home,
			require_results = req,
			out_params      = out_params,
			slices          = slices,
			keep_c_return   = prov.rule.keep_c_return,
			doc             = fn.doc,
		}
		wh := ir_add_wrapper(ir, w)
		append(&new_order, Decl_Ref{kind = .Wrapper, index = u32(wh)})
	}

	clear(&ir.order)
	for ref in new_order {
		append(&ir.order, ref)
	}
	delete(new_order)
}

plan_wrapper_for_func :: proc(ir: ^IR, fn: ^Func_Decl, rule: Wrapper_Rule, c_name: string) -> (Provisional_Wrapper, bool) {
	if fn.is_variadic {
		ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: variadic procedures cannot have wrappers", c_name)
		return {}, false
	}

	// Param name → index (C names still).
	by_param := make(map[string]int, context.temp_allocator)
	for p, i in fn.params {
		if p.name != "" {
			by_param[p.name] = i
		}
	}

	out_indices := make([dynamic]int, context.temp_allocator)
	used := make(map[int]bool, context.temp_allocator)

	for pname in rule.out_params {
		idx, found := by_param[pname]
		if !found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params names unknown parameter %q", c_name, pname)
			return {}, false
		}
		if used[idx] {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: parameter %q used more than once", c_name, pname)
			return {}, false
		}
		if !param_is_single_data_pointer(ir, fn.params[idx]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params %q must be a single data pointer (^T), not multipointer", c_name, pname)
			return {}, false
		}
		if fn.params[idx].by_ptr {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: out_params %q cannot be #by_ptr (call-borrowed input)", c_name, pname)
			return {}, false
		}
		used[idx] = true
		append(&out_indices, idx)
	}

	slice_indices := make([dynamic][2]int, context.temp_allocator)
	for sl in rule.slices {
		pi, p_found := by_param[sl.pointer]
		ci, c_found := by_param[sl.count]
		if !p_found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.pointer unknown parameter %q", c_name, sl.pointer)
			return {}, false
		}
		if !c_found {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.count unknown parameter %q", c_name, sl.count)
			return {}, false
		}
		if used[pi] || used[ci] {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slice parameters overlap out_params or another slice", c_name)
			return {}, false
		}
		if !param_is_data_pointer_for_slice(ir, fn.params[pi]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.pointer %q must be a data pointer", c_name, sl.pointer)
			return {}, false
		}
		if !param_is_integer_like(ir, fn.params[ci]) {
			ir_diag(ir, .Wrapper_Plan_Failed, "procs.wrappers[%q]: slices.count %q must be an integer type", c_name, sl.count)
			return {}, false
		}
		used[pi] = true
		used[ci] = true
		append(&slice_indices, [2]int{pi, ci})
	}

	// Own copies of index slices for materialize (temp may be freed? we use
	// context.allocator for the returned slices so they live until materialize
	// in the same transform() call — use allocator, not temp, for indices).
	out_copy := make([]int, len(out_indices))
	for v, i in out_indices {
		out_copy[i] = v
	}
	sl_copy := make([][2]int, len(slice_indices))
	for v, i in slice_indices {
		sl_copy[i] = v
	}

	return Provisional_Wrapper{rule = rule, out_indices = out_copy, slice_indices = sl_copy}, true
}

param_is_single_data_pointer :: proc(ir: ^IR, param: Param) -> bool {
	if param.type_spelling != "" {
		// Explicit spelling: allow if it looks like a pointer; conservative.
		return strings.has_prefix(param.type_spelling, "^") || strings.has_prefix(param.type_spelling, "[^]")
	}
	lowered, ok := ir_type(ir, param.type).variant.(Type_Lowered_Pointer)
	return ok && lowered.kind == .Single
}

param_is_data_pointer_for_slice :: proc(ir: ^IR, param: Param) -> bool {
	if param.by_ptr {
		return false
	}
	if param.type_spelling != "" {
		return strings.has_prefix(param.type_spelling, "^") || strings.has_prefix(param.type_spelling, "[^]")
	}
	lowered, ok := ir_type(ir, param.type).variant.(Type_Lowered_Pointer)
	return ok && (lowered.kind == .Single || lowered.kind == .Multi)
}

param_is_integer_like :: proc(ir: ^IR, param: Param) -> bool {
	// Prefer IR type; spelling-only is best-effort.
	if param.type_spelling != "" {
		// Common integer spellings.
		s := param.type_spelling
		if strings.contains(s, "int") ||
		   strings.contains(s, "size") ||
		   strings.contains(s, "i32") ||
		   strings.contains(s, "u32") ||
		   strings.contains(s, "i64") ||
		   strings.contains(s, "u64") ||
		   strings.contains(s, "uint") {
			return true
		}
	}
	return type_is_integer_like(ir, param.type)
}
