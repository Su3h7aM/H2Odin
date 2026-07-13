package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_macro_group_materializes_filtered_enum :: proc(t: ^testing.T) {
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
	substitute_leaf_types(&ir)
	ir_add_macro(&ir, Macro_Decl{name = "LIB_OK", tokens = {{spelling = "0", kind = .Literal}}, home = 1})
	ir_add_macro(&ir, Macro_Decl{name = "LIB_ERR", tokens = {{spelling = "7", kind = .Literal}}, home = 2})
	ir_add_macro(&ir, Macro_Decl{name = "LIB_OPEN_RO", tokens = {{spelling = "1", kind = .Literal}}, home = 2})
	ir_add_macro(&ir, Macro_Decl{name = "LIB_TITLE", tokens = {{spelling = `"lib"`, kind = .Literal}}, home = 2})
	ir_add_macro(&ir, Macro_Decl{name = "LIB_ADD", is_function_like = true, home = 2})

	policy := Policy {
		macro_groups = {
			{
				name = "Result_Code",
				base_type = "c.int",
				prefix = "LIB_",
				exclude_prefixes = {"LIB_OPEN_"},
				member_strip_prefix = "LIB_",
				emit_original_consts = false,
			},
		},
	}

	apply_macro_groups(&ir, &policy)

	testing.expect_value(t, len(ir.enums), 1)
	grouped_enum := ir.enums[0]
	testing.expect_value(t, grouped_enum.name, "Result_Code")
	testing.expect_value(t, grouped_enum.home, Input_Header_Handle(1))
	testing.expect_value(t, len(grouped_enum.members), 2)
	testing.expect_value(t, grouped_enum.members[0].name, "OK")
	testing.expect_value(t, grouped_enum.members[0].value, i64(0))
	testing.expect_value(t, grouped_enum.members[1].name, "ERR")
	testing.expect_value(t, grouped_enum.members[1].value, i64(7))
	backing_type := ir_type(&ir, grouped_enum.backing)
	backing_leaf, has_configured_backing := backing_type.variant.(Type_Idiomatic_Leaf)
	testing.expect(t, has_configured_backing)
	testing.expect_value(t, backing_leaf.spelling, "i32")
	testing.expect_value(t, backing_leaf.reason, Idiomatic_Reason.Table_Preference)
	native_unsigned_backing := macro_group_backing_type(&ir, Macro_Group_Enum{base_type = "u16"})
	native_unsigned_leaf := ir_type(&ir, native_unsigned_backing).variant.(Type_Idiomatic_Leaf)
	native_unsigned_original := ir_type(&ir, native_unsigned_leaf.original).variant.(Type_Builtin)
	testing.expect_value(t, native_unsigned_leaf.spelling, "u16")
	testing.expect_value(t, native_unsigned_original.kind, Builtin_Kind.U_Int)

	remaining_macros := 0
	for declaration in ir.order {
		if declaration.kind == .Macro {
			remaining_macros += 1
			name := ir.macros[declaration.index].name
			testing.expect(t, name != "LIB_OK" && name != "LIB_ERR")
		}
	}
	testing.expect_value(t, remaining_macros, 3)
	testing.expect_value(t, len(ir.diagnostics), 0)
}

@(test)
test_macro_groups_keep_first_claim :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	ir_add_macro(&ir, Macro_Decl{name = "LIB_OK", tokens = {{spelling = "0", kind = .Literal}}, home = 1})

	policy := Policy {
		macro_groups = {
			{id = "first", name = "First", prefix = "LIB_", emit_original_consts = true},
			{id = "second", name = "Second", prefix = "LIB_", emit_original_consts = true},
		},
	}

	apply_macro_groups(&ir, &policy)

	testing.expect_value(t, len(ir.enums), 1)
	testing.expect_value(t, ir.enums[0].name, "First")
	testing.expect_value(t, len(ir.enums[0].members), 1)
	testing.expect_value(t, len(ir.diagnostics), 2)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Macro_Group_Conflict)
	testing.expect_value(t, ir.diagnostics[1].category, Diag_Category.Macro_Group_Empty)
	remaining_macro := false
	for declaration in ir.order {
		if declaration.kind == .Macro && ir.macros[declaration.index].name == "LIB_OK" {
			remaining_macro = true
		}
	}
	testing.expect(t, remaining_macro)
}
