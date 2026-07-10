package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_bit_field_layout_proves_cx_index_options_shape :: proc(t: ^testing.T) {
	record := Record_Decl {
		name      = "CXIndexOptions",
		size      = 24,
		alignment = 8,
		fields    = {
			{name = "Size", bit_offset = 0, size = 4, alignment = 4},
			{name = "ThreadBackgroundPriorityForIndexing", bit_offset = 32, size = 1, alignment = 1},
			{name = "ThreadBackgroundPriorityForEditing", bit_offset = 40, size = 1, alignment = 1},
			{name = "ExcludeDeclarationsFromPCH", is_bitfield = true, bit_width = 1, bit_offset = 48},
			{name = "DisplayDiagnostics", is_bitfield = true, bit_width = 1, bit_offset = 49},
			{name = "StorePreamblesInMemory", is_bitfield = true, bit_width = 1, bit_offset = 50},
			{name = "", is_bitfield = true, bit_width = 13, bit_offset = 51},
			{name = "PreambleStoragePath", bit_offset = 64, size = 8, alignment = 8},
			{name = "InvocationEmissionPath", bit_offset = 128, size = 8, alignment = 8},
		},
	}

	layout, ok := prove_record_bit_field_layout(record, allocator = context.temp_allocator)
	testing.expect(t, ok)
	testing.expect_value(t, len(layout.runs), 1)
	if len(layout.runs) == 1 {
		testing.expect_value(t, layout.runs[0].first_field, 3)
		testing.expect_value(t, layout.runs[0].one_past_last_field, 7)
		testing.expect_value(t, layout.runs[0].backing_bits, 16)
	}
}

@(test)
test_bit_field_layout_preserves_measured_internal_gaps :: proc(t: ^testing.T) {
	record := Record_Decl {
		name      = "Gapped",
		size      = 1,
		alignment = 1,
		fields    = {{name = "a", is_bitfield = true, bit_width = 1, bit_offset = 0}, {name = "b", is_bitfield = true, bit_width = 2, bit_offset = 3}},
	}

	layout, ok := prove_record_bit_field_layout(record, allocator = context.temp_allocator)
	testing.expect(t, ok)
	testing.expect_value(t, len(layout.runs), 1)
	if len(layout.runs) == 1 {
		testing.expect_value(t, layout.runs[0].backing_bits, 8)
	}
}

@(test)
test_bit_field_layout_fails_closed_for_union_and_non_power_of_two_span :: proc(t: ^testing.T) {
	union_record := Record_Decl {
		name      = "Overlapping",
		size      = 8,
		alignment = 8,
		is_union  = true,
		fields    = {{name = "pointer", bit_offset = 0, size = 8, alignment = 8}, {name = "flag", is_bitfield = true, bit_width = 1, bit_offset = 0}},
	}
	_, union_ok := prove_record_bit_field_layout(union_record, allocator = context.temp_allocator)
	testing.expect(t, !union_ok)

	non_power_span := Record_Decl {
		name      = "ThreeBytes",
		size      = 3,
		alignment = 1,
		is_packed = true,
		fields    = {{name = "flag", is_bitfield = true, bit_width = 1, bit_offset = 0}},
	}
	_, span_ok := prove_record_bit_field_layout(non_power_span, allocator = context.temp_allocator)
	testing.expect(t, !span_ok)
}

@(test)
test_bit_field_free_record_needs_no_layout_rewrite :: proc(t: ^testing.T) {
	record := Record_Decl {
		name      = "Plain",
		size      = 8,
		alignment = 4,
		fields    = {{name = "x", bit_offset = 0, size = 4, alignment = 4}, {name = "y", bit_offset = 32, size = 1, alignment = 1}},
	}

	layout, ok := prove_record_bit_field_layout(record, allocator = context.temp_allocator)
	testing.expect(t, ok)
	testing.expect_value(t, len(layout.runs), 0)
}

@(test)
test_bit_field_layout_rejects_user_authored_adjacent_field_type :: proc(t: ^testing.T) {
	// ir_init allocates types and input_headers; free both via an arena so
	// partial delete(ir.types) does not leave a 128B leak (and hide real ones).
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	record := Record_Decl {
		name      = "Configured",
		size      = 8,
		alignment = 4,
		fields    = {
			{name = "prefix", type = ir_builtin_type(&ir, .Int), type_spelling = "[16]u8", bit_offset = 0, size = 4, alignment = 4},
			{name = "flag", type = ir_builtin_type(&ir, .U_Int), is_bitfield = true, bit_width = 1, bit_offset = 32},
		},
	}

	_, ok := prove_record_bit_field_layout(record, &ir, context.temp_allocator)
	testing.expect(t, !ok)
}
