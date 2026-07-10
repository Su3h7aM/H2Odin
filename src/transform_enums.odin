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
		ok := true
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
		}
		if !ok {
			continue
		}
		// Rewrite member values to bit positions (log2).
		for &member in decl.members {
			member.value = i64(log2_u64(u64(member.value)))
		}
		// Type handle for the enum (reuse an existing Type_Enum_Ref if any,
		// otherwise add one).
		enum_type := ir_add_type(ir, Type_Info{variant = Type_Enum_Ref{decl = Decl_Handle(enum_index)}})
		ir_add_bit_set(ir, Bit_Set_Decl{name = strings.clone(rule.name), elem = enum_type})
	}
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
