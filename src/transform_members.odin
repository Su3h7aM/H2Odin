package h2odin

import "core:fmt"

// Apply configured field and alignment decisions while declarations still
// carry their C names. A callback refines the matching declarative field
// action; the combined action is applied once so stale partial state cannot
// survive a stronger callback decision.
apply_struct_adjustments :: proc(ir: ^IR, policy: ^Policy) {
	has_field_actions := len(policy.struct_fields) > 0
	has_field_callback := policy.has_struct_field
	has_alignment_overrides := len(policy.struct_align) > 0
	if !has_field_actions && !has_field_callback && !has_alignment_overrides {
		return
	}
	for &record in ir.records {
		if record.name == "" {
			continue
		}
		if has_alignment_overrides {
			if alignment, found := policy.struct_align[record.name]; found {
				record.align = alignment
			}
		}
		if !has_field_actions && !has_field_callback {
			continue
		}
		for &field in record.fields {
			if field.name == "" {
				continue
			}

			action: Member_Action
			has_action := false
			if has_field_actions {
				key := fmt.tprintf("%s.%s", record.name, field.name)
				if configured_action, found := policy.struct_fields[key]; found {
					action = configured_action
					has_action = true
				}
			}
			if has_field_callback {
				view_type := type_name_for_policy_view(ir, field.type)
				if refinement, decided := policy_struct_field_action(policy, record.name, field.name, view_type); decided {
					action = refine_member_action(action, refinement)
					has_action = true
				}
			}
			if has_action {
				apply_field_action(&field, action)
			}
		}
	}
}

// Overlay non-empty decisions. Member_Action uses empty values for "unset",
// so callback fields that are absent leave declarative fields intact.
refine_member_action :: proc(base, refinement: Member_Action) -> Member_Action {
	result := base
	// Type spelling, pointer shape, and #by_ptr are alternative ways to
	// decide a parameter's emitted type. When a callback supplies any one of
	// them, replace the declarative shape group as a unit. If the callback
	// itself supplies conflicting members, retain them so normal validation
	// can report that conflict.
	if refinement.type != "" || refinement.pointer != "" || refinement.by_ptr {
		result.type = ""
		result.pointer = ""
		result.by_ptr = false
	}
	if refinement.type != "" {
		result.type = refinement.type
	}
	if refinement.tag != "" {
		result.tag = refinement.tag
	}
	if refinement.default != "" {
		result.default = refinement.default
	}
	if refinement.pointer != "" {
		result.pointer = refinement.pointer
	}
	if refinement.by_ptr {
		result.by_ptr = true
	}
	return result
}

apply_field_action :: proc(field: ^Field, action: Member_Action) {
	if action.type != "" {
		field.type_spelling = action.type
	}
	if action.tag != "" {
		field.tag = action.tag
	}
}

// Apply configured parameter, result, and require-results decisions. Callback
// actions refine declarative actions before either mutates the IR.
apply_proc_adjustments :: proc(ir: ^IR, policy: ^Policy, type_mode: Type_Mode = .ABI) {
	has_parameter_actions := len(policy.proc_params) > 0
	has_parameter_callback := policy.has_proc_param
	has_result_actions := len(policy.proc_results) > 0
	has_result_callback := policy.has_proc_result
	has_required_results := len(policy.require_results) > 0
	if !has_parameter_actions && !has_parameter_callback && !has_result_actions && !has_result_callback && !has_required_results {
		return
	}
	required_result_names: map[string]struct{}
	if has_required_results {
		required_result_names = make(map[string]struct{}, context.temp_allocator)
		for name in policy.require_results {
			required_result_names[name] = {}
		}
	}
	for &function in ir.funcs {
		if has_parameter_actions || has_parameter_callback {
			for &parameter in function.params {
				parameter_name := parameter.name if parameter.name != "" else "_"
				action: Member_Action
				has_action := false
				if has_parameter_actions {
					key := fmt.tprintf("%s.%s", function.name, parameter_name)
					if configured_action, found := policy.proc_params[key]; found {
						action = configured_action
						has_action = true
					}
				}
				if has_parameter_callback {
					view_type := type_name_for_policy_view(ir, parameter.type)
					if refinement, decided := policy_proc_param_action(policy, function.name, parameter.name, view_type); decided {
						action = refine_member_action(action, refinement)
						has_action = true
					}
				}
				if has_action {
					apply_parameter_action(&parameter, action, ir, type_mode, function.name)
				}
			}
		}

		if has_result_actions || has_result_callback {
			action: Member_Action
			has_action := false
			if has_result_actions {
				if configured_action, found := policy.proc_results[function.name]; found {
					action = configured_action
					has_action = true
				}
			}
			if has_result_callback {
				view_type := type_name_for_policy_view(ir, function.return_type)
				if refinement, decided := policy_proc_result_action(policy, function.name, view_type); decided {
					action = refine_member_action(action, refinement)
					has_action = true
				}
			}
			if has_action && action.type != "" {
				function.return_type_spelling = action.type
			}
		}

		// Match on C name before renames (this pass runs before naming).
		if has_required_results && function.name in required_result_names {
			function.require_results = true
		}
	}
}

apply_parameter_action :: proc(parameter: ^Param, action: Member_Action, ir: ^IR, type_mode: Type_Mode = .ABI, function_name: string = "") {
	if action.type != "" {
		parameter.type_spelling = action.type
	}
	if action.default != "" {
		parameter.default = action.default
	}
	// pointer = "multi" rewrites the lowered type when the user did not
	// supply a full type spelling (that spelling is authoritative).
	if action.pointer == "multi" && parameter.type_spelling == "" {
		if !force_multi_pointer(ir, parameter.type, .Configured_Multi) {
			// Soft: leave ^T (or other lowering) and note why multi failed.
			ir_diag(
				ir,
				.Pointer_Lowering_Guess,
				"procs.params pointer = \"multi\" ignored for parameter %q: type is not a single data pointer",
				parameter.name if parameter.name != "" else "_",
			)
		}
	}
	if action.by_ptr {
		apply_parameter_by_pointer(ir, parameter, type_mode, function_name)
	}
}

// Idiomatic-only #by_ptr: peels one single-pointer level at emission.
// Never inferred from C const; explicit policy only.
apply_parameter_by_pointer :: proc(ir: ^IR, parameter: ^Param, type_mode: Type_Mode, function_name: string) {
	parameter_name := parameter.name if parameter.name != "" else "_"
	scope := fmt.tprintf("%s.%s", function_name, parameter_name) if function_name != "" else parameter_name
	if type_mode != .Idiomatic {
		ir_diag(ir, .Pointer_Lowering_Guess, "procs.params by_ptr ignored for %s: #by_ptr is idiomatic-only (type_mode = \"idiomatic\")", scope)
		return
	}
	if parameter.type_spelling != "" {
		ir_diag(ir, .Pointer_Lowering_Guess, "procs.params by_ptr ignored for %s: cannot combine with an explicit type spelling", scope)
		return
	}
	lowered_pointer, is_pointer := ir_type(ir, parameter.type).variant.(Type_Lowered_Pointer)
	if !is_pointer || lowered_pointer.kind != .Single {
		ir_diag(ir, .Pointer_Lowering_Guess, "procs.params by_ptr ignored for %s: type is not a single data pointer (^T)", scope)
		return
	}
	parameter.by_ptr = true
}

// Best-effort type name for callback views — named refs only; complex types
// report empty so configs match on parent/child names instead.
type_name_for_policy_view :: proc(ir: ^IR, handle: Type_Handle) -> string {
	info := ir_type(ir, handle)
	#partial switch variant in info.variant {
	case Type_Record_Ref:
		return ir.records[variant.decl].name
	case Type_Enum_Ref:
		return ir.enums[variant.decl].name
	case Type_Typedef_Ref:
		return ir.typedefs[variant.decl].name
	case Type_Std:
		return variant.name
	case Type_Idiomatic_Leaf:
		return variant.spelling
	case Type_Lowered_Pointer:
		return type_name_for_policy_view(ir, variant.pointee)
	case Type_Pointer:
		return type_name_for_policy_view(ir, variant.pointee)
	}
	return ""
}
