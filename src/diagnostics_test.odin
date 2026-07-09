package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_ir_diag_collects_categorized_messages :: proc(t: ^testing.T) {
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
	ir_diag(&ir, .Pointer_Lowering_Guess, "guessed pointer lowering in %s: defaulted to ^T", `function "fill" parameter "out"`)
	ir_diag(&ir, .Incomplete_Extern_Array, "extern array %q has unknown size; emitted as [0]T", "version")
	testing.expect_value(t, len(ir.diagnostics), 2)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Pointer_Lowering_Guess)
	testing.expect_value(t, ir.diagnostics[0].message, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
	testing.expect_value(t, ir.diagnostics[1].category, Diag_Category.Incomplete_Extern_Array)
	testing.expect_value(t, ir.diagnostics[1].message, `extern array "version" has unknown size; emitted as [0]T`)
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
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Pointer_Lowering_Guess)
	testing.expect_value(t, ir.diagnostics[0].message, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
}

@(test)
test_diag_resolve_severity_default_warn_and_local_override :: proc(t: ^testing.T) {
	policy: Policy
	// default zero: all Warn
	d_global := Diagnostic {
		category = .Pointer_Lowering_Guess,
		message  = "msg",
	}
	testing.expect_value(t, diag_resolve_severity(d_global, &policy), Diag_Severity.Warn)

	policy.diag_severity[.Pointer_Lowering_Guess] = .Error
	testing.expect_value(t, diag_resolve_severity(d_global, &policy), Diag_Severity.Error)

	// Local constructor override beats global.
	d_local := Diagnostic {
		category       = .Pointer_Lowering_Guess,
		message        = "msg",
		local_severity = Diag_Severity.Warn,
	}
	testing.expect_value(t, diag_resolve_severity(d_local, &policy), Diag_Severity.Warn)
}

@(test)
test_diag_category_roundtrip_names :: proc(t: ^testing.T) {
	for c in Diag_Category {
		name := diag_category_name(c)
		back, ok := diag_category_from_name(name)
		testing.expectf(t, ok, "category %v name %q should round-trip", c, name)
		testing.expect_value(t, back, c)
	}
	_, bad := diag_category_from_name("not_a_category")
	testing.expect(t, !bad)
}
