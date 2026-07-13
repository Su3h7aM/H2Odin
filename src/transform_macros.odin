package h2odin

import "core:strings"

// ---------------------------------------------------------------- Macros

// Synthesize explicit-valued enums from macros.groups. Consumed macros are
// dropped from the ordering list when emit_original_consts is false.
//
// Per-macro check order (config-spec): prefix → exclude_prefixes →
// value-kind (integer) → include last.
apply_macro_groups :: proc(ir: ^IR, policy: ^Policy) {
	if len(policy.macro_groups) == 0 {
		return
	}

	macros_to_drop := make(map[u32]bool, context.temp_allocator)
	claimed_macros := make(map[u32]bool, context.temp_allocator)

	for group in policy.macro_groups {
		group_label := group.id if group.id != "" else group.name
		members := make([dynamic]Enum_Member, context.temp_allocator)
		// Output home follows the first member in IR pool order.
		first_member_home: Input_Header_Handle
		for macro, macro_index in ir.macros {
			value, is_member := macro_group_member_value(policy, group, macro)
			if !is_member {
				continue
			}
			if claimed_macros[u32(macro_index)] {
				ir_diag_with_local(
					ir,
					group.diag_overrides,
					.Macro_Group_Conflict,
					"%q already claimed by an earlier group; skipping for %q",
					macro.name,
					group_label,
				)
				continue
			}
			claimed_macros[u32(macro_index)] = true
			if first_member_home == 0 {
				first_member_home = macro.home
			}

			member_name := macro.name
			if group.member_strip_prefix != "" {
				member_name = str_strip_prefix(member_name, group.member_strip_prefix)
			}
			append(&members, Enum_Member{name = strings.clone(member_name), value = value})
			if !group.emit_original_consts {
				macros_to_drop[u32(macro_index)] = true
			}
		}
		if len(members) == 0 {
			ir_diag_with_local(ir, group.diag_overrides, .Macro_Group_Empty, "macro group %q matched no macros", group_label)
			continue
		}
		persistent_members := make([]Enum_Member, len(members))
		for member, member_index in members {
			persistent_members[member_index] = member
		}
		_ = ir_add_enum(
			ir,
			Enum_Decl{name = strings.clone(group.name), backing = macro_group_backing_type(ir, group), members = persistent_members, home = first_member_home},
		)
	}

	if len(macros_to_drop) == 0 {
		return
	}
	kept_declarations := make([dynamic]Decl_Ref, 0, len(ir.order))
	for declaration in ir.order {
		if declaration.kind == .Macro && macros_to_drop[declaration.index] {
			continue
		}
		append(&kept_declarations, declaration)
	}
	ir.order = kept_declarations
}

// Apply the documented filter order before a macro can claim membership:
// prefix, excluded prefixes, integer value, then the optional policy callback.
macro_group_member_value :: proc(policy: ^Policy, group: Macro_Group_Enum, macro: Macro_Decl) -> (value: i64, ok: bool) {
	if group.prefix != "" && !macro_matches_prefix(macro.name, group.prefix) {
		return 0, false
	}
	for excluded_prefix in group.exclude_prefixes {
		if macro_matches_prefix(macro.name, excluded_prefix) {
			return 0, false
		}
	}

	parsed_value, is_integer := macro_integer_value(macro)
	if !is_integer || !policy_macro_include(policy, group, macro) {
		return 0, false
	}
	return parsed_value, true
}

macro_group_backing_type :: proc(ir: ^IR, group: Macro_Group_Enum) -> Type_Handle {
	default_backing := ir_builtin_type(ir, .Int)
	if group.base_type == "" {
		return default_backing
	}
	// Resolve C spellings through the captured builtin so the selected type
	// mode still applies. A core:c distinct type cannot be pasted directly as
	// an Odin enum base.
	if builtin_kind, is_builtin := builtin_kind_for_abi_spelling(group.base_type); is_builtin {
		return ir_builtin_type(ir, builtin_kind)
	}
	unsigned, is_supported := enum_backing_spelling_signedness(group.base_type)
	if !is_supported {
		return default_backing // rejected while loading; protects direct internal callers
	}
	original_kind := Builtin_Kind.Int
	if unsigned {
		original_kind = .U_Int
	}
	original_backing := ir_builtin_type(ir, original_kind)
	if leaf, is_substituted := ir_type(ir, original_backing).variant.(Type_Idiomatic_Leaf); is_substituted {
		original_backing = leaf.original
	}
	return ir_add_type(
		ir,
		Type_Info{variant = Type_Idiomatic_Leaf{original = original_backing, spelling = strings.clone(group.base_type), reason = .Config_Override}},
	)
}
