package h2odin

import "core:fmt"

// structs.fields → structs.field → structs.align. Keys and align names are
// C names (this pass runs before naming).
apply_struct_adjustments :: proc(ir: ^IR, policy: ^Policy) {
	has_fields := policy.struct_fields != nil && len(policy.struct_fields) > 0
	has_align := policy.struct_align != nil && len(policy.struct_align) > 0
	if !has_fields && !policy.has_struct_field && !has_align {
		return
	}
	for &record in ir.records {
		if record.name == "" {
			continue
		}
		if has_align {
			if n, ok := policy.struct_align[record.name]; ok {
				record.align = n
			}
		}
		if !has_fields && !policy.has_struct_field {
			continue
		}
		for &field in record.fields {
			if field.name == "" {
				continue
			}
			key := fmt.tprintf("%s.%s", record.name, field.name)
			if has_fields {
				if action, ok := policy.struct_fields[key]; ok {
					apply_member_action_to_field(&field, action)
				}
			}
			if policy.has_struct_field {
				view_type := type_name_for_view(ir, field.type)
				if action, decided := policy_struct_field_action(policy, record.name, field.name, view_type); decided {
					apply_member_action_to_field(&field, action)
				}
			}
		}
	}
}

apply_member_action_to_field :: proc(field: ^Field, action: Member_Action) {
	if action.type != "" {
		field.type_spelling = action.type
	}
	if action.tag != "" {
		field.tag = action.tag
	}
}

// procs.params → procs.param; procs.results → procs.result.
apply_proc_adjustments :: proc(ir: ^IR, policy: ^Policy) {
	has_params := policy.proc_params != nil && len(policy.proc_params) > 0
	has_results := policy.proc_results != nil && len(policy.proc_results) > 0
	if !has_params && !has_results && !policy.has_proc_param && !policy.has_proc_result {
		return
	}
	for &fn in ir.funcs {
		if has_params || policy.has_proc_param {
			for &param in fn.params {
				key_name := param.name if param.name != "" else "_"
				key := fmt.tprintf("%s.%s", fn.name, key_name)
				if has_params {
					if action, ok := policy.proc_params[key]; ok {
						apply_member_action_to_param(&param, action)
					}
				}
				if policy.has_proc_param {
					view_type := type_name_for_view(ir, param.type)
					if action, decided := policy_proc_param_action(policy, fn.name, param.name, view_type); decided {
						apply_member_action_to_param(&param, action)
					}
				}
			}
		}
		if has_results {
			if action, ok := policy.proc_results[fn.name]; ok {
				if action.type != "" {
					fn.return_type_spelling = action.type
				}
			}
		}
		if policy.has_proc_result {
			view_type := type_name_for_view(ir, fn.return_type)
			if action, decided := policy_proc_result_action(policy, fn.name, view_type); decided {
				if action.type != "" {
					fn.return_type_spelling = action.type
				}
			}
		}
	}
}

apply_member_action_to_param :: proc(param: ^Param, action: Member_Action) {
	if action.type != "" {
		param.type_spelling = action.type
	}
	if action.default != "" {
		param.default = action.default
	}
}

// Best-effort type name for callback views — named refs only; complex types
// report empty so configs match on parent/child names instead.
type_name_for_view :: proc(ir: ^IR, handle: Type_Handle) -> string {
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
		return type_name_for_view(ir, variant.pointee)
	case Type_Pointer:
		return type_name_for_view(ir, variant.pointee)
	}
	return ""
}

// A config type spelling names an explicit Odin form for a C type by name —
// stronger than an idiomatic proof, since the user asked for it directly —
// so it applies in both type modes and can override an idiomatic
// substitution already made. Anything not named is untouched.
//
// types.map rewrites references only. types.overrides also drops the named
// record/enum/typedef from the ordering list: the user supplied its Odin
// spelling directly, so emitting the generator's own declaration would be
// redundant (and for "typedef struct { … } Name;" would emit the name twice).
