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
test_report_pointer_lowering_guesses_only_reports_emitted_types :: proc(t: ^testing.T) {
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
	ir_add_record(&ir, Record_Decl{name = "Opaque", is_complete = true, has_unrepresentable_fields = true, fields = {{name = "data", type = ptr}}})
	ir_add_record(
		&ir,
		Record_Decl {
			name = "Opaque_Bit_Fields",
			size = 8,
			alignment = 8,
			is_complete = true,
			is_union = true,
			fields = {{name = "data", type = ptr, size = 8, alignment = 8}, {name = "flag", is_bitfield = true, bit_width = 1}},
		},
	)

	bit_field_plan := plan_bit_field_emission(&ir)
	testing.expect(t, bit_field_plan.opaque_records[1])
	report_pointer_lowering_guesses(&ir, bit_field_plan.opaque_records)

	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Pointer_Lowering_Guess)
	testing.expect_value(t, ir.diagnostics[0].message, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
}

@(test)
test_pointer_lowering_guesses_ignore_explicit_type_spellings :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_type := ir_builtin_type(&ir, .Int)
	void_type := ir_builtin_type(&ir, .Void)
	hidden_pointer := ir_add_type(
		&ir,
		Type_Info{variant = Type_Lowered_Pointer{pointee = int_type, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}},
	)
	outer_proc := ir_add_type(
		&ir,
		Type_Info{variant = Type_Proc{return_type = void_type, params = {{name = "value", type = hidden_pointer, type_spelling = "rawptr"}}}},
	)
	ir_add_func(
		&ir,
		Func_Decl {
			name = "read",
			return_type = hidden_pointer,
			return_type_spelling = "rawptr",
			params = {{name = "value", type = hidden_pointer, type_spelling = "rawptr"}},
		},
	)
	ir_add_record(&ir, Record_Decl{name = "Value", is_complete = true, fields = {{name = "data", type = hidden_pointer, type_spelling = "rawptr"}}})
	ir_add_typedef(&ir, Typedef_Decl{name = "Read_Callback", aliased = outer_proc})

	report_pointer_lowering_guesses(&ir)

	testing.expect_value(t, len(ir.diagnostics), 0)
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

@(test)
test_diag_verbose_guidance_covers_active_categories :: proc(t: ^testing.T) {
	// Active categories should document cause + config fix for -verbose.
	// Reserved categories may return empty until their emitters land.
	active := [?]Diag_Category{.Pointer_Lowering_Guess, .Bit_Field_Layout_Fallback, .Naming_Ambiguity, .Incomplete_Extern_Array, .Opaque_Record_Complete}
	for c in active {
		cause, fix := diag_verbose_guidance(c)
		testing.expectf(t, cause != "", "category %v should have a cause", c)
		testing.expectf(t, fix != "", "category %v should have a fix", c)
	}
}
