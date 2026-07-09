package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_ir_diag_collects_messages_for_report :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	testing.expect_value(t, len(ir.diagnostics), 0)
	ir_diag(&ir, "guessed pointer lowering in %s: defaulted to ^T", `function "fill" parameter "out"`)
	ir_diag(&ir, "extern array %q has unknown size; emitted as [0]T", "version")
	testing.expect_value(t, len(ir.diagnostics), 2)
	testing.expect_value(t, ir.diagnostics[0], `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
	testing.expect_value(t, ir.diagnostics[1], `extern array "version" has unknown size; emitted as [0]T`)
}

@(test)
test_report_pointer_lowering_guesses_records_guessed_sites :: proc(t: ^testing.T) {
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
	ptr := ir_add_type(
		&ir,
		Type_Info{variant = Type_Lowered_Pointer{pointee = int_ty, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}},
	)
	ir_add_func(&ir, Func_Decl{name = "fill", return_type = ir_builtin_type(&ir, .Void), params = {{name = "out", type = ptr}}})

	report_pointer_lowering_guesses(&ir)

	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0], `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
}
