package h2odin

// Apply both configured spelling tables as one decision so precedence cannot
// depend on a previous pass having already replaced the type slot.
//
// types.map rewrites references only. types.overrides wins on conflicts and
// also replaces the declaration:
//
//   - typedef Name: keep `Name` as an alias of the configured spelling and
//     leave use sites referring to `Name`.
//   - named record/enum: drop the declaration and inline the configured
//     spelling at use sites.
//
// Keys are C names; this pass runs before apply_renames.
apply_configured_type_rewrites :: proc(ir: ^IR, policy: ^Policy) {
	if len(policy.type_map) == 0 && len(policy.type_overrides) == 0 {
		return
	}

	original_type_count := len(ir.types)
	overridden_typedefs := make([]bool, len(ir.typedefs), context.temp_allocator)
	for &typedef, typedef_index in ir.typedefs {
		spelling, overridden := policy.type_overrides[typedef.name]
		if !overridden || typedef.name == "" || typedef.is_foreign || typedef.is_unresolvable {
			continue
		}

		original := ir_add_type(ir, ir_type(ir, typedef.aliased))
		original_info := ir_type(ir, original)
		typedef.aliased = ir_add_type(
			ir,
			Type_Info{is_const = original_info.is_const, variant = Type_Idiomatic_Leaf{original = original, spelling = spelling, reason = .Config_Override}},
		)
		overridden_typedefs[typedef_index] = true
	}

	configured_spellings := make([]string, original_type_count, context.temp_allocator)
	has_configured_spelling := make([]bool, original_type_count, context.temp_allocator)
	for type_index in 0 ..< original_type_count {
		name := configurable_type_name(ir, Type_Handle(type_index))
		configured_spellings[type_index], has_configured_spelling[type_index] = configured_type_spelling(policy, name)
	}

	for type_index in 0 ..< original_type_count {
		type_info := ir.types[type_index]
		if typedef_reference, is_typedef := type_info.variant.(Type_Typedef_Ref); is_typedef && overridden_typedefs[typedef_reference.decl] {
			continue
		}

		if !has_configured_spelling[type_index] {
			continue
		}

		original := ir_add_type(ir, type_info)
		ir.types[type_index] = Type_Info {
			is_const = type_info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = configured_spellings[type_index], reason = .Config_Override},
		}
	}

	kept_count := 0
	for declaration in ir.order {
		should_drop := false
		#partial switch declaration.kind {
		case .Record:
			name := ir.records[declaration.index].name
			if name != "" {
				_, should_drop = policy.type_overrides[name]
			}
		case .Enum:
			name := ir.enums[declaration.index].name
			if name != "" {
				_, should_drop = policy.type_overrides[name]
			}
		}
		if should_drop {
			continue
		}
		ir.order[kept_count] = declaration
		kept_count += 1
	}
	resize(&ir.order, kept_count)
}

// Return the C name by which config addresses a type slot. Native scalar
// substitutions retain their captured C type for this purpose. Opaque,
// platform, and prior config decisions are terminal representations.
configurable_type_name :: proc(ir: ^IR, handle: Type_Handle) -> string {
	current := handle
	for _ in 0 ..< len(ir.types) {
		#partial switch variant in ir_type(ir, current).variant {
		case Type_Record_Ref:
			return ir.records[variant.decl].name
		case Type_Enum_Ref:
			return ir.enums[variant.decl].name
		case Type_Typedef_Ref:
			return ir.typedefs[variant.decl].name
		case Type_Std:
			return variant.name
		case Type_Idiomatic_Leaf:
			switch variant.reason {
			case .Table_Preference, .Derived_From_Measurement:
				current = variant.original
			case .Config_Override, .Opaque_Handle, .Platform_Type:
				return ""
			}
		case:
			return ""
		}
	}
	return ""
}

// types.overrides has explicit precedence over types.map everywhere config
// type spellings are consulted, including the earlier foreign-type stage.
configured_type_spelling :: proc(policy: ^Policy, name: string) -> (spelling: string, ok: bool) {
	if override, overridden := policy.type_overrides[name]; overridden {
		return override, true
	}
	if mapped_type, mapped := policy.type_map[name]; mapped {
		return mapped_type, true
	}
	return "", false
}
