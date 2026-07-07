package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_keyword_safe_default_suffixes_keywords :: proc(t: ^testing.T) {
	testing.expect_value(t, keyword_safe_default("ordinary"), "ordinary")

	name := keyword_safe_default("matrix")
	defer delete(name)
	testing.expect_value(t, name, "matrix_")
}

@(test)
test_strip_configured_prefix_by_symbol_kind :: proc(t: ^testing.T) {
	policy := Policy {
		strip_prefix_func  = "gl_",
		strip_prefix_type  = "GL",
		strip_prefix_const = "GL_",
	}

	testing.expect_value(t, strip_configured_prefix(&policy, "gl_Draw", .Func), "Draw")
	testing.expect_value(t, strip_configured_prefix(&policy, "GLVector", .Type), "Vector")
	testing.expect_value(t, strip_configured_prefix(&policy, "GL_MAX", .Const), "MAX")
	testing.expect_value(t, strip_configured_prefix(&policy, "gl_field", .Field), "gl_field")
	testing.expect_value(t, strip_configured_prefix(&policy, "gl_", .Func), "gl_")
}

@(test)
test_apply_type_map_rewrites_type_refs_and_suppresses_decl :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	record := ir_add_record(&ir, Record_Decl{name = "Vector2", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})
	testing.expect_value(t, len(ir.order), 1)

	policy := Policy{}
	policy.type_map = make(map[string]string)
	policy.type_map["Vector2"] = "[2]f32"

	apply_type_map(&ir, &policy)

	mapped, is_mapped := ir.types[int(record_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, is_mapped)
	testing.expect_value(t, mapped.spelling, "[2]f32")
	testing.expect_value(t, mapped.reason, Idiomatic_Reason.Config_Override)
	testing.expect_value(t, len(ir.order), 0)
}
