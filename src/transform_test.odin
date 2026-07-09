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
test_strip_configured_affixes_by_symbol_kind :: proc(t: ^testing.T) {
	policy := Policy {
		strip_prefix_proc  = {"gl_"},
		strip_prefix_type  = {"GL"},
		strip_prefix_const = {"GL_"},
		strip_suffix_type  = {"_t"},
	}

	testing.expect_value(t, strip_configured_affixes(&policy, "gl_Draw", .Func), "Draw")
	testing.expect_value(t, strip_configured_affixes(&policy, "GLVector", .Type), "Vector")
	testing.expect_value(t, strip_configured_affixes(&policy, "GL_MAX", .Const), "MAX")
	testing.expect_value(t, strip_configured_affixes(&policy, "gl_field", .Field), "gl_field")
	testing.expect_value(t, strip_configured_affixes(&policy, "gl_", .Func), "gl_")
	testing.expect_value(t, strip_configured_affixes(&policy, "size_t", .Type), "size")
}

@(test)
test_apply_type_overrides_rewrites_type_refs_and_suppresses_decl :: proc(t: ^testing.T) {
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
	policy.type_overrides = make(map[string]string)
	policy.type_overrides["Vector2"] = "[2]f32"

	apply_type_rewrites(&ir, policy.type_overrides, drop_decls = true)

	mapped, is_mapped := ir.types[int(record_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, is_mapped)
	testing.expect_value(t, mapped.spelling, "[2]f32")
	testing.expect_value(t, mapped.reason, Idiomatic_Reason.Config_Override)
	testing.expect_value(t, len(ir.order), 0)
}

@(test)
test_apply_struct_and_proc_adjustments :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_ty := ir_builtin_type(&ir, .Int)

	_ = ir_add_record(&ir, Record_Decl{name = "BoneInfo", is_complete = true, fields = {{name = "name", type = int_ty}, {name = "parent", type = int_ty}}})
	ir_add_func(&ir, Func_Decl{name = "SetConfigFlags", return_type = ir_builtin_type(&ir, .Void), params = {{name = "flags", type = int_ty}}})

	policy := Policy{}
	policy.struct_fields = make(map[string]Member_Action)
	policy.struct_fields["BoneInfo.name"] = Member_Action {
		tag = `fmt:"s,0"`,
	}
	policy.struct_fields["BoneInfo.parent"] = Member_Action {
		type = "i32",
	}
	policy.struct_align = make(map[string]int)
	policy.struct_align["BoneInfo"] = 8
	policy.proc_params = make(map[string]Member_Action)
	policy.proc_params["SetConfigFlags.flags"] = Member_Action {
		type    = "ConfigFlags",
		default = "0",
	}
	policy.proc_results = make(map[string]Member_Action)

	apply_struct_adjustments(&ir, &policy)
	apply_proc_adjustments(&ir, &policy)

	rec := ir.records[0]
	testing.expect_value(t, rec.align, 8)
	testing.expect_value(t, rec.fields[0].tag, `fmt:"s,0"`)
	testing.expect_value(t, rec.fields[1].type_spelling, "i32")
	fn := ir.funcs[0]
	testing.expect_value(t, fn.params[0].type_spelling, "ConfigFlags")
	testing.expect_value(t, fn.params[0].default, "0")
}

@(test)
test_link_name_for_respects_link_prefix :: proc(t: ^testing.T) {
	policy := Policy {
		foreign_link_prefix = "sqlite3_",
	}
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open"), "")
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open_v2"), "sqlite3_open")
	policy.foreign_link_prefix = ""
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open"), "sqlite3_open")
}
