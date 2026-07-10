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

@(test)
test_extract_keeps_sibling_input_typedef_names :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// Both headers are inputs: a includes b, and use sites in a must keep
	// Sibling_Id rather than peeling to the underlying int.
	ok := extract({"tests/fixtures/m13_sibling_a.h", "tests/fixtures/m13_sibling_b.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	sibling_typedef := false
	for td in ir.typedefs {
		if td.name == "Sibling_Id" {
			sibling_typedef = true
			break
		}
	}
	testing.expect(t, sibling_typedef)

	use_sibling := false
	make_sibling := false
	for func in ir.funcs {
		if func.name == "m13_use_sibling" {
			use_sibling = true
			testing.expect_value(t, len(func.params), 1)
			if len(func.params) == 1 {
				_, is_td := ir_type(&ir, func.params[0].type).variant.(Type_Typedef_Ref)
				testing.expect(t, is_td)
			}
			_, ret_td := ir_type(&ir, func.return_type).variant.(Type_Typedef_Ref)
			testing.expect(t, ret_td)
		}
		if func.name == "m13_make_sibling" {
			make_sibling = true
		}
	}
	testing.expect(t, use_sibling)
	testing.expect(t, make_sibling)

	// Sibling decls captured once despite a.h including b.h and b.h also
	// being its own main-file TU.
	func_count := 0
	for func in ir.funcs {
		if func.name == "m13_make_sibling" || func.name == "m13_use_sibling" {
			func_count += 1
		}
	}
	testing.expect_value(t, func_count, 2)

	macro_count := 0
	for m in ir.macros {
		if m.name == "M13_SIBLING_FLAG" {
			macro_count += 1
		}
	}
	testing.expect_value(t, macro_count, 1)
}

@(test)
test_extract_peels_typedef_from_non_input_include :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// Only the main header is an input; Hidden_Id lives in an unlisted include
	// and must peel to the underlying builtin at the use site.
	ok := extract({"tests/fixtures/m13_peel_main.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	for td in ir.typedefs {
		testing.expect(t, td.name != "Hidden_Id")
	}

	found := false
	for func in ir.funcs {
		if func.name != "m13_use_hidden" {
			continue
		}
		found = true
		testing.expect_value(t, len(func.params), 1)
		if len(func.params) == 1 {
			_, is_builtin := ir_type(&ir, func.params[0].type).variant.(Type_Builtin)
			testing.expect(t, is_builtin)
		}
	}
	testing.expect(t, found)
}
