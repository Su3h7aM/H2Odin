package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_transform_materializes_wrapper_after_renaming :: proc(t: ^testing.T) {
	generation_arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&generation_arena), nil)
	defer vmem.arena_destroy(&generation_arena)
	context.allocator = vmem.arena_allocator(&generation_arena)

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Pointer{pointee = int_type}})
	ir_add_func(
		&ir,
		Func_Decl {
			name = "consume",
			return_type = void_type,
			params = {
				{name = "items", type = pointer_type},
				{name = "count", type = int_type, type_spelling = "c.int"},
				{name = "out_total", type = pointer_type},
			},
		},
	)

	policy: Policy
	policy.naming_overrides = make(map[string]string)
	policy.naming_overrides["consume"] = "Consume"
	policy.naming_overrides["items"] = "values"
	policy.naming_overrides["out_total"] = "total"
	policy.proc_wrappers = make(map[string]Wrapper_Rule)
	policy.proc_wrappers["consume"] = Wrapper_Rule {
		out_params = {"out_total"},
		slices     = {{pointer = "items", count = "count"}},
	}

	{
		scratch_arena: vmem.Arena
		testing.expect_value(t, vmem.arena_init_growing(&scratch_arena), nil)
		defer vmem.arena_destroy(&scratch_arena)
		context.temp_allocator = vmem.arena_allocator(&scratch_arena)

		transform(&ir, .Idiomatic, &policy)
	}

	testing.expect_value(t, len(ir.funcs), 1)
	testing.expect_value(t, ir.funcs[0].name, "_Consume")
	testing.expect_value(t, ir.funcs[0].link_name, "consume")
	testing.expect_value(t, ir.funcs[0].params[0].name, "values")

	testing.expect_value(t, len(ir.wrappers), 1)
	wrapper := ir.wrappers[0]
	testing.expect_value(t, wrapper.name, "Consume")
	testing.expect_value(t, wrapper.target, Decl_Handle(0))
	testing.expect_value(t, len(wrapper.out_params), 1)
	testing.expect_value(t, wrapper.out_params[0].param_index, 2)
	testing.expect_value(t, wrapper.out_params[0].result_name, "total")
	testing.expect_value(t, len(wrapper.slices), 1)
	testing.expect_value(t, wrapper.slices[0].pointer_index, 0)
	testing.expect_value(t, wrapper.slices[0].count_index, 1)
	testing.expect_value(t, wrapper.slices[0].public_name, "values")

	testing.expect_value(t, len(ir.order), 2)
	testing.expect_value(t, ir.order[0], Decl_Ref{kind = .Func, index = 0})
	testing.expect_value(t, ir.order[1], Decl_Ref{kind = .Wrapper, index = 0})
}

@(test)
test_transform_rejects_pointer_spelling_for_wrapper_slice_count :: proc(t: ^testing.T) {
	generation_arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&generation_arena), nil)
	defer vmem.arena_destroy(&generation_arena)
	context.allocator = vmem.arena_allocator(&generation_arena)

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = int_type, kind = .Single}})
	ir_add_func(
		&ir,
		Func_Decl {
			name = "consume",
			return_type = void_type,
			params = {{name = "items", type = pointer_type}, {name = "count", type = int_type, type_spelling = "^c.int"}},
		},
	)

	policy: Policy
	policy.proc_wrappers = make(map[string]Wrapper_Rule)
	policy.proc_wrappers["consume"] = Wrapper_Rule {
		slices = {{pointer = "items", count = "count"}},
	}

	{
		scratch_arena: vmem.Arena
		testing.expect_value(t, vmem.arena_init_growing(&scratch_arena), nil)
		defer vmem.arena_destroy(&scratch_arena)
		context.temp_allocator = vmem.arena_allocator(&scratch_arena)

		transform(&ir, .Idiomatic, &policy)
	}

	testing.expect_value(t, len(ir.wrappers), 0)
	found_wrapper_failure := false
	for diagnostic in ir.diagnostics {
		if diagnostic.category == .Wrapper_Plan_Failed {
			found_wrapper_failure = true
			break
		}
	}
	testing.expect(t, found_wrapper_failure)
}

@(test)
test_transform_rejects_multipointer_spelling_for_wrapper_out_parameter :: proc(t: ^testing.T) {
	generation_arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&generation_arena), nil)
	defer vmem.arena_destroy(&generation_arena)
	context.allocator = vmem.arena_allocator(&generation_arena)

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	int_type := ir_builtin_type(&ir, .Int)
	pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = int_type, kind = .Single}})
	ir_add_func(&ir, Func_Decl{name = "read_value", return_type = void_type, params = {{name = "out_value", type = pointer_type, type_spelling = "[^]c.int"}}})

	policy: Policy
	policy.proc_wrappers = make(map[string]Wrapper_Rule)
	policy.proc_wrappers["read_value"] = Wrapper_Rule {
		out_params = {"out_value"},
	}

	{
		scratch_arena: vmem.Arena
		testing.expect_value(t, vmem.arena_init_growing(&scratch_arena), nil)
		defer vmem.arena_destroy(&scratch_arena)
		context.temp_allocator = vmem.arena_allocator(&scratch_arena)

		transform(&ir, .Idiomatic, &policy)
	}

	testing.expect_value(t, len(ir.wrappers), 0)
	found_wrapper_failure := false
	for diagnostic in ir.diagnostics {
		if diagnostic.category == .Wrapper_Plan_Failed {
			found_wrapper_failure = true
			break
		}
	}
	testing.expect(t, found_wrapper_failure)
}
