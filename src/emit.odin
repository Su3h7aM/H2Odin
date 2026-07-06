package h2odin

import "core:fmt"
import "core:strings"

// Emission turns the final IR into Odin text. Every decision has already
// been made by the time this runs, so emission only serializes — if
// something in here starts looking like a real decision, it belongs in an
// earlier stage.

Emit_Options :: struct {
	package_name: string,
	foreign_lib:  string,
}

emit :: proc(ir: ^IR, opts: Emit_Options) -> string {
	// Declarations are emitted in ordering-list order so the output reads
	// like the original header, routed into two sections: type declarations
	// at file scope, functions and variables inside the foreign block. The
	// sections are built first so the prelude knows which imports the
	// declarations actually use.
	types_body: strings.Builder
	foreign_body: strings.Builder
	uses_core_c := false

	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			emit_func(&foreign_body, ir, ir.funcs[ref.index], &uses_core_c)
		case .Record:
			emit_record(&types_body, ir, ir.records[ref.index], &uses_core_c)
		case .Enum:
			emit_enum(&types_body, ir, ir.enums[ref.index], &uses_core_c)
		case .Typedef:
			emit_typedef(&types_body, ir, ir.typedefs[ref.index], &uses_core_c)
		case .Var, .Macro:
		// Not yet emitted; extraction for these lands kind by kind.
		}
	}

	out: strings.Builder
	fmt.sbprintfln(&out, "package %s", opts.package_name)
	strings.write_string(&out, "\n")
	if uses_core_c {
		strings.write_string(&out, "import \"core:c\"\n\n")
	}
	fmt.sbprintfln(&out, "foreign import lib \"system:%s\"", opts.foreign_lib)
	strings.write_string(&out, "\n")
	strings.write_string(&out, strings.to_string(types_body))
	if strings.builder_len(foreign_body) > 0 {
		// Procedures in a foreign block already default to the C calling
		// convention; no attribute needed.
		strings.write_string(&out, "foreign lib {\n")
		strings.write_string(&out, strings.to_string(foreign_body))
		strings.write_string(&out, "}\n")
	}
	return strings.to_string(out)
}

emit_record :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, uses_core_c: ^bool) {
	if record.name == "" {
		// Anonymous records are spelled inline where they are used (a field,
		// or the typedef that names them); they have no standalone form.
		return
	}
	fmt.sbprintf(b, "%s :: ", record.name)
	write_record_body(b, ir, record, 0, uses_core_c)
	strings.write_string(b, "\n\n")
}

write_record_body :: proc(b: ^strings.Builder, ir: ^IR, record: Record_Decl, indent: int, uses_core_c: ^bool) {
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
	if len(record.fields) == 0 {
		strings.write_string(b, " {}")
		return
	}
	strings.write_string(b, " {\n")
	for field in record.fields {
		write_indent(b, indent + 1)
		if field.name == "" {
			// A C11 anonymous member: its fields read as the parent's.
			strings.write_string(b, "using _: ")
		} else {
			fmt.sbprintf(b, "%s: ", field.name)
		}
		write_type(b, ir, field.type, indent + 1, uses_core_c)
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

emit_enum :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, uses_core_c: ^bool) {
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
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_enum_body(b, ir, decl, 0, uses_core_c)
	strings.write_string(b, "\n\n")
}

write_enum_body :: proc(b: ^strings.Builder, ir: ^IR, decl: Enum_Decl, indent: int, uses_core_c: ^bool) {
	strings.write_string(b, "enum ")
	write_type(b, ir, decl.backing, indent, uses_core_c)
	strings.write_string(b, " {\n")
	for member in decl.members {
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
	builtin, is_builtin := ir_type(ir, backing).variant.(Type_Builtin)
	if is_builtin && builtin_is_unsigned(builtin.kind) {
		fmt.sbprintf(b, "%d", u64(value))
	} else {
		fmt.sbprintf(b, "%d", value)
	}
}

builtin_is_unsigned :: proc(kind: Builtin_Kind) -> bool {
	#partial switch kind {
	case .Bool, .U_Char, .U_Short, .U_Int, .U_Long, .U_Long_Long:
		return true
	}
	return false
}

emit_typedef :: proc(b: ^strings.Builder, ir: ^IR, decl: Typedef_Decl, uses_core_c: ^bool) {
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
	fmt.sbprintf(b, "%s :: ", decl.name)
	write_type(b, ir, decl.aliased, 0, uses_core_c)
	strings.write_string(b, "\n\n")
}

emit_func :: proc(b: ^strings.Builder, ir: ^IR, func: Func_Decl, uses_core_c: ^bool) {
	fmt.sbprintf(b, "\t%s :: proc(", func.name)
	write_params(b, ir, func.params, func.is_variadic, uses_core_c)
	strings.write_string(b, ")")
	if !type_is_void(ir, func.return_type) {
		strings.write_string(b, " -> ")
		write_type(b, ir, func.return_type, 1, uses_core_c)
	}
	strings.write_string(b, " ---\n")
}

write_params :: proc(b: ^strings.Builder, ir: ^IR, params: []Param, is_variadic: bool, uses_core_c: ^bool) {
	for param, i in params {
		if i > 0 {
			strings.write_string(b, ", ")
		}
		if param.name != "" {
			fmt.sbprintf(b, "%s: ", param.name)
		}
		write_type(b, ir, param.type, 1, uses_core_c)
	}
	if is_variadic {
		if len(params) > 0 {
			strings.write_string(b, ", ")
		}
		strings.write_string(b, "#c_vararg _: ..any")
	}
}

type_is_void :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	builtin, is_builtin := ir_type(ir, handle).variant.(Type_Builtin)
	return is_builtin && builtin.kind == .Void
}

// Write the faithful ABI spelling of a type, using Odin's C-compatible types
// from core:c. indent is where this type sits, for the rare spellings that
// span lines (inline anonymous record bodies).
write_type :: proc(b: ^strings.Builder, ir: ^IR, handle: Type_Handle, indent: int, uses_core_c: ^bool) {
	info := ir_type(ir, handle)
	if info.variant == nil {
		// Extraction rejects types the IR cannot represent, so an invalid
		// handle reaching emission is a pipeline bug, not a user mistake.
		panic("invalid type handle reached emission")
	}
	switch variant in info.variant {
	case Type_Builtin:
		strings.write_string(b, abi_builtin_name(variant.kind, uses_core_c))

	case Type_Pointer:
		#partial switch pointee in ir_type(ir, variant.pointee).variant {
		case Type_Builtin:
			if pointee.kind == .Void {
				// void* carries no pointee type worth preserving.
				strings.write_string(b, "rawptr")
				return
			}
		case Type_Proc:
			// An Odin proc value is already a pointer, so a C function
			// pointer spells as the proc type itself.
			write_type(b, ir, variant.pointee, indent, uses_core_c)
			return
		}
		strings.write_string(b, "^")
		write_type(b, ir, variant.pointee, indent, uses_core_c)

	case Type_Array:
		if variant.is_incomplete {
			// T[] has no size to preserve; zero length keeps the ABI honest
			// in the positions C allows it (trailing flexible members).
			strings.write_string(b, "[0]")
		} else {
			fmt.sbprintf(b, "[%d]", variant.count)
		}
		write_type(b, ir, variant.element, indent, uses_core_c)

	case Type_Proc:
		strings.write_string(b, "proc \"c\" (")
		write_params(b, ir, variant.params, variant.is_variadic, uses_core_c)
		strings.write_string(b, ")")
		if !type_is_void(ir, variant.return_type) {
			strings.write_string(b, " -> ")
			write_type(b, ir, variant.return_type, indent, uses_core_c)
		}

	case Type_Record_Ref:
		record := ir.records[variant.decl]
		if record.name != "" {
			strings.write_string(b, record.name)
		} else {
			// Anonymous record: its body is its only spelling.
			write_record_body(b, ir, record, indent, uses_core_c)
		}

	case Type_Enum_Ref:
		decl := ir.enums[variant.decl]
		if decl.name != "" {
			strings.write_string(b, decl.name)
		} else if decl.members != nil {
			// Anonymous enum: its body is its only spelling.
			write_enum_body(b, ir, decl, indent, uses_core_c)
		} else {
			// Referenced but never defined — only its backing integer is
			// known, and that is all C guarantees about it anyway.
			write_type(b, ir, decl.backing, indent, uses_core_c)
		}

	case Type_Typedef_Ref:
		// Unresolvable typedefs never reach emission: capture refuses to
		// hand out references to them.
		strings.write_string(b, ir.typedefs[variant.decl].name)
	}
}

// Exhaustive over Builtin_Kind on purpose: adding a builtin without deciding
// its ABI spelling must not compile.
abi_builtin_name :: proc(kind: Builtin_Kind, uses_core_c: ^bool) -> string {
	uses_core_c^ = true
	switch kind {
	case .Void:
		// C void never appears as a parameter in the IR, and void returns
		// are handled by the caller omitting the result entirely.
		panic("void type has no ABI spelling")
	case .Bool:
		return "c.bool"
	case .Char:
		return "c.char"
	case .S_Char:
		return "c.schar"
	case .U_Char:
		return "c.uchar"
	case .Short:
		return "c.short"
	case .U_Short:
		return "c.ushort"
	case .Int:
		return "c.int"
	case .U_Int:
		return "c.uint"
	case .Long:
		return "c.long"
	case .U_Long:
		return "c.ulong"
	case .Long_Long:
		return "c.longlong"
	case .U_Long_Long:
		return "c.ulonglong"
	case .Float:
		return "c.float"
	case .Double:
		return "c.double"
	}
	return ""
}
