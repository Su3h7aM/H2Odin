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
test_apply_type_overrides_typedef_becomes_named_alias :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	impl := ir_add_record(&ir, Record_Decl{name = "CXTargetInfoImpl", is_complete = false})
	impl_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = impl}})
	ptr_ty := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = impl_ty, kind = .Single}})
	td := ir_add_typedef(&ir, Typedef_Decl{name = "CXTargetInfo", aliased = ptr_ty})
	use_ty := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = td}})
	testing.expect_value(t, len(ir.order), 2)

	policy := Policy{}
	policy.type_overrides = make(map[string]string)
	policy.type_overrides["CXTargetInfo"] = "rawptr"

	apply_type_rewrites(&ir, policy.type_overrides, drop_decls = true)

	// Typedef kept with rawptr body; Impl record remains until symbols.remove.
	// Use sites still name the typedef (not bare rawptr).
	testing.expect_value(t, len(ir.order), 2)
	body, is_leaf := ir.types[int(ir.typedefs[int(td)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, is_leaf)
	testing.expect_value(t, body.spelling, "rawptr")
	_, still_td := ir.types[int(use_ty)].variant.(Type_Typedef_Ref)
	testing.expect(t, still_td)
	found_td := false
	for ref in ir.order {
		if ref.kind == .Typedef && ref.index == u32(td) {
			found_td = true
		}
	}
	testing.expect(t, found_td)
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
test_rename_of_escapes_keywords_from_absolute_overrides :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	// An absolute override that happens to land on an Odin keyword must still
	// emit valid syntax — keyword safety is a generator invariant, not a
	// naming preference, so it gates every emitted name.
	policy := Policy{}
	policy.naming_overrides = make(map[string]string)
	policy.naming_overrides["context"] = "context"

	name, decided := rename_of(&ir, &policy, "context", .Field, "CursorAndRangeVisitor")
	testing.expect(t, decided)
	testing.expect_value(t, name, "context_")
}

@(test)
test_rename_of_escapes_keywords_from_generator_default :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	// No override callback, no absolute map: the default path must escape too.
	policy := Policy{}
	name, decided := rename_of(&ir, &policy, "map", .Field, "")
	testing.expect(t, decided)
	testing.expect_value(t, name, "map_")
}

@(test)
test_apply_renames_renames_params_via_override_map :: proc(t: ^testing.T) {
	// libclang names parameters after their type (CXCursor Cursor); once the
	// type is recased to Cursor the param shadows it. Parameters must be
	// renamable through the same naming pipeline as fields.
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
	ir_add_func(&ir, Func_Decl{name = "clang_getModuleParent", return_type = int_ty, params = {{name = "Module", type = int_ty}}})

	policy := Policy{}
	policy.naming_overrides = make(map[string]string)
	policy.naming_overrides["Module"] = "module"

	apply_renames(&ir, &policy)

	testing.expect_value(t, ir.funcs[0].name, "clang_getModuleParent")
	testing.expect_value(t, ir.funcs[0].params[0].name, "module")
}

@(test)
test_apply_renames_escapes_keyword_param :: proc(t: ^testing.T) {
	// A parameter named with an Odin keyword must still emit valid syntax —
	// keyword safety gates params, same as every other emitted name.
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
	ir_add_func(&ir, Func_Decl{name = "f", return_type = int_ty, params = {{name = "context", type = int_ty}}})

	apply_renames(&ir, &Policy{})

	testing.expect_value(t, ir.funcs[0].params[0].name, "context_")
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

@(test)
test_plan_outputs_merged_is_single_unit :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"headers/a.h", "headers/b.h"})
	ir_add_func(&ir, Func_Decl{name = "fa", return_type = ir_builtin_type(&ir, .Void), home = 1})
	ir_add_func(&ir, Func_Decl{name = "fb", return_type = ir_builtin_type(&ir, .Void), home = 2})

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Merged})
	testing.expect(t, ok)
	testing.expect_value(t, len(plan.units), 1)
	testing.expect_value(t, plan.units[0].filename, "a.odin")
	testing.expect_value(t, plan.units[0].stem, "a")
	testing.expect_value(t, len(plan.units[0].decls), 2)
}

@(test)
test_plan_outputs_per_header_partitions_and_keeps_empty :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"headers/Index.h", "headers/CXString.h", "headers/Empty.h"})
	ir_add_func(&ir, Func_Decl{name = "from_index", return_type = ir_builtin_type(&ir, .Void), home = 1})
	ir_add_func(&ir, Func_Decl{name = "from_cx", return_type = ir_builtin_type(&ir, .Void), home = 2})
	// Empty.h contributes no decls.

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Per_Header, output_folder = "out"})
	testing.expect(t, ok)
	testing.expect_value(t, len(plan.units), 3)
	testing.expect_value(t, plan.units[0].filename, "Index.odin")
	testing.expect_value(t, len(plan.units[0].decls), 1)
	testing.expect_value(t, plan.units[1].filename, "CXString.odin")
	testing.expect_value(t, len(plan.units[1].decls), 1)
	testing.expect_value(t, plan.units[2].filename, "Empty.odin")
	testing.expect_value(t, len(plan.units[2].decls), 0)
}

@(test)
test_plan_outputs_per_header_rejects_duplicate_stems :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"a/foo.h", "b/foo.hpp"})

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Per_Header, output_folder = "out"})
	testing.expect(t, !ok)
	testing.expect_value(t, len(plan.units), 0)
}

@(test)
test_plan_outputs_per_header_rejects_missing_home :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"a.h"})
	// home = 0 is an internal planning error in per_header layout.
	ir_add_func(&ir, Func_Decl{name = "orphan", return_type = ir_builtin_type(&ir, .Void), home = 0})

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Per_Header, output_folder = "out"})
	testing.expect(t, !ok)
	testing.expect_value(t, len(plan.units), 0)
}

@(test)
test_plan_outputs_per_header_rejects_imports_file :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"a.h"})

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Per_Header, output_folder = "out", imports_file = "imports.odin"})
	testing.expect(t, !ok)
	testing.expect_value(t, len(plan.units), 0)
}

@(test)
test_macro_group_and_bit_set_inherit_home :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"a.h", "b.h"})
	// Two macros in different homes; first matched (pool order) is home_a.
	ir_add_macro(&ir, Macro_Decl{name = "FLG_A", tokens = {{spelling = "1", kind = .Literal}}, home = 1})
	ir_add_macro(&ir, Macro_Decl{name = "FLG_B", tokens = {{spelling = "2", kind = .Literal}}, home = 2})
	// Backing enum for bit_set lives in header b.
	_ = ir_add_enum(
		&ir,
		Enum_Decl{name = "Flag", backing = ir_builtin_type(&ir, .Int), members = {{name = "One", value = 1}, {name = "Two", value = 2}}, home = 2},
	)

	policy := Policy {
		macro_groups  = {{name = "Flg", prefix = "FLG_"}},
		enum_bit_sets = {{enum_name = "Flag", name = "Flag_Set", mode = "log2"}},
	}
	apply_macro_groups(&ir, &policy)
	apply_enum_bit_sets(&ir, &policy)

	found_enum := false
	for e in ir.enums {
		if e.name == "Flg" {
			found_enum = true
			testing.expect_value(t, e.home, Input_Header_Handle(1))
		}
	}
	testing.expect(t, found_enum)

	found_bs := false
	for bs in ir.bit_sets {
		if bs.name == "Flag_Set" {
			found_bs = true
			testing.expect_value(t, bs.home, Input_Header_Handle(2))
		}
	}
	testing.expect(t, found_bs)
}
