package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_plan_outputs_merged_keeps_only_live_declarations_in_order :: proc(t: ^testing.T) {
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
	ir_add_func(&ir, Func_Decl{name = "first", return_type = ir_builtin_type(&ir, .Void), home = 1})
	append(&ir.order, Decl_Ref{})
	ir_add_func(&ir, Func_Decl{name = "second", return_type = ir_builtin_type(&ir, .Void), home = 2})

	plan, ok := plan_outputs(&ir, &Policy{output_layout = .Merged})
	testing.expect(t, ok)
	testing.expect_value(t, len(plan.units), 1)
	testing.expect_value(t, plan.units[0].filename, "a.odin")
	testing.expect_value(t, plan.units[0].stem, "a")
	testing.expect_value(t, len(plan.units[0].decls), 2)
	testing.expect_value(t, plan.units[0].decls[0], Decl_Ref{kind = .Func, index = 0})
	testing.expect_value(t, plan.units[0].decls[1], Decl_Ref{kind = .Func, index = 1})
}

@(test)
test_plan_outputs_per_header_partitions_and_keeps_empty_units :: proc(t: ^testing.T) {
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
