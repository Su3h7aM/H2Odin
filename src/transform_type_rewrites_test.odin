package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_type_overrides_rewrite_named_declarations_and_remove_them :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	record := ir_add_record(&ir, Record_Decl{name = "Vector2", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})
	enum_declaration := ir_add_enum(&ir, Enum_Decl{name = "Vector_Kind", backing = ir_builtin_type(&ir, .Int)})
	enum_type := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enum_declaration}})

	policy := Policy {
		type_overrides = make(map[string]string),
	}
	policy.type_overrides["Vector2"] = "[2]f32"
	policy.type_overrides["Vector_Kind"] = "c.int"
	apply_configured_type_rewrites(&ir, &policy)

	rewritten, rewritten_ok := ir.types[record_type].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, rewritten_ok)
	testing.expect_value(t, rewritten.spelling, "[2]f32")
	testing.expect_value(t, rewritten.reason, Idiomatic_Reason.Config_Override)
	rewritten_enum := ir.types[enum_type].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, rewritten_enum.spelling, "c.int")
	testing.expect_value(t, len(ir.order), 0)
}

@(test)
test_type_override_takes_precedence_over_type_map :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	record := ir_add_record(&ir, Record_Decl{name = "Vector2", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})

	policy := Policy {
		type_map       = make(map[string]string),
		type_overrides = make(map[string]string),
	}
	policy.type_map["Vector2"] = "[2]f32"
	policy.type_overrides["Vector2"] = "distinct [2]f32"
	apply_configured_type_rewrites(&ir, &policy)

	rewritten := ir.types[record_type].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, rewritten.spelling, "distinct [2]f32")
}

@(test)
test_type_map_rewrites_references_and_keeps_declarations :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	record := ir_add_record(&ir, Record_Decl{name = "Vector2", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})
	alias_type := ir_builtin_type(&ir, .Long_Long)
	typedef := ir_add_typedef(&ir, Typedef_Decl{name = "Scalar", aliased = alias_type})
	typedef_type := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = typedef}})

	policy := Policy {
		type_map = make(map[string]string),
	}
	policy.type_map["Vector2"] = "[2]f32"
	policy.type_map["Scalar"] = "i64"
	apply_configured_type_rewrites(&ir, &policy)

	rewritten := ir.types[record_type].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, rewritten.spelling, "[2]f32")
	rewritten_typedef := ir.types[typedef_type].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, rewritten_typedef.spelling, "i64")
	testing.expect_value(t, ir.typedefs[typedef].aliased, alias_type)
	testing.expect_value(t, len(ir.order), 2)
	testing.expect_value(t, ir.order[0].kind, Decl_Kind.Record)
	testing.expect_value(t, ir.order[1].kind, Decl_Kind.Typedef)
}

@(test)
test_type_override_replaces_prior_idiomatic_type_decision :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	standard_type := ir_add_type(&ir, Type_Info{variant = Type_Std{name = "size_t"}})
	idiomatic_type := ir_add_type(&ir, Type_Info{variant = Type_Idiomatic_Leaf{original = standard_type, spelling = "c.size_t", reason = .Table_Preference}})

	policy := Policy {
		type_overrides = make(map[string]string),
	}
	policy.type_overrides["size_t"] = "uintptr"
	apply_configured_type_rewrites(&ir, &policy)

	rewritten := ir.types[idiomatic_type].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, rewritten.spelling, "uintptr")
	testing.expect_value(t, rewritten.reason, Idiomatic_Reason.Config_Override)
}

@(test)
test_type_map_does_not_replace_opaque_typedef_representation :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	record := ir_add_record(&ir, Record_Decl{name = "ggml_backend_buffer"})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})
	opaque_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Idiomatic_Leaf{original = record_type, spelling = SPELLING_DISTINCT_RAWPTR, reason = .Opaque_Handle}},
	)
	typedef := ir_add_typedef(&ir, Typedef_Decl{name = "ggml_backend_buffer_t", aliased = opaque_type})

	policy := Policy {
		type_map = make(map[string]string),
	}
	policy.type_map["ggml_backend_buffer"] = "backend_buffer_t"
	apply_configured_type_rewrites(&ir, &policy)

	alias := ir.types[ir.typedefs[typedef].aliased].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, alias.spelling, SPELLING_DISTINCT_RAWPTR)
	testing.expect_value(t, alias.reason, Idiomatic_Reason.Opaque_Handle)
}

@(test)
test_type_override_keeps_typedef_name_and_rewrites_alias :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	implementation := ir_add_record(&ir, Record_Decl{name = "CXTargetInfoImpl", is_complete = false})
	implementation_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = implementation}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = implementation_type, kind = .Single}})
	typedef := ir_add_typedef(&ir, Typedef_Decl{name = "CXTargetInfo", aliased = pointer_type})
	use_type := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = typedef}})

	policy := Policy {
		type_overrides = make(map[string]string),
	}
	policy.type_overrides["CXTargetInfo"] = "rawptr"
	apply_configured_type_rewrites(&ir, &policy)

	alias := ir.types[ir.typedefs[typedef].aliased].variant.(Type_Idiomatic_Leaf)
	testing.expect_value(t, alias.spelling, "rawptr")
	_, use_keeps_name := ir.types[use_type].variant.(Type_Typedef_Ref)
	testing.expect(t, use_keeps_name)
	testing.expect_value(t, len(ir.order), 2)
	testing.expect_value(t, ir.order[1].kind, Decl_Kind.Typedef)
}

@(test)
test_type_overrides_preserve_remaining_declaration_order :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	first_function := len(ir.funcs)
	ir_add_func(&ir, Func_Decl{name = "before", return_type = void_type})
	_ = ir_add_record(&ir, Record_Decl{name = "Hidden_Record", is_complete = true})
	anonymous_record := ir_add_record(&ir, Record_Decl{is_complete = true})
	_ = ir_add_enum(&ir, Enum_Decl{name = "Hidden_Enum", backing = ir_builtin_type(&ir, .Int)})
	last_function := len(ir.funcs)
	ir_add_func(&ir, Func_Decl{name = "after", return_type = void_type})

	policy := Policy {
		type_overrides = make(map[string]string),
	}
	policy.type_overrides["Hidden_Record"] = "rawptr"
	policy.type_overrides["Hidden_Enum"] = "c.int"
	policy.type_overrides[""] = "rawptr"
	apply_configured_type_rewrites(&ir, &policy)

	testing.expect_value(t, len(ir.order), 3)
	testing.expect_value(t, ir.order[0], Decl_Ref{kind = .Func, index = u32(first_function)})
	testing.expect_value(t, ir.order[1], Decl_Ref{kind = .Record, index = u32(anonymous_record)})
	testing.expect_value(t, ir.order[2], Decl_Ref{kind = .Func, index = u32(last_function)})
}
