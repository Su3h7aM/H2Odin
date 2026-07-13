package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_pointer_lowering_classifies_pointer_semantics :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	const_char_type := ir_add_type(&ir, Type_Info{is_const = true, variant = Type_Builtin{kind = .Char_Signed, size = 1}})
	proc_type := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_type}})

	void_pointer := lower_pointer(&ir, void_type)
	testing.expect_value(t, void_pointer.kind, Pointer_Lowering_Kind.Rawptr)
	testing.expect_value(t, void_pointer.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, void_pointer.reason, Pointer_Lowering_Reason.Void_Pointer)

	string_pointer := lower_pointer(&ir, const_char_type)
	testing.expect_value(t, string_pointer.kind, Pointer_Lowering_Kind.CString)
	testing.expect_value(t, string_pointer.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, string_pointer.reason, Pointer_Lowering_Reason.Const_Char_Pointer)

	procedure_pointer := lower_pointer(&ir, proc_type)
	testing.expect_value(t, procedure_pointer.kind, Pointer_Lowering_Kind.Proc)
	testing.expect_value(t, procedure_pointer.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, procedure_pointer.reason, Pointer_Lowering_Reason.Function_Pointer)

	data_pointer := lower_pointer(&ir, int_type)
	testing.expect_value(t, data_pointer.kind, Pointer_Lowering_Kind.Single)
	testing.expect_value(t, data_pointer.confidence, Pointer_Lowering_Confidence.Guessed)
	testing.expect_value(t, data_pointer.reason, Pointer_Lowering_Reason.Single_Pointer_Default)
}

@(test)
test_array_parameter_decay_proves_multi_pointer :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = int_type, is_array_param_decay = true}})

	lower_type(&ir, pointer_type)
	lowered_pointer := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect_value(t, lowered_pointer.kind, Pointer_Lowering_Kind.Multi)
	testing.expect_value(t, lowered_pointer.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, lowered_pointer.reason, Pointer_Lowering_Reason.Array_Param_Decay)
}

@(test)
test_force_multi_pointer_records_configured_proof :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Lowered_Pointer{pointee = int_type, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}},
	)

	testing.expect(t, force_multi_pointer(&ir, pointer_type, .Configured_Multi))
	lowered_pointer := ir.types[int(pointer_type)].variant.(Type_Lowered_Pointer)
	testing.expect_value(t, lowered_pointer.kind, Pointer_Lowering_Kind.Multi)
	testing.expect_value(t, lowered_pointer.confidence, Pointer_Lowering_Confidence.Proven)
	testing.expect_value(t, lowered_pointer.reason, Pointer_Lowering_Reason.Configured_Multi)
}

@(test)
test_leaf_substitution_preserves_semantic_type_family :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	long_type := ir_builtin_type(&ir, .Long)
	float_type := ir_builtin_type(&ir, .Float)
	double_type := ir_builtin_type(&ir, .Double)
	bool_type := ir_builtin_type(&ir, .Bool)
	matching_float_type := ir_add_type(&ir, Type_Info{variant = Type_Builtin{kind = .Float, size = 4}})
	matching_bool_type := ir_add_type(&ir, Type_Info{variant = Type_Builtin{kind = .Bool, size = 1}})
	ir.types[int(int_type)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	ir.types[int(long_type)].variant = Type_Builtin {
		kind = .Long,
		size = 4,
	}
	ir.types[int(float_type)].variant = Type_Builtin {
		kind = .Float,
		size = 8,
	}
	ir.types[int(double_type)].variant = Type_Builtin {
		kind = .Double,
		size = 8,
	}
	ir.types[int(bool_type)].variant = Type_Builtin {
		kind = .Bool,
		size = 2,
	}

	substitute_leaf_types(&ir)

	int_leaf, int_was_substituted := ir.types[int(int_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, int_was_substituted)
	testing.expect_value(t, int_leaf.spelling, "i32")
	testing.expect_value(t, int_leaf.reason, Idiomatic_Reason.Table_Preference)

	long_leaf, long_was_substituted := ir.types[int(long_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, long_was_substituted)
	testing.expect_value(t, long_leaf.spelling, "i32")
	testing.expect_value(t, long_leaf.reason, Idiomatic_Reason.Derived_From_Measurement)
	double_leaf, double_was_substituted := ir.types[int(double_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, double_was_substituted)
	testing.expect_value(t, double_leaf.spelling, "f64")
	testing.expect_value(t, double_leaf.reason, Idiomatic_Reason.Table_Preference)
	float_leaf, float_was_substituted := ir.types[int(matching_float_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, float_was_substituted)
	testing.expect_value(t, float_leaf.spelling, "f32")
	testing.expect_value(t, float_leaf.reason, Idiomatic_Reason.Table_Preference)
	bool_leaf, bool_was_substituted := ir.types[int(matching_bool_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, bool_was_substituted)
	testing.expect_value(t, bool_leaf.spelling, "bool")
	testing.expect_value(t, bool_leaf.reason, Idiomatic_Reason.Table_Preference)

	_, mismatched_float_was_substituted := ir.types[int(float_type)].variant.(Type_Idiomatic_Leaf)
	_, mismatched_bool_was_substituted := ir.types[int(bool_type)].variant.(Type_Idiomatic_Leaf)
	testing.expect(t, !mismatched_float_was_substituted)
	testing.expect(t, !mismatched_bool_was_substituted)
	testing.expect_value(t, len(ir.diagnostics), 2)
	for diagnostic in ir.diagnostics {
		testing.expect_value(t, diagnostic.category, Diag_Category.Unresolved_Idiomatic_Leaf)
	}
}
