package h2odin

import "core:math/bits"
import "core:strings"

// ---------------------------------------------------------------- Enums

apply_enum_policies :: proc(ir: ^IR, policy: ^Policy) {
	name_anonymous_enums(ir, policy)
	filter_enum_members(ir, policy)
	apply_enum_bit_sets(ir, policy)
}

name_anonymous_enums :: proc(ir: ^IR, policy: ^Policy) {
	for rule in policy.enum_anonymous {
		for &decl in ir.enums {
			if decl.name != "" || len(decl.members) == 0 {
				continue
			}
			if decl.members[0].name == rule.first_member {
				decl.name = strings.clone(rule.name)
				break
			}
		}
	}
}

filter_enum_members :: proc(ir: ^IR, policy: ^Policy) {
	if !policy.has_enum_member {
		return
	}
	for &decl in ir.enums {
		if len(decl.members) == 0 {
			continue
		}
		enum_name := decl.name // may be "" for anonymous
		kept_count := 0
		for member in decl.members {
			if policy_enum_member_remove(policy, enum_name, member.name, member.value) {
				continue
			}
			decl.members[kept_count] = member
			kept_count += 1
		}
		decl.members = decl.members[:kept_count]
	}
}

apply_enum_bit_sets :: proc(ir: ^IR, policy: ^Policy) {
	transformed_enums := make(map[Decl_Handle]int, context.temp_allocator)
	for rule in policy.enum_bit_sets {
		enum_handle, found := find_named_enum(ir, rule.enum_name)
		if !found {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q not found", rule.enum_name)
			continue
		}
		decl := &ir.enums[enum_handle]
		if len(decl.members) == 0 {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q has no members", rule.enum_name)
			continue
		}

		backing_bits, already_transformed := transformed_enums[enum_handle]
		if !already_transformed {
			valid: bool
			backing_bits, valid = validate_bit_set_rule(ir, rule, decl)
			if !valid {
				continue
			}
			rewrite_enum_members_to_bit_positions(decl)
			transformed_enums[enum_handle] = backing_bits
		}

		enum_type := ir_add_type(ir, Type_Info{variant = Type_Enum_Ref{decl = enum_handle}})
		// Place the bit_set with its element enum; width is a measured fact.
		ir_add_bit_set(ir, Bit_Set_Decl{name = strings.clone(rule.name), elem = enum_type, backing_bits = backing_bits, home = decl.home})
	}
}

find_named_enum :: proc(ir: ^IR, name: string) -> (Decl_Handle, bool) {
	for declaration, declaration_index in ir.enums {
		if declaration.name == name {
			return Decl_Handle(declaration_index), true
		}
	}
	return {}, false
}

validate_bit_set_rule :: proc(ir: ^IR, rule: Enum_Bit_Set_Rule, declaration: ^Enum_Decl) -> (backing_bits: int, ok: bool) {
	// Proven width from the C enum's measured integer type. Unknown or
	// unsupported byte sizes cannot back an ABI-faithful Odin bit_set.
	measured_bytes := type_measured_integer_size(ir, declaration.backing)
	backing_bits = measured_bytes * 8
	if measured_bytes <= 0 || bit_set_backing_spelling(backing_bits) == "" {
		ir_diag_with_local(
			ir,
			rule.diag_overrides,
			.Bit_Set_Backing_Mismatch,
			"enums.bit_sets: enum %q has unusable backing width (measured size %d bytes); skipping bit_set %q",
			rule.enum_name,
			measured_bytes,
			rule.name,
		)
		return 0, false
	}

	max_position := -1
	for member in declaration.members {
		if member.value <= 0 || !bits.is_power_of_two(u64(member.value)) {
			ir_diag_with_local(
				ir,
				rule.diag_overrides,
				.Bit_Set_Non_Power_Of_Two,
				"%s.%s = %d is not a power of two; skipping bit_set %q",
				rule.enum_name,
				member.name,
				member.value,
				rule.name,
			)
			return 0, false
		}
		max_position = max(max_position, int(bits.trailing_zeros(u64(member.value))))
	}
	if max_position >= backing_bits {
		ir_diag_with_local(
			ir,
			rule.diag_overrides,
			.Bit_Set_Backing_Mismatch,
			"enums.bit_sets: flag bit position %d does not fit in %d-bit backing for enum %q; skipping bit_set %q",
			max_position,
			backing_bits,
			rule.enum_name,
			rule.name,
		)
		return 0, false
	}
	return backing_bits, true
}

rewrite_enum_members_to_bit_positions :: proc(declaration: ^Enum_Decl) {
	for &member in declaration.members {
		member.value = i64(bits.trailing_zeros(u64(member.value)))
	}
}

// Measured size in bytes of a leaf integer type. Peels Type_Idiomatic_Leaf
// back to the original capture so the C width stays available after idiomatic
// substitution rewrote the shared slot. -1 when unknown or not a sized leaf.
type_measured_integer_size :: proc(ir: ^IR, handle: Type_Handle) -> int {
	info := ir_type(ir, handle)
	#partial switch variant in info.variant {
	case Type_Idiomatic_Leaf:
		return type_measured_integer_size(ir, variant.original)
	case Type_Builtin:
		return variant.size if builtin_is_integer(variant.kind) else -1
	case Type_Std:
		return variant.size
	}
	return -1
}

// Unsigned fixed-width spelling for a bit_set's explicit backing.
// "" when bits is not a supported power-of-two width.
bit_set_backing_spelling :: proc(bits: int) -> string {
	switch bits {
	case 8:
		return "u8"
	case 16:
		return "u16"
	case 32:
		return "u32"
	case 64:
		return "u64"
	}
	return ""
}

// Parameter names are not symbols — the policy is never consulted — but a
// name that collides with an Odin keyword still cannot be emitted verbatim.
// Case is left as in the header (same foreign-porting convention as symbols).
