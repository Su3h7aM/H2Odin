package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_declarative_member_adjustments_update_matching_declarations :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	void_type := ir_builtin_type(&ir, .Void)

	_ = ir_add_record(
		&ir,
		Record_Decl{name = "BoneInfo", is_complete = true, fields = {{name = "name", type = integer_type}, {name = "parent", type = integer_type}}},
	)
	ir_add_func(&ir, Func_Decl{name = "SetConfigFlags", return_type = void_type, params = {{name = "flags", type = integer_type}}})
	ir_add_func(&ir, Func_Decl{name = "GetKeyPressed", return_type = integer_type})

	policy := Policy {
		struct_fields   = make(map[string]Member_Action),
		struct_align    = make(map[string]int),
		proc_params     = make(map[string]Member_Action),
		proc_results    = make(map[string]Member_Action),
		require_results = {"GetKeyPressed"},
	}
	policy.struct_fields["BoneInfo.name"] = Member_Action {
		tag = `fmt:"s,0"`,
	}
	policy.struct_fields["BoneInfo.parent"] = Member_Action {
		type = "i32",
	}
	policy.struct_align["BoneInfo"] = 8
	policy.proc_params["SetConfigFlags.flags"] = Member_Action {
		type    = "ConfigFlags",
		default = "0",
	}
	policy.proc_results["GetKeyPressed"] = Member_Action {
		type = "c.int",
	}

	apply_struct_adjustments(&ir, &policy)
	apply_proc_adjustments(&ir, &policy)

	record := ir.records[0]
	testing.expect_value(t, record.align, 8)
	testing.expect_value(t, record.fields[0].tag, `fmt:"s,0"`)
	testing.expect_value(t, record.fields[1].type_spelling, "i32")
	set_flags := ir.funcs[0]
	testing.expect_value(t, set_flags.params[0].type_spelling, "ConfigFlags")
	testing.expect_value(t, set_flags.params[0].default, "0")
	get_key := ir.funcs[1]
	testing.expect_value(t, get_key.return_type_spelling, "c.int")
	testing.expect(t, get_key.require_results)
}

@(test)
test_field_pointer_multi_rewrites_single_data_pointer :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	float_type := ir_builtin_type(&ir, .Float)
	pointer_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Lowered_Pointer{pointee = float_type, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}},
	)
	_ = ir_add_record(&ir, Record_Decl{name = "Mesh", is_complete = true, fields = {{name = "vertices", type = pointer_type}}})

	policy := Policy {
		struct_fields = make(map[string]Member_Action),
	}
	policy.struct_fields["Mesh.vertices"] = Member_Action {
		pointer = "multi",
	}
	apply_struct_adjustments(&ir, &policy)

	lowered := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect_value(t, lowered.kind, Pointer_Lowering_Kind.Multi)
	testing.expect_value(t, lowered.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, lowered.reason, Pointer_Lowering_Reason.Configured_Multi)
	testing.expect_value(t, ir.records[0].fields[0].type_spelling, "")
}

@(test)
test_field_pointer_multi_ignored_when_type_spelling_set :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	float_type := ir_builtin_type(&ir, .Float)
	pointer_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Lowered_Pointer{pointee = float_type, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}},
	)
	_ = ir_add_record(&ir, Record_Decl{name = "Mesh", is_complete = true, fields = {{name = "vertices", type = pointer_type}}})

	policy := Policy {
		struct_fields = make(map[string]Member_Action),
	}
	// Explicit type spelling is authoritative; multi does not rewrite.
	policy.struct_fields["Mesh.vertices"] = Member_Action {
		type    = "^f32",
		pointer = "multi",
	}
	apply_struct_adjustments(&ir, &policy)

	lowered := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect_value(t, lowered.kind, Pointer_Lowering_Kind.Single)
	testing.expect_value(t, ir.records[0].fields[0].type_spelling, "^f32")
}

@(test)
test_field_pointer_multi_soft_ignores_non_pointer :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	_ = ir_add_record(&ir, Record_Decl{name = "Mesh", is_complete = true, fields = {{name = "vertexCount", type = integer_type}}})

	policy := Policy {
		struct_fields = make(map[string]Member_Action),
	}
	policy.struct_fields["Mesh.vertexCount"] = Member_Action {
		pointer = "multi",
	}
	apply_struct_adjustments(&ir, &policy)

	// Non-pointer field: unchanged type, soft diagnostic recorded.
	testing.expect_value(t, ir.records[0].fields[0].type, integer_type)
	testing.expect(t, len(ir.diagnostics) > 0)
}

@(test)
test_require_results_non_void_mode_marks_only_non_void_returns :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	void_type := ir_builtin_type(&ir, .Void)

	ir_add_func(&ir, Func_Decl{name = "SetConfigFlags", return_type = void_type, params = {{name = "flags", type = integer_type}}})
	ir_add_func(&ir, Func_Decl{name = "GetKeyPressed", return_type = integer_type})
	ir_add_func(&ir, Func_Decl{name = "DrawTexturePro", return_type = void_type})

	policy := Policy {
		require_results_mode = .Non_Void,
	}
	apply_proc_adjustments(&ir, &policy)

	testing.expect(t, !ir.funcs[0].require_results)
	testing.expect(t, ir.funcs[1].require_results)
	testing.expect(t, !ir.funcs[2].require_results)
}

@(test)
test_require_results_mode_and_names_compose :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	void_type := ir_builtin_type(&ir, .Void)

	// Name list can mark a void procedure (edge case); mode marks non-void.
	ir_add_func(&ir, Func_Decl{name = "listed_void", return_type = void_type})
	ir_add_func(&ir, Func_Decl{name = "non_void", return_type = integer_type})
	ir_add_func(&ir, Func_Decl{name = "other_void", return_type = void_type})

	policy := Policy {
		require_results_mode = .Non_Void,
		require_results      = {"listed_void"},
	}
	apply_proc_adjustments(&ir, &policy)

	testing.expect(t, ir.funcs[0].require_results)
	testing.expect(t, ir.funcs[1].require_results)
	testing.expect(t, !ir.funcs[2].require_results)
}

@(test)
test_member_action_refinement_preserves_unspecified_decisions :: proc(t: ^testing.T) {
	declarative := Member_Action {
		type    = "Initial_Type",
		default = "DEFAULT_VALUE",
		by_ptr  = true,
	}
	callback := Member_Action {
		type = "Refined_Type",
		tag  = `fmt:"v"`,
	}

	action := refine_member_action(declarative, callback)

	testing.expect_value(t, action.type, "Refined_Type")
	testing.expect_value(t, action.tag, `fmt:"v"`)
	testing.expect_value(t, action.default, "DEFAULT_VALUE")
	testing.expect(t, !action.by_ptr)
}

@(test)
test_explicit_parameter_type_suppresses_by_pointer_action :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = integer_type, kind = .Single}})
	parameter := Param {
		name = "value",
		type = pointer_type,
	}

	action := refine_member_action(Member_Action{by_ptr = true}, Member_Action{type = "^c.int"})
	apply_parameter_action(&parameter, action, &ir, .Idiomatic, "BorrowOrSpell")

	testing.expect_value(t, parameter.type_spelling, "^c.int")
	testing.expect(t, !parameter.by_ptr)
	testing.expect_value(t, len(ir.diagnostics), 0)
}

@(test)
test_explicit_parameter_type_suppresses_multi_pointer_action :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	integer_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = integer_type, kind = .Single}})
	parameter := Param {
		name = "values",
		type = pointer_type,
	}

	action := refine_member_action(Member_Action{pointer = "multi"}, Member_Action{type = "[^]c.int"})
	apply_parameter_action(&parameter, action, &ir, .Idiomatic, "MultiOrSpell")

	testing.expect_value(t, parameter.type_spelling, "[^]c.int")
	lowered_pointer := ir_type(&ir, parameter.type).variant.(Type_Lowered_Pointer)
	testing.expect_value(t, lowered_pointer.kind, Pointer_Lowering_Kind.Single)
	testing.expect_value(t, len(ir.diagnostics), 0)
}
