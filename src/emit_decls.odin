package h2odin

import "core:fmt"
import "core:strings"

emit_record :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, emit_comments: bool, uses_core_c: ^bool) {
	if record.name == "" {
		// Anonymous records are spelled inline where they are used (a field,
		// or the typedef that names them); they have no standalone form.
		return
	}
	write_doc(b, record.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: ", record.name)
	write_record_body(b, ir, record, 0, emit_comments, uses_core_c)
	strings.write_string(b, "\n\n")
}

write_record_body :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, indent: int, emit_comments: bool, uses_core_c: ^bool) {
	if !record.is_complete || record.has_unrepresentable_fields {
		// No layout to preserve (forward-declared), or a layout the IR
		// cannot represent yet — an opaque body is the honest fallback;
		// pointers to it stay fully usable.
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
	for field in record.fields {
		write_doc(b, field.doc, indent + 1, emit_comments)
		write_indent(b, indent + 1)
		if field.name == "" {
			// A C11 anonymous member: its fields read as the parent's.
			strings.write_string(b, "using _: ")
		} else {
			fmt.sbprintf(b, "%s: ", field.name)
		}
		if field.type_spelling != "" {
			strings.write_string(b, field.type_spelling)
		} else {
			write_type(b, ir, field.type, indent + 1, emit_comments, uses_core_c)
		}
		if field.tag != "" {
			fmt.sbprintf(b, " `%s`", field.tag)
		}
		strings.write_string(b, ",\n")
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

emit_enum :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, emit_comments: bool, uses_core_c: ^bool) {
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
		// exactly what it becomes.
		for member in decl.members {
			fmt.sbprintf(b, "%s :: ", member.name)
			write_enum_value(b, ir, decl.backing, member.value)
			strings.write_string(b, "\n")
		}
		strings.write_string(b, "\n")
		return
	}
	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_enum_body(b, ir, decl, 0, emit_comments, uses_core_c)
	strings.write_string(b, "\n\n")
}

write_enum_body :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, indent: int, emit_comments: bool, uses_core_c: ^bool) {
	strings.write_string(b, "enum ")
	write_type(b, ir, decl.backing, indent, emit_comments, uses_core_c)
	strings.write_string(b, " {\n")
	for member in decl.members {
		write_doc(b, member.doc, indent + 1, emit_comments)
		write_indent(b, indent + 1)
		fmt.sbprintf(b, "%s = ", member.name)
		write_enum_value(b, ir, decl.backing, member.value)
		strings.write_string(b, ",\n")
	}
	write_indent(b, indent)
	strings.write_string(b, "}")
}

// Member values are stored as raw i64 bits; the backing type's signedness
// decides how they read back.
write_enum_value :: proc(b: ^strings.Builder, ir: ^IR, backing: Type_Handle, value: i64) {
	info := ir_type(ir, backing)
	if leaf, is_leaf := info.variant.(Type_Idiomatic_Leaf); is_leaf {
		// Signedness lives on the original the substitution replaced.
		info = ir_type(ir, leaf.original)
	}
	builtin, is_builtin := info.variant.(Type_Builtin)
	if is_builtin && builtin_is_unsigned(builtin.kind) {
		fmt.sbprintf(b, "%d", u64(value))
	} else {
		fmt.sbprintf(b, "%d", value)
	}
}

builtin_is_unsigned :: proc(kind: Builtin_Kind) -> bool {
	#partial switch kind {
	case .Bool, .Char_Unsigned, .U_Char, .U_Short, .U_Int, .U_Long, .U_Long_Long:
		return true
	}
	return false
}

emit_typedef :: proc(b: ^strings.Builder, ir: ^IR, decl: Typedef_Decl, emit_comments: bool, uses_core_c: ^bool) {
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
		if ir.enums[target.decl].name == decl.name {
			return
		}
	}
	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_type(b, ir, decl.aliased, 0, emit_comments, uses_core_c)
	strings.write_string(b, "\n\n")
}

emit_var :: proc(b: ^strings.Builder, ir: ^IR, decl: Var_Decl, emit_comments: bool, uses_core_c: ^bool) {
	write_doc(b, decl.doc, 1, emit_comments)
	if decl.link_name != "" {
		fmt.sbprintfln(b, "\t@(link_name = %q)", decl.link_name)
	}
	fmt.sbprintf(b, "\t%s: ", decl.name)
	write_type(b, ir, decl.type, 1, emit_comments, uses_core_c)
	strings.write_string(b, "\n")
}

emit_macro :: proc(b: ^strings.Builder, decl: Macro_Decl, emit_comments: bool) {
	if decl.is_function_like || len(decl.tokens) != 1 {
		return
	}

	token := decl.tokens[0]
	if token.kind != .Literal || !macro_literal_can_emit(token.spelling) {
		return
	}

	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintfln(b, "%s :: %s", decl.name, token.spelling)
}

emit_bit_set :: proc(b: ^strings.Builder, ir: ^IR, decl: Bit_Set_Decl, emit_comments: bool, uses_core_c: ^bool) {
	write_doc(b, decl.doc, 0, emit_comments)
	fmt.sbprintf(b, "%s :: bit_set[", decl.name)
	write_type(b, ir, decl.elem, 0, emit_comments, uses_core_c)
	strings.write_string(b, "]\n\n")
}

macro_literal_can_emit :: proc(s: string) -> bool {
	if len(s) == 0 {
		return false
	}
	first := s[0]
	if first == '"' || first == '\'' {
		return true
	}
	last := s[len(s) - 1]
	// Skip common C numeric suffixes until macro values get a real numeric
	// parser. Emitting invalid Odin would be worse than omitting the macro.
	if last == 'u' || last == 'U' || last == 'l' || last == 'L' || last == 'f' || last == 'F' {
		return false
	}
	return true
}

emit_func :: proc(b: ^strings.Builder, ir: ^IR, func: Func_Decl, emit_comments: bool, uses_core_c: ^bool) {
	write_doc(b, func.doc, 1, emit_comments)
	if func.link_name != "" {
		fmt.sbprintfln(b, "\t@(link_name = %q)", func.link_name)
	}
	fmt.sbprintf(b, "\t%s :: proc(", func.name)
	write_params(b, ir, func.params, func.is_variadic, emit_comments, uses_core_c)
	strings.write_string(b, ")")
	if func.return_type_spelling != "" {
		strings.write_string(b, " -> ")
		strings.write_string(b, func.return_type_spelling)
	} else if !type_is_void(ir, func.return_type) {
		strings.write_string(b, " -> ")
		write_type(b, ir, func.return_type, 1, emit_comments, uses_core_c)
	}
	strings.write_string(b, " ---\n")
}
