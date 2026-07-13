package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_length_like_parameter_names_are_case_insensitive :: proc(t: ^testing.T) {
	matching_names := [?]string{"n", "LEN", "Length", "_LEN", "item_count", "byte_SIZE", "value_Num"}
	for name in matching_names {
		testing.expect(t, name_is_length_like(name))
	}
	non_matching_names := [?]string{"", "index", "number", "filename", "size_hint"}
	for name in non_matching_names {
		testing.expect(t, !name_is_length_like(name))
	}
}

@(test)
test_analyze_records_adjacent_integer_lengths_for_data_pointers :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	float_type := ir_builtin_type(&ir, .Float)
	data_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = float_type}})
	procedure_type := ir_add_type(&ir, Type_Info{variant = Type_Proc{return_type = void_type}})
	procedure_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = procedure_type}})

	ir_add_func(
		&ir,
		Func_Decl{name = "read_values", return_type = void_type, params = {{name = "values", type = data_pointer_type}, {name = "count", type = int_type}}},
	)
	ir_add_func(
		&ir,
		Func_Decl{name = "write_values", return_type = void_type, params = {{name = "len", type = int_type}, {name = "values", type = data_pointer_type}}},
	)
	ir_add_func(
		&ir,
		Func_Decl {
			name = "register_callback",
			return_type = void_type,
			params = {{name = "callback", type = procedure_pointer_type}, {name = "count", type = int_type}},
		},
	)
	ir_add_func(
		&ir,
		Func_Decl {
			name = "measure_values",
			return_type = void_type,
			params = {{name = "values", type = data_pointer_type}, {name = "size", type = float_type}},
		},
	)

	analyze(&ir)

	read_values := ir.funcs[0].params[0].facts
	testing.expect(t, read_values.has_length_like_neighbour)
	testing.expect_value(t, read_values.length_param_index, 1)

	write_values := ir.funcs[1].params[1].facts
	testing.expect(t, write_values.has_length_like_neighbour)
	testing.expect_value(t, write_values.length_param_index, 0)

	testing.expect(t, !ir.funcs[2].params[0].facts.has_length_like_neighbour)
	testing.expect(t, !ir.funcs[3].params[0].facts.has_length_like_neighbour)
}

@(test)
test_analyze_replaces_stale_parameter_facts :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = int_type}})
	ir_add_func(&ir, Func_Decl{return_type = void_type, params = {{name = "values", type = pointer_type}, {name = "count", type = int_type}}})

	analyze(&ir)
	testing.expect(t, ir.funcs[0].params[0].facts.has_length_like_neighbour)

	ir.funcs[0].params[1].name = "mode"
	analyze(&ir)
	testing.expect(t, !ir.funcs[0].params[0].facts.has_length_like_neighbour)
}
