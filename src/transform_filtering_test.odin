package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_declaration_filter_applies_exact_pattern_and_deprecation_rules_in_place :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	ir_add_func(&ir, Func_Decl{name = "drop_exact", return_type = void_type})
	kept_record := ir_add_record(&ir, Record_Decl{name = "Public_Record", is_complete = true})
	ir_add_var(&ir, Var_Decl{name = "internal_count", type = ir_builtin_type(&ir, .Int)})
	ir_add_macro(&ir, Macro_Decl{name = "OLD_VALUE", deprecated = true})
	kept_function_index := len(ir.funcs)
	ir_add_func(&ir, Func_Decl{name = "keep", return_type = void_type})
	append(&ir.order, Decl_Ref{})

	policy := Policy {
		remove_names      = {"drop_exact"},
		remove_patterns   = {"internal_*"},
		remove_deprecated = true,
	}
	filter_declarations(&ir, &policy)

	testing.expect_value(t, len(ir.order), 2)
	testing.expect_value(t, ir.order[0], Decl_Ref{kind = .Record, index = u32(kept_record)})
	testing.expect_value(t, ir.order[1], Decl_Ref{kind = .Func, index = u32(kept_function_index)})
	testing.expect_value(t, len(ir.funcs), 2)
	testing.expect_value(t, len(ir.vars), 1)
	testing.expect_value(t, len(ir.macros), 1)
}

@(test)
test_deprecation_filter_preserves_inline_records_and_live_anonymous_enums :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	deprecated_record := ir_add_record(&ir, Record_Decl{is_complete = true, deprecated = true})
	_ = ir_add_enum(&ir, Enum_Decl{deprecated = true, members = {{name = "OLD_VALUE"}}})
	live_enum := ir_add_enum(&ir, Enum_Decl{members = {{name = "LIVE_VALUE"}}})

	filter_declarations(&ir, &Policy{remove_deprecated = true})

	testing.expect_value(t, len(ir.order), 2)
	testing.expect_value(t, ir.order[0], Decl_Ref{kind = .Record, index = u32(deprecated_record)})
	testing.expect_value(t, ir.order[1], Decl_Ref{kind = .Enum, index = u32(live_enum)})
}
