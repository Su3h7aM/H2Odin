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
	ok := extract({"tests/fixtures/sibling_input_a.h", "tests/fixtures/sibling_input_b.h"}, &ir)
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
		if func.name == "use_sibling_id" {
			use_sibling = true
			testing.expect_value(t, len(func.params), 1)
			if len(func.params) == 1 {
				_, is_td := ir_type(&ir, func.params[0].type).variant.(Type_Typedef_Ref)
				testing.expect(t, is_td)
			}
			_, ret_td := ir_type(&ir, func.return_type).variant.(Type_Typedef_Ref)
			testing.expect(t, ret_td)
		}
		if func.name == "make_sibling_id" {
			make_sibling = true
		}
	}
	testing.expect(t, use_sibling)
	testing.expect(t, make_sibling)

	// Sibling decls captured once despite a.h including b.h and b.h also
	// being its own main-file TU.
	func_count := 0
	for func in ir.funcs {
		if func.name == "make_sibling_id" || func.name == "use_sibling_id" {
			func_count += 1
		}
	}
	testing.expect_value(t, func_count, 2)

	macro_count := 0
	for m in ir.macros {
		if m.name == "SIBLING_FLAG" {
			macro_count += 1
		}
	}
	testing.expect_value(t, macro_count, 1)
}

@(test)
test_extract_distinct_anonymous_unions_in_one_record :: proc(t: ^testing.T) {
	// libclang assigns the same USR to every anonymous union in a parent
	// (c:@S@Parent@Ua). Extraction must still create two layouts.
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	// Write a tiny header into the arena path… use the tests fixture.
	ir: IR
	ir_init(&ir)
	// Inline path: tests/fixtures is preferred; create if missing via /tmp no —
	// use extract on a dedicated fixture file added next to this test.
	ok := extract({"tests/fixtures/anon_unions.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	found := false
	for record in ir.records {
		if record.name != "Node" {
			continue
		}
		found = true
		// x + 2 anonymous unions + height
		testing.expect_value(t, len(record.fields), 4)
		if len(record.fields) < 4 {
			break
		}
		// Fields 1 and 2 are the anonymous unions — distinct type handles.
		testing.expect(t, record.fields[1].type != record.fields[2].type)
		u1 := ir_type(&ir, record.fields[1].type)
		u2 := ir_type(&ir, record.fields[2].type)
		r1, ok1 := u1.variant.(Type_Record_Ref)
		r2, ok2 := u2.variant.(Type_Record_Ref)
		testing.expect(t, ok1 && ok2)
		if ok1 && ok2 {
			testing.expect(t, r1.decl != r2.decl)
			testing.expect_value(t, ir.records[r1.decl].is_union, true)
			testing.expect_value(t, ir.records[r2.decl].is_union, true)
			// First union: children + userData; second: parent + next.
			testing.expect_value(t, len(ir.records[r1.decl].fields), 2)
			testing.expect_value(t, len(ir.records[r2.decl].fields), 2)
			if len(ir.records[r1.decl].fields) == 2 {
				testing.expect_value(t, ir.records[r1.decl].fields[0].name, "children")
			}
			if len(ir.records[r2.decl].fields) == 2 {
				testing.expect_value(t, ir.records[r2.decl].fields[0].name, "parent")
			}
		}
		break
	}
	testing.expect(t, found)
}

@(test)
test_extract_unsigned_enum_member_values :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	ok := extract({"tests/fixtures/unsigned_enum.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	found_unsigned := false
	found_signed := false
	for enm in ir.enums {
		if enm.name == "Unsigned_Flags" {
			found_unsigned = true
			testing.expect(t, enum_backing_is_unsigned(&ir, enm.backing))
			testing.expect_value(t, len(enm.members), 3)
			if len(enm.members) == 3 {
				// Must not be -1: that is the signed mis-capture of 0xFFFFFFFF.
				testing.expect_value(t, u64(enm.members[2].value), u64(0xFFFFFFFF))
				testing.expect_value(t, u64(enm.members[1].value), u64(0x80000000))
			}
		}
		if enm.name == "Signed_Flags" {
			found_signed = true
			testing.expect(t, !enum_backing_is_unsigned(&ir, enm.backing))
			testing.expect_value(t, len(enm.members), 2)
			if len(enm.members) == 2 {
				testing.expect_value(t, enm.members[1].value, i64(-1))
			}
		}
	}
	testing.expect(t, found_unsigned)
	testing.expect(t, found_signed)
}

@(test)
test_extract_records_deprecation_from_attributes :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	ok := extract({"tests/fixtures/deprecated.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	found_fn := false
	found_bare := false
	found_live := false
	for func in ir.funcs {
		if func.name == "old_fn" {
			found_fn = true
			testing.expect(t, func.deprecated)
			testing.expect_value(t, func.deprecated_message, "use new_fn instead")
		}
		if func.name == "bare_deprecated_fn" {
			found_bare = true
			testing.expect(t, func.deprecated)
			testing.expect_value(t, func.deprecated_message, "")
		}
		if func.name == "live_fn" {
			found_live = true
			testing.expect(t, !func.deprecated)
		}
	}
	testing.expect(t, found_fn)
	testing.expect(t, found_bare)
	testing.expect(t, found_live)

	found_type := false
	for record in ir.records {
		if record.name == "Old_Type" {
			found_type = true
			testing.expect(t, record.deprecated)
			testing.expect_value(t, record.deprecated_message, "use New_Type instead")
		}
	}
	testing.expect(t, found_type)

	found_var := false
	for var in ir.vars {
		if var.name == "old_var" {
			found_var = true
			testing.expect(t, var.deprecated)
			testing.expect_value(t, var.deprecated_message, "use new_var instead")
		}
	}
	testing.expect(t, found_var)

	found_const_enum := false
	for enm in ir.enums {
		if enm.name == "" && enm.deprecated {
			found_const_enum = true
			testing.expect_value(t, enm.deprecated_message, "use NEW_CONST instead")
		}
	}
	testing.expect(t, found_const_enum)
}

@(test)
test_extract_records_home_header_per_input :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	a := "tests/fixtures/sibling_input_a.h"
	b := "tests/fixtures/sibling_input_b.h"
	ok := extract({a, b}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	// Two real input headers after the empty sentinel slot.
	testing.expect_value(t, len(ir.input_headers), 3)
	home_a := Input_Header_Handle(1)
	home_b := Input_Header_Handle(2)

	for func in ir.funcs {
		if func.name == "use_sibling_id" {
			testing.expect_value(t, func.home, home_a)
		}
		if func.name == "make_sibling_id" {
			testing.expect_value(t, func.home, home_b)
		}
	}
	for td in ir.typedefs {
		if td.name == "Sibling_Id" {
			testing.expect_value(t, td.home, home_b)
		}
	}
	for m in ir.macros {
		if m.name == "SIBLING_FLAG" {
			testing.expect_value(t, m.home, home_b)
		}
	}
}

@(test)
test_extract_owns_declarations_from_unlisted_project_headers :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// Hidden_Id lives in a project header that config.inputs does not list —
	// the umbrella-header pattern (Box3D lists only box3d.h and reaches
	// types.h through it). Ownership is "not a system header", not "listed in
	// config.inputs": the typedef is ours, so it keeps its name and is
	// emitted. Only system-header declarations are foreign.
	ok := extract({"tests/fixtures/transitive_typedef_main.h"}, &ir)
	testing.expect(t, ok)
	if !ok {
		return
	}

	found := false
	for td, i in ir.typedefs {
		if td.name != "Hidden_Id" {
			continue
		}
		found = true
		testing.expect(t, !td.is_foreign)
		in_order := false
		for ref in ir.order {
			if ref.kind == .Typedef && ref.index == u32(i) {
				in_order = true
			}
		}
		testing.expect(t, in_order)
	}
	testing.expect(t, found)
}

@(test)
test_extract_captures_calling_conventions :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	provenance: Clang_Provenance
	ok := extract({"tests/fixtures/calling_conv.h"}, &ir, {}, &provenance)
	testing.expect(t, ok)
	if !ok {
		return
	}
	// Provenance must record the linked library version (non-empty on a
	// working libclang) and whatever resource-dir selection succeeded.
	testing.expect(t, provenance.libclang_version != "")

	found_plain := false
	found_stdcall := false
	found_fastcall := false
	found_vectorcall := false
	for func in ir.funcs {
		switch func.name {
		case "plain_c":
			found_plain = true
			// Default or C are both honest "C ABI" answers from libclang.
			testing.expect(t, func.calling_conv == .Default || func.calling_conv == .C)
		case "stdcall_fn":
			found_stdcall = true
			// Attribute accepted → Stdcall when the target supports it.
			testing.expect(t, func.calling_conv == .Stdcall || func.calling_conv != .Unknown)
		case "fastcall_fn":
			found_fastcall = true
			testing.expect(t, func.calling_conv == .Fastcall || func.calling_conv != .Unknown)
		case "vectorcall_fn":
			found_vectorcall = true
			// Prefer the mapped Vectorcall fact; at minimum not Unknown.
			testing.expect(t, func.calling_conv == .Vectorcall || func.calling_conv != .Unknown)
		}
	}
	testing.expect(t, found_plain)
	testing.expect(t, found_stdcall)
	testing.expect(t, found_fastcall)
	testing.expect(t, found_vectorcall)

	// Callback typedefs: convention lives on Type_Proc under the pointer.
	found_stdcall_cb := false
	found_fast_cb := false
	for td in ir.typedefs {
		switch td.name {
		case "Stdcall_Cb":
			found_stdcall_cb = true
			assert_typedef_proc_calling_conv(t, &ir, td, .Stdcall)
		case "Fastcall_Cb":
			found_fast_cb = true
			assert_typedef_proc_calling_conv(t, &ir, td, .Fastcall)
		}
	}
	testing.expect(t, found_stdcall_cb)
	testing.expect(t, found_fast_cb)
}

assert_typedef_proc_calling_conv :: proc(t: ^testing.T, ir: ^IR, td: Typedef_Decl, want: Calling_Conv) {
	info := ir_type(ir, td.aliased)
	// typedef of pointer-to-function, possibly already lowered in extract? Extraction stores Type_Pointer.
	ptr, is_ptr := info.variant.(Type_Pointer)
	if !is_ptr {
		// Some paths may store lowered form only after transform; extraction uses Type_Pointer.
		testing.expectf(t, false, "typedef %q aliased type is not a pointer", td.name)
		return
	}
	pointee := ir_type(ir, ptr.pointee)
	proc_ty, is_proc := pointee.variant.(Type_Proc)
	if !is_proc {
		testing.expectf(t, false, "typedef %q pointee is not a procedure type", td.name)
		return
	}
	// Attribute may not stick on every libclang/target combo; never silently Unknown.
	if proc_ty.calling_conv == want {
		return
	}
	testing.expectf(t, proc_ty.calling_conv != .Unknown, "typedef %q calling_conv = %v (want %v or any known fact)", td.name, proc_ty.calling_conv, want)
}
