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
	// like the original header. The body is built first so the prelude knows
	// which imports the declarations actually use.
	body: strings.Builder
	uses_core_c := false

	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			emit_func(&body, ir, ir.funcs[ref.index], &uses_core_c)
		case .Record, .Enum, .Typedef, .Var, .Macro:
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
	// Procedures in a foreign block already default to the C calling
	// convention; no attribute needed.
	strings.write_string(&out, "foreign lib {\n")
	strings.write_string(&out, strings.to_string(body))
	strings.write_string(&out, "}\n")
	return strings.to_string(out)
}

emit_func :: proc(b: ^strings.Builder, ir: ^IR, func: Func_Decl, uses_core_c: ^bool) {
	fmt.sbprintf(b, "\t%s :: proc(", func.name)
	for param, i in func.params {
		if i > 0 {
			strings.write_string(b, ", ")
		}
		if param.name != "" {
			fmt.sbprintf(b, "%s: ", param.name)
		}
		strings.write_string(b, abi_type_name(ir, param.type, uses_core_c))
	}
	strings.write_string(b, ")")
	if !type_is_void(ir, func.return_type) {
		fmt.sbprintf(b, " -> %s", abi_type_name(ir, func.return_type, uses_core_c))
	}
	strings.write_string(b, " ---\n")
}

type_is_void :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	builtin, is_builtin := ir_type(ir, handle).variant.(Type_Builtin)
	return is_builtin && builtin.kind == .Void
}

// The faithful ABI spelling of a type, using Odin's C-compatible types from
// core:c.
abi_type_name :: proc(ir: ^IR, handle: Type_Handle, uses_core_c: ^bool) -> string {
	info := ir_type(ir, handle)
	switch variant in info.variant {
	case Type_Builtin:
		return abi_builtin_name(variant.kind, uses_core_c)
	case Type_Pointer, Type_Array, Type_Proc, Type_Record_Ref, Type_Enum_Ref, Type_Typedef_Ref:
		// Extraction cannot produce these yet; their spellings land with
		// their extraction, kind by kind.
		panic("type variant not yet emittable")
	}
	// nil variant: extraction rejects types the IR cannot represent, so an
	// invalid handle reaching emission is a pipeline bug, not a user mistake.
	panic("invalid type handle reached emission")
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
