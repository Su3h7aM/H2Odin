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

	drop_macros := make(map[u32]bool, context.temp_allocator)
	claimed := make(map[u32]bool, context.temp_allocator)

	for group in policy.macro_groups {
		members := make([dynamic]Enum_Member, context.temp_allocator)
		// Placement: first matched macro in IR pool order (final input/order).
		first_home: Input_Header_Handle
		for macro, mi in ir.macros {
			if macro.is_function_like {
				continue
			}
			if group.prefix != "" && !strings.has_prefix(macro.name, group.prefix) {
				continue
			}
			excluded := false
			for excl in group.exclude_prefixes {
				if excl != "" && strings.has_prefix(macro.name, excl) {
					excluded = true
					break
				}
			}
			if excluded {
				continue
			}
			value, is_int := macro_integer_value(macro)
			if !is_int {
				continue
			}
			if group.has_include && !policy_macro_include(policy, group, macro) {
				continue
			}
			if claimed[u32(mi)] {
				label := group.id if group.id != "" else group.name
				ir_diag_with_local(
					ir,
					group.diag_overrides,
					.Macro_Group_Conflict,
					"%q already claimed by an earlier group; skipping for %q",
					macro.name,
					label,
				)
				continue
			}
			claimed[u32(mi)] = true
			if first_home == 0 {
				first_home = macro.home
			}

			member_name := macro.name
			if group.member_strip_prefix != "" {
				member_name = str_strip_prefix(member_name, group.member_strip_prefix)
			}
			append(&members, Enum_Member{name = strings.clone(member_name), value = value})
			if !group.emit_original_consts {
				drop_macros[u32(mi)] = true
			}
		}
		if len(members) == 0 {
			label := group.id if group.id != "" else group.name
			ir_diag_with_local(ir, group.diag_overrides, .Macro_Group_Empty, "macro group %q matched no macros", label)
			continue
		}
		arena_members := make([]Enum_Member, len(members))
		for m, i in members {
			arena_members[i] = m
		}
		_ = ir_add_enum(ir, Enum_Decl{name = strings.clone(group.name), backing = ir_builtin_type(ir, .Int), members = arena_members, home = first_home})
	}

	if len(drop_macros) == 0 {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		if ref.kind == .Macro && drop_macros[ref.index] {
			continue
		}
		append(&kept, ref)
	}
	ir.order = kept
}
