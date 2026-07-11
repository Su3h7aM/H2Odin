package h2odin

import "core:fmt"
import "core:strings"

write_params :: proc(b: ^strings.Builder, ir: ^IR, params: []Param, is_variadic: bool, emit_comments: bool, imports: ^Emit_Imports) {
	for param, i in params {
		if i > 0 {
			strings.write_string(b, ", ")
		}
		if param.name != "" {
			fmt.sbprintf(b, "%s: ", param.name)
		} else {
			strings.write_string(b, "_: ")
		}
		if param.type_spelling != "" {
			note_import_for_spelling(imports, param.type_spelling)
			strings.write_string(b, param.type_spelling)
		} else {
			write_type(b, ir, param.type, 1, emit_comments, imports)
		}
		if param.default != "" {
			fmt.sbprintf(b, " = %s", param.default)
		}
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

// Write the type spelling decided by Transformation. indent is where this type
// sits, for the rare spellings that span lines (inline anonymous record bodies).
write_type :: proc(b: ^strings.Builder, ir: ^IR, handle: Type_Handle, indent: int, emit_comments: bool, imports: ^Emit_Imports) {
	info := ir_type(ir, handle)
	if info.variant == nil {
		// Extraction rejects types the IR cannot represent, so an invalid
		// handle reaching emission is a pipeline bug, not a user mistake.
		panic("invalid type handle reached emission")
	}
	switch variant in info.variant {
	case Type_Builtin:
		spelling := builtin_spellings[variant.kind]
		if spelling.abi == "" {
			// C void never appears as a parameter in the IR, and void
			// returns are handled by the caller omitting the result.
			panic("void type has no ABI spelling")
		}
		imports.core_c = true
		strings.write_string(b, spelling.abi)

	case Type_Std:
		mapping, known := std_mapping_for(variant.name)
		if !known {
			// Extraction only builds Type_Std for names it found in
			// std_mappings, so a miss here is a pipeline bug.
			panic("std typedef reached emission without a spelling")
		}
		imports.core_c = true
		strings.write_string(b, mapping.abi)

	case Type_Idiomatic_Leaf:
		// Proven substitution, config override, or platform mapping.
		// Track package imports for qualified spellings (posix.T).
		note_import_for_spelling(imports, variant.spelling)
		strings.write_string(b, variant.spelling)

	case Type_Pointer:
		panic("raw pointer reached emission before Transformation lowered it")

	case Type_Lowered_Pointer:
		#partial switch variant.kind {
		case .Rawptr:
			strings.write_string(b, SPELLING_RAWPTR)
			return
		case .CString:
			strings.write_string(b, SPELLING_CSTRING)
			return
		case .Proc:
			write_type(b, ir, variant.pointee, indent, emit_comments, imports)
			return
		case .Single:
		}
		strings.write_string(b, "^")
		write_type(b, ir, variant.pointee, indent, emit_comments, imports)

	case Type_Array:
		if variant.is_incomplete {
			// T[] has no size to preserve; zero length keeps the ABI honest
			// in the positions C allows it (trailing flexible members).
			strings.write_string(b, "[0]")
		} else {
			fmt.sbprintf(b, "[%d]", variant.count)
		}
		write_type(b, ir, variant.element, indent, emit_comments, imports)

	case Type_Proc:
		strings.write_string(b, "proc \"c\" (")
		write_params(b, ir, variant.params, variant.is_variadic, emit_comments, imports)
		strings.write_string(b, ")")
		if !type_is_void(ir, variant.return_type) {
			strings.write_string(b, " -> ")
			write_type(b, ir, variant.return_type, indent, emit_comments, imports)
		}

	case Type_Record_Ref:
		record := ir.records[variant.decl]
		if record.name != "" {
			strings.write_string(b, record.name)
		} else {
			// Anonymous record: its body is its only spelling.
			write_record_body(b, ir, record, indent, emit_comments, imports)
		}

	case Type_Enum_Ref:
		decl := ir.enums[variant.decl]
		if decl.name != "" {
			strings.write_string(b, decl.name)
		} else if decl.members != nil {
			// Anonymous enum: its body is its only spelling.
			write_enum_body(b, ir, decl, indent, emit_comments, imports)
		} else {
			// Referenced but never defined — only its backing integer is
			// known, and that is all C guarantees about it anyway.
			write_type(b, ir, decl.backing, indent, emit_comments, imports)
		}

	case Type_Typedef_Ref:
		// Unresolvable typedefs never reach emission: capture refuses to
		// hand out references to them.
		strings.write_string(b, ir.typedefs[variant.decl].name)

	case Type_Bit_Set:
		strings.write_string(b, "bit_set[")
		write_type(b, ir, variant.elem, indent, emit_comments, imports)
		backing := bit_set_backing_spelling(variant.backing_bits)
		if backing == "" {
			panic("Type_Bit_Set reached emission without a proven backing width")
		}
		fmt.sbprintf(b, "; %s]", backing)
	}
}

// Record package imports required by an explicit type spelling: the built-in
// POSIX/libc map and config spellings both use the qualified `pkg.T` form
// (spec 0010). Any caller that writes a spelling straight into the output —
// including field/param type_spelling overrides from policy — must call this.
note_import_for_spelling :: proc(imports: ^Emit_Imports, spelling: string) {
	if strings.has_prefix(spelling, "posix.") {
		imports.posix = true
	}
	if strings.has_prefix(spelling, "libc.") {
		imports.libc = true
	}
}

// Params may carry an explicit type_spelling from policy; track its imports.
note_param_spelling_imports :: proc(imports: ^Emit_Imports, params: []Param) {
	for p in params {
		if p.type_spelling != "" {
			note_import_for_spelling(imports, p.type_spelling)
		}
	}
}
