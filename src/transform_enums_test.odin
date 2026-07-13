package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_enum_policies_name_filter_and_materialize_in_order :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"enum-policy-order",
		`local h2o = require "h2odin"
local config = h2o.config()
config.enums.anonymous = {
  h2o.enum.anonymous { name = "Flag", first_member = "FIRST" },
}
config.enums.member = function(member)
  if member.enum_name == "Flag" and member.name == "REMOVE" then
    return { remove = true }
  end
  return nil
end
config.enums.bit_sets = {
  h2o.enum.bit_set { enum = "Flag", name = "Flags", mode = "log2" },
}
return config
`,
	)
	if !path_ok {
		return
	}

	policy, policy_ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, policy_ok)
	if !policy_ok {
		return
	}

	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	ir.types[int(int_type)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(&ir, Enum_Decl{backing = int_type, members = {{name = "FIRST", value = 1}, {name = "REMOVE", value = 2}, {name = "LAST", value = 4}}})

	apply_enum_policies(&ir, &policy)

	testing.expect_value(t, ir.enums[0].name, "Flag")
	testing.expect_value(t, len(ir.enums[0].members), 2)
	testing.expect_value(t, ir.enums[0].members[0].name, "FIRST")
	testing.expect_value(t, ir.enums[0].members[0].value, i64(0))
	testing.expect_value(t, ir.enums[0].members[1].name, "LAST")
	testing.expect_value(t, ir.enums[0].members[1].value, i64(2))
	testing.expect_value(t, len(ir.bit_sets), 1)
	testing.expect_value(t, len(ir.diagnostics), 0)
}

@(test)
test_anonymous_enum_name_matches_first_member :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_add_enum(&ir, Enum_Decl{members = {{name = "KEY_NONE"}}})
	_ = ir_add_enum(&ir, Enum_Decl{name = "Already_Named", members = {{name = "KEY_NONE"}}})
	policy := Policy {
		enum_anonymous = {{name = "Key", first_member = "KEY_NONE"}},
	}

	name_anonymous_enums(&ir, &policy)

	testing.expect_value(t, ir.enums[0].name, "Key")
	testing.expect_value(t, ir.enums[1].name, "Already_Named")
}

@(test)
test_bit_set_rejects_empty_enum :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	member_storage: [1]Enum_Member
	empty_members := member_storage[:0]
	_ = ir_add_enum(&ir, Enum_Decl{name = "Empty_Flag", backing = ir_builtin_type(&ir, .Int), members = empty_members})
	policy := Policy {
		enum_bit_sets = {{enum_name = "Empty_Flag", name = "Empty_Flags", mode = "log2"}},
	}

	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Bit_Set_Target_Missing)
}

@(test)
test_bit_set_rejects_non_integer_backing :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	float_type := ir_builtin_type(&ir, .Float)
	ir.types[int(float_type)].variant = Type_Builtin {
		kind = .Float,
		size = 4,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Invalid_Flag", backing = float_type, members = {{name = "First", value = 1}}})
	policy := Policy {
		enum_bit_sets = {{enum_name = "Invalid_Flag", name = "Invalid_Flags", mode = "log2"}},
	}

	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Bit_Set_Backing_Mismatch)
}

@(test)
test_bit_set_rules_can_share_an_enum :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	ir.types[int(int_type)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = int_type, members = {{name = "First", value = 1}, {name = "Second", value = 2}}})
	policy := Policy {
		enum_bit_sets = {{enum_name = "Flag", name = "Flag_Set", mode = "log2"}, {enum_name = "Flag", name = "Alternate_Flag_Set", mode = "log2"}},
	}

	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 2)
	if len(ir.bit_sets) == 2 {
		testing.expect_value(t, ir.bit_sets[0].backing_bits, 32)
		testing.expect_value(t, ir.bit_sets[1].backing_bits, 32)
	}
	testing.expect_value(t, ir.enums[0].members[0].value, i64(0))
	testing.expect_value(t, ir.enums[0].members[1].value, i64(1))
	testing.expect_value(t, len(ir.diagnostics), 0)
}
