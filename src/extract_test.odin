package h2odin

import vmem "core:mem/virtual"
import "core:testing"

@(test)
test_extract_captures_bit_field_widths_offsets_and_record_layout :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	ok := extract({"tests/fixtures/bit_fields.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	found := false
	for record in ir.records {
		if record.name != "H2O_IndexOptions" {
			continue
		}
		found = true
		testing.expect_value(t, len(record.fields), 9)
		testing.expect(t, record.size > 0)
		testing.expect(t, record.alignment > 0)
		if len(record.fields) == 9 {
			testing.expect(t, record.fields[3].is_bitfield)
			testing.expect_value(t, record.fields[3].bit_width, i64(1))
			testing.expect_value(t, record.fields[3].bit_offset, i64(48))
			testing.expect_value(t, record.fields[6].name, "")
			testing.expect_value(t, record.fields[6].bit_width, i64(13))
			testing.expect_value(t, record.fields[6].bit_offset, i64(51))
			testing.expect_value(t, record.fields[7].bit_offset, i64(64))
		}
		break
	}
	testing.expect(t, found)
}
