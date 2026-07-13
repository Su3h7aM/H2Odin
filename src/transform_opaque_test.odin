package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_opaque_pointer_typedef_canonicalizes_direct_record_pointers :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	implementation := ir_add_record(&ir, Record_Decl{name = "Implementation", is_complete = false})
	handle_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = implementation}})
	handle_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = handle_record_type, kind = .Single}})
	handle := ir_add_typedef(&ir, Typedef_Decl{name = "Handle", aliased = handle_pointer_type})

	direct_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = implementation}})
	direct_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = direct_record_type, kind = .Single}})
	ir_add_func(
		&ir,
		Func_Decl{name = "use_implementation", return_type = ir_builtin_type(&ir, .Void), params = {{name = "implementation", type = direct_pointer_type}}},
	)
	field_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = implementation}})
	field_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = field_record_type, kind = .Single}})
	_ = ir_add_record(&ir, Record_Decl{name = "Holder", is_complete = true, fields = {{name = "implementation", type = field_pointer_type}}})

	apply_opaque_types(&ir, &Policy{}, .ABI)

	_, handle_is_distinct := ir_type(&ir, ir.typedefs[handle].aliased).variant.(Type_Idiomatic_Leaf)
	testing.expect(t, handle_is_distinct)
	direct_reference, direct_reference_is_handle := ir_type(&ir, direct_pointer_type).variant.(Type_Typedef_Ref)
	testing.expect(t, direct_reference_is_handle)
	testing.expect_value(t, direct_reference.decl, handle)
	field_reference, field_reference_is_handle := ir_type(&ir, field_pointer_type).variant.(Type_Typedef_Ref)
	testing.expect(t, field_reference_is_handle)
	testing.expect_value(t, field_reference.decl, handle)

	record_is_emitted := false
	for declaration in ir.order {
		if declaration.kind == .Record && declaration.index == u32(implementation) {
			record_is_emitted = true
			break
		}
	}
	testing.expect(t, !record_is_emitted)
}

@(test)
test_opaque_pointer_typedefs_become_distinct_handles :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	foo_implementation := ir_add_record(&ir, Record_Decl{name = "FooImpl", is_complete = false})
	bar_implementation := ir_add_record(&ir, Record_Decl{name = "BarImpl", is_complete = false})
	foo_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = foo_implementation}})
	bar_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = bar_implementation}})
	foo_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = foo_record_type, kind = .Single}})
	bar_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = bar_record_type, kind = .Single}})
	foo_typedef := ir_add_typedef(&ir, Typedef_Decl{name = "Foo", aliased = foo_pointer_type})
	bar_typedef := ir_add_typedef(&ir, Typedef_Decl{name = "Bar", aliased = bar_pointer_type})

	apply_opaque_pointer_typedefs(&ir, &Policy{})

	foo_handle_type, foo_is_handle := ir.types[int(ir.typedefs[int(foo_typedef)].aliased)].variant.(Type_Idiomatic_Leaf)
	bar_handle_type, bar_is_handle := ir.types[int(ir.typedefs[int(bar_typedef)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, foo_is_handle)
	testing.expect(t, bar_is_handle)
	testing.expect_value(t, foo_handle_type.spelling, SPELLING_DISTINCT_RAWPTR)
	testing.expect_value(t, bar_handle_type.spelling, SPELLING_DISTINCT_RAWPTR)
	testing.expect_value(t, foo_handle_type.reason, Idiomatic_Reason.Opaque_Handle)

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
test_opaque_pointer_typedefs_preserve_shared_record_aliases :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	implementation := ir_add_record(&ir, Record_Decl{name = "SharedImpl", is_complete = false})
	implementation_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = implementation}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = implementation_type, kind = .Single}})
	first := ir_add_typedef(&ir, Typedef_Decl{name = "Handle_A", aliased = pointer_type})
	second := ir_add_typedef(&ir, Typedef_Decl{name = "Handle_B", aliased = pointer_type})

	apply_opaque_pointer_typedefs(&ir, &Policy{})

	body, is_distinct := ir.types[int(ir.typedefs[int(first)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, is_distinct)
	testing.expect_value(t, body.spelling, SPELLING_DISTINCT_RAWPTR)

	alias, is_alias := ir.types[int(ir.typedefs[int(second)].aliased)].variant.(Type_Typedef_Ref)
	testing.expect(t, is_alias)
	testing.expect_value(t, alias.decl, first)
}

@(test)
test_opaque_pointer_typedef_keeps_complete_record_pointer :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	record_reference := ir_add_record(&ir, Record_Decl{name = "Complete", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record_reference}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = record_type, kind = .Single}})
	typedef_handle := ir_add_typedef(&ir, Typedef_Decl{name = "Complete_Ptr", aliased = pointer_type})

	apply_opaque_pointer_typedefs(&ir, &Policy{})

	// Still a pointer to the complete record — not collapsed to distinct rawptr.
	_, is_ptr := ir.types[int(ir.typedefs[int(typedef_handle)].aliased)].variant.(Type_Lowered_Pointer)
	testing.expect(t, is_ptr)
	// Complete record stays in order.
	found_rec := false
	for ref in ir.order {
		if ref.kind == .Record && ref.index == u32(record_reference) {
			found_rec = true
		}
	}
	testing.expect(t, found_rec)
}

@(test)
test_opaque_tag_record_collapses_one_pointer_level :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	statement_record := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	statement_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = statement_record}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = statement_type, kind = .Single}})
	pointer_to_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = pointer_type, kind = .Single}})

	policy := Policy{}
	// ABI mode + force handle for this name.
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["sqlite3_stmt"] = true
	apply_opaque_tag_records(&ir, &policy, .ABI)

	testing.expect(t, ir.records[int(statement_record)].emit_as_handle)

	// T* → T (bare record ref)
	record_reference, is_rec := ir.types[int(pointer_type)].variant.(Type_Record_Ref)
	testing.expect(t, is_rec)
	testing.expect_value(t, record_reference.decl, statement_record)

	// T** → still a pointer, pointee slot rewritten → emits as ^T
	outer, is_outer := ir.types[int(pointer_to_pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect(t, is_outer)
	testing.expect_value(t, outer.kind, Pointer_Lowering_Kind.Single)
	inner, is_inner := ir.types[int(outer.pointee)].variant.(Type_Record_Ref)
	testing.expect(t, is_inner)
	testing.expect_value(t, inner.decl, statement_record)
}

@(test)
test_opaque_tag_record_rejects_complete_record :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	record_reference := ir_add_record(&ir, Record_Decl{name = "Complete", is_complete = true})
	record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record_reference}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = record_type, kind = .Single}})

	policy := Policy{}
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["Complete"] = true
	apply_opaque_tag_records(&ir, &policy, .ABI)

	testing.expect(t, !ir.records[int(record_reference)].emit_as_handle)
	_, still_ptr := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
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
test_opaque_tag_record_collapses_by_default_in_idiomatic_mode :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	statement_record := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	statement_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = statement_record}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = statement_type, kind = .Single}})

	// Idiomatic, no config: incomplete tags collapse.
	apply_opaque_tag_records(&ir, &Policy{}, .Idiomatic)
	testing.expect(t, ir.records[int(statement_record)].emit_as_handle)
	_, is_rec := ir.types[int(pointer_type)].variant.(Type_Record_Ref)
	testing.expect(t, is_rec)
}

@(test)
test_opaque_tag_record_allows_idiomatic_opt_out :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	statement_record := ir_add_record(&ir, Record_Decl{name = "sqlite3_stmt", is_complete = false})
	statement_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = statement_record}})
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = statement_type, kind = .Single}})

	policy := Policy{}
	policy.types_opaque = make(map[string]bool)
	policy.types_opaque["sqlite3_stmt"] = false
	apply_opaque_tag_records(&ir, &policy, .Idiomatic)

	testing.expect(t, !ir.records[int(statement_record)].emit_as_handle)
	_, still_ptr := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect(t, still_ptr)
}

@(test)
test_opaque_void_pointer_typedef_requires_distinct_opt_in :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	void_type := ir_builtin_type(&ir, .Void)
	raw_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = void_type, kind = .Rawptr}})
	distinct_typedef := ir_add_typedef(&ir, Typedef_Decl{name = "CXIndex", aliased = raw_pointer_type})
	plain_typedef := ir_add_typedef(&ir, Typedef_Decl{name = "CXFile", aliased = raw_pointer_type})

	policy := Policy {
		types_distinct = {"CXIndex"},
	}
	apply_opaque_pointer_typedefs(&ir, &policy)

	distinct_handle_type, distinct_is_handle := ir.types[int(ir.typedefs[int(distinct_typedef)].aliased)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, distinct_is_handle)
	testing.expect_value(t, distinct_handle_type.spelling, SPELLING_DISTINCT_RAWPTR)

	// Not listed → stays rawptr (lowered pointer or plain rawptr leaf).
	plain := ir.types[int(ir.typedefs[int(plain_typedef)].aliased)]
	_, still_raw := plain.variant.(Type_Lowered_Pointer)
	testing.expect(t, still_raw)
}

@(test)
test_resolve_record_reference_handles_long_typedef_chains :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	record := ir_add_record(&ir, Record_Decl{name = "Record", is_complete = false})
	current_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = record}})
	for _ in 0 ..< 40 {
		typedef := ir_add_typedef(&ir, Typedef_Decl{aliased = current_type})
		current_type = ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = typedef}})
	}

	resolved_record, resolved := resolve_record_reference(&ir, current_type)
	testing.expect(t, resolved)
	testing.expect_value(t, resolved_record, record)
}

@(test)
test_resolve_record_reference_stops_at_typedef_cycle :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	first_typedef := ir_add_typedef(&ir, Typedef_Decl{})
	second_typedef := ir_add_typedef(&ir, Typedef_Decl{})
	first_reference := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = first_typedef}})
	second_reference := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = second_typedef}})
	ir.typedefs[first_typedef].aliased = second_reference
	ir.typedefs[second_typedef].aliased = first_reference

	_, resolved := resolve_record_reference(&ir, first_reference)
	testing.expect(t, !resolved)
}
