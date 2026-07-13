package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_keyword_safe_default_suffixes_keywords :: proc(t: ^testing.T) {
	testing.expect_value(t, keyword_safe_default("ordinary"), "ordinary")

	name := keyword_safe_default("matrix")
	defer delete(name)
	testing.expect_value(t, name, "matrix_")
}

@(test)
test_package_stem_sanitization_and_identifier_check :: proc(t: ^testing.T) {
	testing.expect(t, is_odin_identifier("mylib"))
	testing.expect(t, is_odin_identifier("_private"))
	testing.expect(t, !is_odin_identifier(""))
	testing.expect(t, !is_odin_identifier("my-library"))
	testing.expect(t, !is_odin_identifier("2bad"))
	testing.expect(t, !is_odin_identifier("package")) // keyword

	testing.expect_value(t, sanitize_package_stem("my-library"), "my_library")
	testing.expect_value(t, sanitize_package_stem("lib.foo"), "lib_foo")
	testing.expect_value(t, sanitize_package_stem("2d_math"), "_2d_math")
	testing.expect_value(t, sanitize_package_stem("map"), "map_")
	testing.expect_value(t, sanitize_package_stem(""), "")
	testing.expect_value(t, sanitize_package_stem("---"), "")

	testing.expect(t, is_safe_foreign_lib("clang"))
	testing.expect(t, is_safe_foreign_lib("my-lib"))
	testing.expect(t, !is_safe_foreign_lib(""))
	testing.expect(t, !is_safe_foreign_lib("bad\"lib"))
	testing.expect(t, !is_safe_foreign_lib("bad\\lib"))
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
test_opaque_handles_incomplete_record_pointer_is_distinct :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	impl_a := ir_add_record(&ir, Record_Decl{name = "FooImpl", is_complete = false})
	impl_b := ir_add_record(&ir, Record_Decl{name = "BarImpl", is_complete = false})
	a_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = impl_a}})
	b_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = impl_b}})
	a_ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = a_ty, kind = .Single}})
	b_ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = b_ty, kind = .Single}})
	td_a := ir_add_typedef(&ir, Typedef_Decl{name = "Foo", aliased = a_ptr})
	td_b := ir_add_typedef(&ir, Typedef_Decl{name = "Bar", aliased = b_ptr})

	apply_opaque_handles(&ir, &Policy{})

	body_a, ok_a := ir.types[int(ir.typedefs[int(td_a)].aliased)].variant.(Type_Idiomatic_Leaf)
	body_b, ok_b := ir.types[int(ir.typedefs[int(td_b)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, ok_a)
	testing.expect(t, ok_b)
	testing.expect_value(t, body_a.spelling, SPELLING_DISTINCT_RAWPTR)
	testing.expect_value(t, body_b.spelling, SPELLING_DISTINCT_RAWPTR)
	testing.expect_value(t, body_a.reason, Idiomatic_Reason.Opaque_Handle)

	// Incomplete *Impl records are not emitted.
	for ref in ir.order {
		testing.expect(t, ref.kind != .Record)
	}
	// Both typedefs remain.
	found := 0
	for ref in ir.order {
		if ref.kind == .Typedef {
			found += 1
		}
	}
	testing.expect_value(t, found, 2)
}

@(test)
test_opaque_handles_same_record_stay_aliases :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	impl := ir_add_record(&ir, Record_Decl{name = "SharedImpl", is_complete = false})
	impl_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = impl}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = impl_ty, kind = .Single}})
	first := ir_add_typedef(&ir, Typedef_Decl{name = "Handle_A", aliased = ptr})
	second := ir_add_typedef(&ir, Typedef_Decl{name = "Handle_B", aliased = ptr})

	apply_opaque_handles(&ir, &Policy{})

	body, is_distinct := ir.types[int(ir.typedefs[int(first)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, is_distinct)
	testing.expect_value(t, body.spelling, SPELLING_DISTINCT_RAWPTR)

	alias, is_alias := ir.types[int(ir.typedefs[int(second)].aliased)].variant.(Type_Typedef_Ref)
	testing.expect(t, is_alias)
	testing.expect_value(t, alias.decl, first)
}

@(test)
test_opaque_handles_complete_record_pointer_unchanged :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	rec := ir_add_record(&ir, Record_Decl{name = "Complete", is_complete = true})
	rec_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = rec}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = rec_ty, kind = .Single}})
	td := ir_add_typedef(&ir, Typedef_Decl{name = "Complete_Ptr", aliased = ptr})

	apply_opaque_handles(&ir, &Policy{})

	// Still a pointer to the complete record — not collapsed to distinct rawptr.
	_, is_ptr := ir.types[int(ir.typedefs[int(td)].aliased)].variant.(Type_Lowered_Pointer)
	testing.expect(t, is_ptr)
	// Complete record stays in order.
	found_rec := false
	for ref in ir.order {
		if ref.kind == .Record && ref.index == u32(rec) {
			found_rec = true
		}
	}
	testing.expect(t, found_rec)
}

@(test)
test_opaque_tag_records_collapse_pointer_level :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	stmt := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	stmt_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = stmt}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = stmt_ty, kind = .Single}})
	pptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = ptr, kind = .Single}})

	policy := Policy{}
	// ABI mode + force handle for this name.
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["sqlite3_stmt"] = true
	apply_opaque_tag_records(&ir, &policy, .ABI)

	testing.expect(t, ir.records[int(stmt)].emit_as_handle)

	// T* → T (bare record ref)
	rec, is_rec := ir.types[int(ptr)].variant.(Type_Record_Ref)
	testing.expect(t, is_rec)
	testing.expect_value(t, rec.decl, stmt)

	// T** → still a pointer, pointee slot rewritten → emits as ^T
	outer, is_outer := ir.types[int(pptr)].variant.(Type_Lowered_Pointer)
	testing.expect(t, is_outer)
	testing.expect_value(t, outer.kind, Pointer_Lowering_Kind.Single)
	inner, is_inner := ir.types[int(outer.pointee)].variant.(Type_Record_Ref)
	testing.expect(t, is_inner)
	testing.expect_value(t, inner.decl, stmt)
}

@(test)
test_opaque_tag_records_fail_closed_when_complete :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	rec := ir_add_record(&ir, Record_Decl{name = "Complete", is_complete = true})
	rec_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = rec}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = rec_ty, kind = .Single}})

	policy := Policy{}
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["Complete"] = true
	apply_opaque_tag_records(&ir, &policy, .ABI)

	testing.expect(t, !ir.records[int(rec)].emit_as_handle)
	_, still_ptr := ir.types[int(ptr)].variant.(Type_Lowered_Pointer)
	testing.expect(t, still_ptr)
	testing.expect(t, len(ir.diagnostics) >= 1)
	found := false
	for d in ir.diagnostics {
		if d.category == .Opaque_Record_Complete {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_opaque_tag_records_idiomatic_default_collapses :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	stmt := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	stmt_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = stmt}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = stmt_ty, kind = .Single}})

	// Idiomatic, no config: incomplete tags collapse.
	apply_opaque_tag_records(&ir, &Policy{}, .Idiomatic)
	testing.expect(t, ir.records[int(stmt)].emit_as_handle)
	_, is_rec := ir.types[int(ptr)].variant.(Type_Record_Ref)
	testing.expect(t, is_rec)
}

@(test)
test_opaque_tag_records_opt_out_under_idiomatic :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	stmt := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	stmt_ty := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = stmt}})
	ptr := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = stmt_ty, kind = .Single}})

	policy := Policy{}
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["sqlite3_stmt"] = false
	apply_opaque_tag_records(&ir, &policy, .Idiomatic)

	testing.expect(t, !ir.records[int(stmt)].emit_as_handle)
	_, still_ptr := ir.types[int(ptr)].variant.(Type_Lowered_Pointer)
	testing.expect(t, still_ptr)
}

@(test)
test_opaque_handles_void_ptr_opt_in_via_types_distinct :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	void_ty := ir_builtin_type(&ir, .Void)
	raw := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = void_ty, kind = .Rawptr}})
	td_opt := ir_add_typedef(&ir, Typedef_Decl{name = "CXIndex", aliased = raw})
	td_plain := ir_add_typedef(&ir, Typedef_Decl{name = "CXFile", aliased = raw})

	policy := Policy {
		types_distinct = {"CXIndex"},
	}
	apply_opaque_handles(&ir, &policy)

	opt_body, opt_ok := ir.types[int(ir.typedefs[int(td_opt)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, opt_ok)
	testing.expect_value(t, opt_body.spelling, SPELLING_DISTINCT_RAWPTR)

	// Not listed → stays rawptr (lowered pointer or plain rawptr leaf).
	plain := ir.types[int(ir.typedefs[int(td_plain)].aliased)]
	_, still_raw := plain.variant.(Type_Lowered_Pointer)
	testing.expect(t, still_raw)
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
	// Backing enum for bit_set lives in header b. Seed a measured size so
	// the bit_set transform has a proven width.
	int_ty := ir_builtin_type(&ir, .Int)
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = int_ty, members = {{name = "One", value = 1}, {name = "Two", value = 2}}, home = 2})

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
			testing.expect_value(t, bs.backing_bits, 32)
		}
	}
	testing.expect(t, found_bs)
}

@(test)
test_bit_set_records_measured_backing_width :: proc(t: ^testing.T) {
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
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(
		&ir,
		Enum_Decl {
			name = "Config_Flag",
			backing = int_ty,
			members = {{name = "VSYNC", value = 1}, {name = "FULLSCREEN", value = 2}, {name = "MSAA", value = 4}},
		},
	)

	policy := Policy {
		enum_bit_sets = {{enum_name = "Config_Flag", name = "Config_Flags", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 1)
	if len(ir.bit_sets) == 1 {
		testing.expect_value(t, ir.bit_sets[0].backing_bits, 32)
		// The Odin size of the explicit backing must
		// match the measured C enum size (4 bytes for int).
		testing.expect_value(t, odin_type_size(bit_set_backing_spelling(ir.bit_sets[0].backing_bits)), 4)
	}
	// Members rewritten to bit positions.
	for e in ir.enums {
		if e.name == "Config_Flag" {
			testing.expect_value(t, e.members[0].value, i64(0))
			testing.expect_value(t, e.members[1].value, i64(1))
			testing.expect_value(t, e.members[2].value, i64(2))
		}
	}
}

@(test)
test_bit_set_skips_when_flag_exceeds_backing_width :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// 1-byte backing cannot hold bit position 8 (value 256).
	u8_ty := ir_builtin_type(&ir, .U_Char)
	ir.types[int(u8_ty)].variant = Type_Builtin {
		kind = .U_Char,
		size = 1,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Wide_Flag", backing = u8_ty, members = {{name = "Low", value = 1}, {name = "High", value = 256}}})

	policy := Policy {
		enum_bit_sets = {{enum_name = "Wide_Flag", name = "Wide_Flags", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	// Members must stay as C masks when the rewrite is skipped.
	testing.expect_value(t, ir.enums[0].members[1].value, i64(256))
	found_diag := false
	for d in ir.diagnostics {
		if d.category == .Bit_Set_Backing_Mismatch {
			found_diag = true
		}
	}
	testing.expect(t, found_diag)
}

@(test)
test_bit_set_skips_when_backing_size_unknown :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// Pre-seeded builtins start at size -1; do not fill.
	_ = ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = ir_builtin_type(&ir, .Int), members = {{name = "One", value = 1}}})

	policy := Policy {
		enum_bit_sets = {{enum_name = "Flag", name = "Flag_Set", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	found_diag := false
	for d in ir.diagnostics {
		if d.category == .Bit_Set_Backing_Mismatch {
			found_diag = true
		}
	}
	testing.expect(t, found_diag)
}

@(test)
test_emit_bit_set_writes_explicit_backing :: proc(t: ^testing.T) {
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
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	enum_handle := ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = int_ty, members = {{name = "One", value = 0}}})
	elem := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enum_handle}})
	decl := Bit_Set_Decl {
		name         = "Flags",
		elem         = elem,
		backing_bits = 32,
	}

	b: strings.Builder
	strings.builder_init(&b)
	imports: Emit_Imports
	emit_bit_set(&b, &ir, decl, false, &imports)
	out := strings.to_string(b)
	testing.expect(t, strings.contains(out, "Flags :: bit_set[Flag; u32]"))
}

@(test)
test_validate_package_scope_collision :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	ir_add_func(&ir, Func_Decl{name = "Open"})
	ir_add_func(&ir, Func_Decl{name = "Open"})
	validate_symbol_names(&ir)
	testing.expect(t, len(ir.diagnostics) >= 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Symbol_Collision)
}

@(test)
test_validate_field_shadow_with_second_type_use :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	enm := ir_add_enum(&ir, Enum_Decl{name = "format"})
	enm_ty := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enm}})
	fields := make([]Field, 2)
	fields[0] = Field {
		name = "format",
		type = enm_ty,
	}
	fields[1] = Field {
		name = "internalFormat",
		type = enm_ty,
	}
	ir_add_record(&ir, Record_Decl{name = "device", fields = fields, is_complete = true})
	validate_symbol_names(&ir)
	found := false
	for d in ir.diagnostics {
		if d.category == .Symbol_Collision && strings.contains(d.message, "shadows type") {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_validate_alone_self_annotation_is_ok :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	enm := ir_add_enum(&ir, Enum_Decl{name = "format"})
	enm_ty := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enm}})
	fields := make([]Field, 1)
	fields[0] = Field {
		name = "format",
		type = enm_ty,
	}
	ir_add_record(&ir, Record_Decl{name = "S", fields = fields, is_complete = true})
	validate_symbol_names(&ir)
	for d in ir.diagnostics {
		testing.expect(t, d.category != .Symbol_Collision)
	}
}
