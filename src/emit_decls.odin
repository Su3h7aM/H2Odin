package h2odin

import "core:fmt"
import "core:strings"

// record_body_emits_fields reports whether a record body will expose its
// fields. The caller supplies emission-only layout fallback because it is
// intentionally not stored in the IR.
record_body_emits_fields :: proc(record: Record_Decl, layout_fallback := false) -> bool {
	return record.is_complete && !record.emit_as_handle && !record.has_unrepresentable_fields && !layout_fallback
}

emit_record :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	if record.name == "" {
		// Anonymous records are spelled inline where they are used (a field,
		// or the typedef that names them); they have no standalone form.
		return
	}
	write_doc(b, record.doc, 0, emit_comments)
	write_deprecated_attr(b, record.deprecated, record.deprecated_message, 0)
	fmt.sbprintf(b, "%s :: ", record.name)
	// Handle style (idiomatic default or types.opaque override).
	// Declaration is distinct rawptr; references already collapsed one
	// pointer level in Transformation.
	if record.emit_as_handle {
		strings.write_string(b, SPELLING_DISTINCT_RAWPTR)
		strings.write_string(b, "\n\n")
		return
	}
	write_record_body(b, ir, record, 0, emit_comments, imports)
	strings.write_string(b, "\n\n")
}

write_record_body :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, indent: int, emit_comments: bool, imports: ^Emit_Imports) {
	if !record_body_emits_fields(record) {
		strings.write_string(b, "struct {}")
		return
	}
	bit_field_layout, bit_fields_ok := prove_record_bit_field_layout(record, ir)
	if !bit_fields_ok {
		// The measured bit-field layout cannot be represented faithfully;
		// an opaque body keeps pointers usable without inventing an ABI.
		strings.write_string(b, "struct {}")
		return
	}
	strings.write_string(b, "struct")
	if record.is_union {
		strings.write_string(b, " #raw_union")
	}
	if record.is_packed {
		strings.write_string(b, " #packed")
	}
	if record.align > 0 {
		fmt.sbprintf(b, " #align(%d)", record.align)
	}
	if len(record.fields) == 0 {
		strings.write_string(b, " {}")
		return
	}
	strings.write_string(b, " {\n")
	run_index := 0
	field_index := 0
	for field_index < len(record.fields) {
		if run_index < len(bit_field_layout.runs) && bit_field_layout.runs[run_index].first_field == field_index {
			run := bit_field_layout.runs[run_index]
			write_bit_field_run(b, record.fields, run, indent + 1, emit_comments)
			field_index = run.one_past_last_field
			run_index += 1
			continue
		}
		field := record.fields[field_index]
		write_doc(b, field.doc, indent + 1, emit_comments)
		write_indent(b, indent + 1)
		if field.name == "" {
			// A C11 anonymous member: its fields read as the parent's.
			strings.write_string(b, "using _: ")
		} else {
			fmt.sbprintf(b, "%s: ", field.name)
		}
		if field.type_spelling != "" {
			note_imports_for_odin_expression(imports, field.type_spelling)
			strings.write_string(b, field.type_spelling)
		} else {
			write_type(b, ir, field.type, indent + 1, emit_comments, imports)
		}
		if field.tag != "" {
			fmt.sbprintf(b, " `%s`", field.tag)
		}
		strings.write_string(b, ",\n")
		field_index += 1
	}
	write_indent(b, indent)
	strings.write_string(b, "}")
}

write_indent :: proc(b: ^strings.Builder, indent: int) {
	for _ in 0 ..< indent {
		strings.write_string(b, "\t")
	}
}

write_doc :: proc(b: ^strings.Builder, doc: string, indent: int, emit_comments: bool) {
	if !emit_comments || doc == "" {
		return
	}
	line_start := 0
	for i in 0 ..< len(doc) {
		if doc[i] != '\n' {
			continue
		}
		write_indent(b, indent)
		strings.write_string(b, doc[line_start:i])
		strings.write_string(b, "\n")
		line_start = i + 1
	}
	if line_start < len(doc) {
		write_indent(b, indent)
		strings.write_string(b, doc[line_start:])
		strings.write_string(b, "\n")
	}
}

// Fallback when the C deprecation attribute has no message.
DEPRECATED_FALLBACK_MESSAGE :: "deprecated in the C header"

// @(deprecated = "msg") for procedures and types. indent matches the decl.
write_deprecated_attr :: proc(b: ^strings.Builder, deprecated: bool, message: string, indent: int) {
	if !deprecated {
		return
	}
	msg := message if message != "" else DEPRECATED_FALLBACK_MESSAGE
	write_indent(b, indent)
	fmt.sbprintfln(b, "@(deprecated = %q)", msg)
}

// Deprecated: line for constants and variables — semantic, not prose, so it
// is emitted even when config.comments = false. Prepended before ordinary docs.
write_deprecated_doc_line :: proc(b: ^strings.Builder, deprecated: bool, message: string, indent: int) {
	if !deprecated {
		return
	}
	msg := message if message != "" else DEPRECATED_FALLBACK_MESSAGE
	write_indent(b, indent)
	fmt.sbprintfln(b, "Deprecated: %s", msg)
}

emit_enum :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	if decl.members == nil {
		// Never defined in this header (or its backing type was
		// unsupported); nothing faithful to emit.
		return
	}
	if decl.name == "" {
		if decl.is_typedef_named {
			// Emitted as a named enum at the typedef that names it.
			return
		}
		// A C anonymous enum is just a bag of integer constants; that is
		// exactly what it becomes. A deprecated anonymous enum
		// still has no Odin attribute on constants — use Deprecated: lines.
		for member in decl.members {
			write_deprecated_doc_line(b, decl.deprecated, decl.deprecated_message, 0)
			write_doc(b, member.doc, 0, emit_comments)
			fmt.sbprintf(b, "%s :: ", member.name)
			write_enum_value(b, ir, decl.backing, member.value)
			strings.write_string(b, "\n")
		}
		strings.write_string(b, "\n")
		return
	}
	write_doc(b, decl.doc, 0, emit_comments)
	write_deprecated_attr(b, decl.deprecated, decl.deprecated_message, 0)
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_enum_body(b, ir, decl, 0, emit_comments, imports)
	strings.write_string(b, "\n\n")
}

write_enum_body :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, indent: int, emit_comments: bool, imports: ^Emit_Imports) {
	strings.write_string(b, "enum ")
	write_type(b, ir, decl.backing, indent, emit_comments, imports)
	strings.write_string(b, " {\n")
	// Odin defaults the first member to 0 and each following to previous+1.
	// Emit `= N` only when the C value differs from that sequence so dense
	// sequential enums stay clean while gaps, non-zero starts, and mid-list
	// removals keep their explicit values (ABI-safe).
	expected_value: Maybe(i64) = i64(0)
	for member in decl.members {
		write_doc(b, member.doc, indent + 1, emit_comments)
		write_indent(b, indent + 1)
		strings.write_string(b, member.name)
		expected, has_expected := expected_value.?
		if !has_expected || member.value != expected {
			strings.write_string(b, " = ")
			write_enum_value(b, ir, decl.backing, member.value)
		}
		strings.write_string(b, ",\n")
		expected_value = next_implicit_enum_value(ir, decl.backing, member.value)
	}
	write_indent(b, indent)
	strings.write_string(b, "}")
}

// Member values are stored as raw i64 bits; the backing type's signedness
// decides how they read back.
write_enum_value :: proc(b: ^strings.Builder, ir: ^IR, backing: Type_Handle, value: i64) {
	unsigned, _ := emitted_enum_backing_layout(ir, backing)
	if unsigned {
		fmt.sbprintf(b, "%d", u64(value))
	} else {
		fmt.sbprintf(b, "%d", value)
	}
}

// next_implicit_enum_value returns the successor when the backing type can
// represent it. nil forces the next C member to keep an explicit value.
next_implicit_enum_value :: proc(ir: ^IR, backing: Type_Handle, value: i64) -> Maybe(i64) {
	unsigned, size := emitted_enum_backing_layout(ir, backing)
	bit_count := size * 8
	if unsigned {
		unsigned_value := u64(value)
		maximum_value := max(u64)
		if bit_count > 0 && bit_count < 64 {
			maximum_value = (u64(1) << uint(bit_count)) - 1
		}
		if unsigned_value == maximum_value {
			return nil
		}
		return i64(unsigned_value + 1)
	}

	maximum_value := max(i64)
	if bit_count > 0 && bit_count < 64 {
		maximum_value = (i64(1) << uint(bit_count - 1)) - 1
	}
	if value == maximum_value {
		return nil
	}
	return value + 1
}

// emitted_enum_backing_layout follows emission-time substitutions and aliases
// to the measured integer backing. The original type remains the signedness
// authority for an idiomatic spelling.
emitted_enum_backing_layout :: proc(ir: ^IR, backing: Type_Handle) -> (unsigned: bool, size: int) {
	current := backing
	for _ in 0 ..< len(ir.types) {
		type_info := ir_type(ir, current)
		switch variant in type_info.variant {
		case Type_Builtin:
			return builtin_is_unsigned(variant.kind), variant.size
		case Type_Std:
			return variant.unsigned, variant.size
		case Type_Idiomatic_Leaf:
			current = variant.original
		case Type_Typedef_Ref:
			current = ir.typedefs[variant.decl].aliased
		case Type_Pointer, Type_Lowered_Pointer, Type_Array, Type_Proc, Type_Record_Ref, Type_Enum_Ref, Type_Bit_Set:
			return false, -1
		}
	}
	return false, -1
}

emit_typedef :: proc(b: ^strings.Builder, ir: ^IR, decl: Typedef_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	if decl.is_unresolvable {
		// Reported during extraction; nothing faithful to emit.
		return
	}
	#partial switch target in ir_type(ir, decl.aliased).variant {
	case Type_Record_Ref:
		record := ir.records[target.decl]
		if record.name == decl.name {
			// The typedef struct Foo { … } Foo idiom: the record's own
			// emission already claims the name.
			return
		}
	case Type_Enum_Ref:
		enum_declaration := ir.enums[target.decl]
		if enum_declaration.name == decl.name && enum_declaration.members != nil {
			// A defined enum already claims the shared typedef/tag name. An
			// incomplete enum has no declaration to merge with, so preserve the
			// typedef as an alias of its measured backing type.
			return
		}
	}
	write_doc(b, decl.doc, 0, emit_comments)
	write_deprecated_attr(b, decl.deprecated, decl.deprecated_message, 0)
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_type(b, ir, decl.aliased, 0, emit_comments, imports)
	strings.write_string(b, "\n\n")
}

emit_variable :: proc(b: ^strings.Builder, ir: ^IR, variable: Var_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	// No @(deprecated) on variables — emit a semantic Deprecated: line.
	write_deprecated_doc_line(b, variable.deprecated, variable.deprecated_message, 1)
	write_doc(b, variable.doc, 1, emit_comments)
	if variable.link_name != "" {
		fmt.sbprintfln(b, "\t@(link_name = %q)", variable.link_name)
	}
	fmt.sbprintf(b, "\t%s: ", variable.name)
	write_type(b, ir, variable.type, 1, emit_comments, imports)
	strings.write_string(b, "\n")
}

emit_macro :: proc(b: ^strings.Builder, decl: Macro_Decl, emit_comments: bool) {
	if decl.is_function_like || len(decl.tokens) != 1 {
		return
	}

	token := decl.tokens[0]
	if token.kind != .Literal {
		return
	}
	integer_body, is_integer := c_integer_literal_for_emission(token.spelling)
	if !is_integer && !macro_literal_can_emit_verbatim(token.spelling) {
		return
	}

	// No @(deprecated) on constants — emit a semantic Deprecated: line.
	write_deprecated_doc_line(b, decl.deprecated, decl.deprecated_message, 0)
	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: ", decl.name)
	if is_integer {
		write_macro_integer_body(b, integer_body)
	} else {
		strings.write_string(b, token.spelling)
	}
	strings.write_string(b, "\n")
}

emit_bit_set :: proc(b: ^strings.Builder, ir: ^IR, decl: Bit_Set_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: bit_set[", decl.name)
	write_type(b, ir, decl.elem, 0, emit_comments, imports)
	// Explicit backing from the measured C enum width. Bare
	// bit_set[E] sizes from the highest flag bit and is not ABI-faithful.
	backing := bit_set_backing_spelling(decl.backing_bits)
	if backing == "" {
		panic("bit_set reached emission without a proven backing width")
	}
	fmt.sbprintf(b, "; %s]\n\n", backing)
}

// write_macro_integer_body rewrites C's leading-zero octal notation, which
// Odin would otherwise read as decimal.
write_macro_integer_body :: proc(b: ^strings.Builder, body: string) {
	if len(body) > 1 && body[0] == '0' && is_ascii_digit(body[1]) {
		strings.write_string(b, "0o")
		strings.write_string(b, body[1:])
		return
	}
	strings.write_string(b, body)
}

// macro_literal_can_emit_verbatim reports whether a non-integer C literal is
// already valid Odin. Numeric suffixes reach here only when integer
// normalization failed or when floating-point suffix handling is unsupported.
macro_literal_can_emit_verbatim :: proc(spelling: string) -> bool {
	if len(spelling) == 0 {
		return false
	}
	first := spelling[0]
	if first == '"' || first == '\'' {
		return true
	}
	last := spelling[len(spelling) - 1]
	// Emitting invalid Odin would be worse than omitting the macro.
	if last == 'u' || last == 'U' || last == 'l' || last == 'L' || last == 'f' || last == 'F' {
		return false
	}
	return true
}

// block_require_results: when true the enclosing foreign block already has
// @(require_results), so per-proc attributes are omitted.
emit_function :: proc(b: ^strings.Builder, ir: ^IR, function: Func_Decl, emit_comments: bool, imports: ^Emit_Imports, block_require_results := false) {
	write_doc(b, function.doc, 1, emit_comments)
	write_deprecated_attr(b, function.deprecated, function.deprecated_message, 1)
	if function.require_results && !block_require_results {
		strings.write_string(b, "\t@(require_results)\n")
	}
	if function.link_name != "" {
		fmt.sbprintfln(b, "\t@(link_name = %q)", function.link_name)
	}
	// Foreign blocks default to cdecl; emit an explicit convention only when
	// the captured fact is not C/default (or when it is unrepresentable — the
	// diagnostic is raised separately so we never silently rewrite a known
	// non-C convention without notice).
	if calling_conv_is_foreign_default(function.calling_conv) {
		fmt.sbprintf(b, "\t%s :: proc(", function.name)
	} else {
		spelling, _ := calling_conv_odin_spelling(function.calling_conv)
		fmt.sbprintf(b, "\t%s :: proc \"%s\" (", function.name, spelling)
	}
	write_params(b, ir, function.params, function.is_variadic, emit_comments, imports)
	strings.write_string(b, ")")
	if function_has_result(ir, function) {
		strings.write_string(b, " -> ")
		write_function_result_type(b, ir, function, 1, emit_comments, imports)
	}
	strings.write_string(b, " ---\n")
}
