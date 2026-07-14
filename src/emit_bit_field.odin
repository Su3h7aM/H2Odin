package h2odin

import "core:fmt"
import "core:mem"
import "core:strings"

// A maximal adjacent run of C bit-field members represented by one Odin
// bit_field. Indices refer to Record_Decl.fields.
Bit_Field_Run_Layout :: struct {
	first_field:         int,
	one_past_last_field: int,
	backing_bits:        int,
}

// Scratch proof result consumed immediately while serializing one record.
// Runs use context.temp_allocator and need no individual cleanup.
Record_Bit_Field_Layout :: struct {
	runs: [dynamic]Bit_Field_Run_Layout,
}

// Scratch plan consumed before Emission. The slices use context.temp_allocator;
// diagnostic messages use the generation allocator because main copies them
// into IR.diagnostics.
Bit_Field_Emit_Plan :: struct {
	opaque_records: []bool, // indexed by IR.records
	diagnostics:    []Diagnostic,
}

record_has_bit_fields :: proc(record: Record_Decl) -> bool {
	for field in record.fields {
		if field.is_bitfield {
			return true
		}
	}
	return false
}

bit_field_backing_bits :: proc(span_bits: i64) -> (int, bool) {
	switch span_bits {
	case 8:
		return 8, true
	case 16:
		return 16, true
	case 32:
		return 32, true
	case 64:
		return 64, true
	}
	return 0, false
}

// Whether Transformation kept a field's emitted type layout tied to the C
// type Extraction measured. User-authored spellings and type-map rewrites are
// deliberately unprovable here: configuration may request them, but it may
// not silently invalidate an automatically emitted bit-field record.
emitted_native_layout_for_bit_fields :: proc(ir: ^IR, type_handle: Type_Handle) -> (size: int, alignment: int, known: bool, ok: bool) {
	type_info := ir_type(ir, type_handle)
	switch variant in type_info.variant {
	case Type_Builtin, Type_Std, Type_Lowered_Pointer:
		return 0, 0, false, true
	case Type_Idiomatic_Leaf:
		if variant.reason == .Config_Override {
			return 0, 0, false, false
		}
		size = odin_type_size(variant.spelling)
		alignment = odin_type_alignment(variant.spelling)
		return size, alignment, true, size > 0 && alignment > 0
	case Type_Array:
		if variant.is_incomplete {
			return 0, 0, false, false
		}
		element_size, element_alignment, element_known, element_ok := emitted_native_layout_for_bit_fields(ir, variant.element)
		if !element_ok || !element_known {
			return 0, 0, false, element_ok
		}
		return element_size * int(variant.count), element_alignment, true, true
	case Type_Enum_Ref:
		return emitted_native_layout_for_bit_fields(ir, ir.enums[variant.decl].backing)
	case Type_Typedef_Ref:
		decl := ir.typedefs[variant.decl]
		if decl.is_unresolvable {
			return 0, 0, false, false
		}
		return emitted_native_layout_for_bit_fields(ir, decl.aliased)
	case Type_Pointer, Type_Proc, Type_Record_Ref, Type_Bit_Set:
		return 0, 0, false, false
	}
	return 0, 0, false, false
}

field_layout_is_preserved_for_bit_fields :: proc(ir: ^IR, field: Field) -> bool {
	if field.type_spelling != "" {
		return false
	}
	size, alignment, known, ok := emitted_native_layout_for_bit_fields(ir, field.type)
	if !ok {
		return false
	}
	return !known || (size == field.size && alignment == field.alignment)
}

// Prove the complete emitted struct layout arithmetically. The returned proof
// is temporary and remains valid until context.temp_allocator is cleared.
// Ordinary fields
// are checked against libclang's measured offsets as anchors; each bit-field
// run consumes the measured whole-byte span up to the next ordinary field or
// record end. Any gap inside that span becomes an anonymous reserved member.
// Odin bit_field order is defined LSB-first, so targets with another byte
// order fail closed instead of assuming C's target-specific convention.
prove_record_bit_field_layout :: proc(record: Record_Decl, ir: ^IR = nil) -> (Record_Bit_Field_Layout, bool) {
	layout: Record_Bit_Field_Layout
	if !record_has_bit_fields(record) {
		return layout, true
	}
	when ODIN_ENDIAN != .Little {
		return layout, false
	}
	if record.is_union || record.size <= 0 || record.alignment <= 0 {
		return layout, false
	}

	layout.runs = make([dynamic]Bit_Field_Run_Layout, context.temp_allocator)
	current_byte := 0
	struct_alignment := 1
	field_index := 0
	for field_index < len(record.fields) {
		field := record.fields[field_index]
		if !field.is_bitfield {
			if field.bit_offset < 0 || field.bit_offset % 8 != 0 || field.size < 0 || field.alignment <= 0 {
				return layout, false
			}
			if ir != nil && !field_layout_is_preserved_for_bit_fields(ir, field) {
				return layout, false
			}
			field_alignment := field.alignment
			if record.is_packed {
				field_alignment = 1
			}
			current_byte = mem.align_formula(current_byte, field_alignment)
			if current_byte != int(field.bit_offset / 8) {
				return layout, false
			}
			current_byte += field.size
			struct_alignment = max(struct_alignment, field_alignment)
			field_index += 1
			continue
		}

		first_field_index := field_index
		for field_index < len(record.fields) && record.fields[field_index].is_bitfield {
			field_index += 1
		}
		one_past_last_field := field_index
		first_bit := record.fields[first_field_index].bit_offset
		boundary_bit := i64(record.size * 8)
		if one_past_last_field < len(record.fields) {
			boundary_bit = record.fields[one_past_last_field].bit_offset
		}
		if first_bit < 0 || first_bit % 8 != 0 || boundary_bit <= first_bit {
			return layout, false
		}

		backing_bits, backing_ok := bit_field_backing_bits(boundary_bit - first_bit)
		if !backing_ok {
			return layout, false
		}
		cursor_bit := first_bit
		for member_index in first_field_index ..< one_past_last_field {
			member := record.fields[member_index]
			if member.bit_width <= 0 || member.bit_offset < cursor_bit {
				return layout, false
			}
			end_bit := member.bit_offset + member.bit_width
			if end_bit > boundary_bit {
				return layout, false
			}
			cursor_bit = end_bit
		}

		backing_bytes := backing_bits / 8
		field_alignment := backing_bytes
		if record.is_packed {
			field_alignment = 1
		}
		current_byte = mem.align_formula(current_byte, field_alignment)
		if current_byte != int(first_bit / 8) {
			return layout, false
		}
		current_byte += backing_bytes
		struct_alignment = max(struct_alignment, field_alignment)
		append(&layout.runs, Bit_Field_Run_Layout{first_field = first_field_index, one_past_last_field = one_past_last_field, backing_bits = backing_bits})
	}

	if record.align > 0 {
		struct_alignment = max(struct_alignment, record.align)
	}
	if struct_alignment != record.alignment || mem.align_formula(current_byte, struct_alignment) != record.size {
		return layout, false
	}
	return layout, true
}

// Prepare the emission-only fallback view without mutating the semantic IR.
// Main uses opaque_records to suppress diagnostics for fields that will not
// be serialized; write_record_body independently consumes the same proof.
plan_bit_field_emission :: proc(ir: ^IR) -> Bit_Field_Emit_Plan {
	opaque_records := make([]bool, len(ir.records), context.temp_allocator)
	diagnostics := make([dynamic]Diagnostic, context.temp_allocator)
	for declaration in ir.order {
		if declaration.kind != .Record {
			continue
		}
		record_index := int(declaration.index)
		record := ir.records[record_index]
		if !record.is_complete || record.has_unrepresentable_fields || !record_has_bit_fields(record) {
			continue
		}
		_, layout_reproducible := prove_record_bit_field_layout(record, ir)
		if layout_reproducible {
			continue
		}
		opaque_records[record_index] = true
		append(
			&diagnostics,
			Diagnostic {
				category = .Bit_Field_Layout_Fallback,
				message = fmt.aprintf("%q measured bit-field layout cannot be reproduced by Odin; emitted opaque", record_display_name(record)),
			},
		)
	}
	return Bit_Field_Emit_Plan{opaque_records = opaque_records, diagnostics = diagnostics[:]}
}

write_reserved_bit_field :: proc(b: ^strings.Builder, backing_bits: int, width: i64, indent: int) {
	write_indent(b, indent)
	fmt.sbprintfln(b, "_: u%d | %d,", backing_bits, width)
}

write_bit_field_run :: proc(b: ^strings.Builder, fields: []Field, run: Bit_Field_Run_Layout, indent: int, emit_comments: bool) {
	write_indent(b, indent)
	fmt.sbprintf(b, "using _: bit_field u%d", run.backing_bits)
	strings.write_string(b, " {\n")
	cursor_bit := fields[run.first_field].bit_offset
	for field_index in run.first_field ..< run.one_past_last_field {
		field := fields[field_index]
		if field.bit_offset > cursor_bit {
			write_reserved_bit_field(b, run.backing_bits, field.bit_offset - cursor_bit, indent + 1)
		}
		write_doc(b, field.doc, indent + 1, emit_comments)
		write_indent(b, indent + 1)
		name := field.name if field.name != "" else "_"
		fmt.sbprintf(b, "%s: u%d | %d", name, run.backing_bits, field.bit_width)
		if field.tag != "" {
			fmt.sbprintf(b, " `%s`", field.tag)
		}
		strings.write_string(b, ",\n")
		cursor_bit = field.bit_offset + field.bit_width
	}
	run_end := fields[run.first_field].bit_offset + i64(run.backing_bits)
	if cursor_bit < run_end {
		write_reserved_bit_field(b, run.backing_bits, run_end - cursor_bit, indent + 1)
	}
	write_indent(b, indent)
	strings.write_string(b, "},\n")
}
