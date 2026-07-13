package h2odin

import "core:strings"

// ---------------------------------------------------------------- Enums

apply_enum_policies :: proc(ir: ^IR, policy: ^Policy) {
	apply_enum_anonymous(ir, policy)
	apply_enum_member_policy(ir, policy)
	apply_enum_bit_sets(ir, policy)
}

apply_enum_anonymous :: proc(ir: ^IR, policy: ^Policy) {
	for rule in policy.enum_anonymous {
		for &decl in ir.enums {
			if decl.name != "" || decl.members == nil || len(decl.members) == 0 {
				continue
			}
			if decl.members[0].name == rule.first_member {
				decl.name = strings.clone(rule.name)
				break
			}
		}
	}
}

apply_enum_member_policy :: proc(ir: ^IR, policy: ^Policy) {
	if !policy.has_enum_member {
		return
	}
	for &decl in ir.enums {
		if decl.members == nil {
			continue
		}
		kept := make([dynamic]Enum_Member, 0, len(decl.members))
		enum_name := decl.name // may be "" for anonymous
		for member in decl.members {
			if policy_enum_member_remove(policy, enum_name, member.name, member.value) {
				continue
			}
			append(&kept, member)
		}
		if len(kept) != len(decl.members) {
			decl.members = kept[:]
		}
	}
}

apply_enum_bit_sets :: proc(ir: ^IR, policy: ^Policy) {
	for rule in policy.enum_bit_sets {
		enum_index := -1
		for decl, i in ir.enums {
			if decl.name == rule.enum_name {
				enum_index = i
				break
			}
		}
		if enum_index < 0 {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q not found", rule.enum_name)
			continue
		}
		decl := &ir.enums[enum_index]
		if decl.members == nil {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q has no members", rule.enum_name)
			continue
		}

		// Proven width from the C enum's measured integer type.
		// Unknown or non-power-of-two byte sizes cannot back an Odin bit_set.
		measured_bytes := type_measured_integer_size(ir, decl.backing)
		backing_bits := measured_bytes * 8
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
			continue
		}

		ok := true
		max_pos: i64 = -1
		for &member in decl.members {
			if member.value <= 0 || !is_power_of_two_u64(u64(member.value)) {
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
				ok = false
				break
			}
			pos := i64(log2_u64(u64(member.value)))
			if pos > max_pos {
				max_pos = pos
			}
		}
		if !ok {
			continue
		}
		// A flag whose log2 position does not fit the measured C width would
		// silently change the set's size if we emitted a bare bit_set[E].
		if max_pos >= i64(backing_bits) {
			ir_diag_with_local(
				ir,
				rule.diag_overrides,
				.Bit_Set_Backing_Mismatch,
				"enums.bit_sets: flag bit position %d does not fit in %d-bit backing for enum %q; skipping bit_set %q",
				max_pos,
				backing_bits,
				rule.enum_name,
				rule.name,
			)
			continue
		}

		// Rewrite member values to bit positions (log2).
		for &member in decl.members {
			member.value = i64(log2_u64(u64(member.value)))
		}
		// Type handle for the enum (reuse an existing Type_Enum_Ref if any,
		// otherwise add one).
		enum_type := ir_add_type(ir, Type_Info{variant = Type_Enum_Ref{decl = Decl_Handle(enum_index)}})
		// Place the bit_set with its element enum; width is a measured fact.
		ir_add_bit_set(ir, Bit_Set_Decl{name = strings.clone(rule.name), elem = enum_type, backing_bits = backing_bits, home = decl.home})
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
		return variant.size
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

is_power_of_two_u64 :: proc(v: u64) -> bool {
	return v != 0 && (v & (v - 1)) == 0
}

log2_u64 :: proc(v: u64) -> u64 {
	// v is a power of two ≥ 1.
	n: u64 = 0
	x := v
	for x > 1 {
		x >>= 1
		n += 1
	}
	return n
}

// Parameter names are not symbols — the policy is never consulted — but a
// name that collides with an Odin keyword still cannot be emitted verbatim.
// Case is left as in the header (same foreign-porting convention as symbols).
