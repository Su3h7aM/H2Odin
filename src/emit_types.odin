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
		// Procedure types default to `"odin"` outside a foreign block, so the
		// C convention must always be stated — including the common `"c"` case.
		write_proc_type_prefix(b, variant.calling_conv)
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

// Human label for diagnostics and tests (not the Odin spelling).
calling_conv_label :: proc(cc: Calling_Conv) -> string {
	switch cc {
	case .Default:
		return "default"
	case .C:
		return "c"
	case .Stdcall:
		return "stdcall"
	case .Fastcall:
		return "fastcall"
	case .Thiscall:
		return "thiscall"
	case .Vectorcall:
		return "vectorcall"
	case .Win64:
		return "win64"
	case .Sys_V:
		return "sysv"
	case .Other:
		return "other"
	case .Unknown:
		return "unknown"
	}
	return "unknown"
}

// Map an IR calling convention to an Odin procedure-type spelling. `ok` is
// false when the convention has no Odin representation — callers must not
// treat that as C without a diagnostic (spec 0011 / Milestone 16 P0).
// Fallback spelling on failure is still `"c"` so emission stays parseable;
// the error-severity diagnostic is what fails the run.
calling_conv_odin_spelling :: proc(cc: Calling_Conv) -> (spelling: string, ok: bool) {
	switch cc {
	case .Default, .C:
		return "c", true
	case .Stdcall:
		return "stdcall", true
	case .Fastcall:
		return "fastcall", true
	case .Win64:
		return "win64", true
	case .Sys_V:
		return "sysv", true
	case .Thiscall, .Vectorcall, .Other, .Unknown:
		return "c", false
	}
	return "c", false
}

// True when the convention is C/default and a foreign-block declaration may
// omit an explicit `proc "c"` (foreign default is cdecl).
calling_conv_is_foreign_default :: proc(cc: Calling_Conv) -> bool {
	return cc == .Default || cc == .C
}

// Write `proc "cc" (` for a procedure type or foreign declaration that needs
// an explicit convention string.
write_proc_type_prefix :: proc(b: ^strings.Builder, cc: Calling_Conv) {
	spelling, _ := calling_conv_odin_spelling(cc)
	fmt.sbprintf(b, "proc \"%s\" (", spelling)
}

// Report every unrepresentable calling convention on *emitted* funcs and on
// procedure types still reachable from live declarations. Symbols dropped by
// filter_declarations stay in the pools but are not in `ir.order`, so they
// must not fail the run. Defaults to error severity (policy_set_diag_defaults).
report_unsupported_calling_conventions :: proc(ir: ^IR) {
	for ref in ir.order {
		if ref.kind != .Func {
			continue
		}
		func := ir.funcs[ref.index]
		if _, ok := calling_conv_odin_spelling(func.calling_conv); ok {
			continue
		}
		ir_diag(
			ir,
			.Unsupported_Calling_Conv,
			"function %q uses calling convention %s which has no Odin spelling",
			func.name,
			calling_conv_label(func.calling_conv),
		)
	}

	// Procedure types that appear in emitted signatures / typedefs. Walk types
	// referenced from live decls rather than the whole pool (which retains
	// types only used by removed symbols).
	seen_types := make(map[Type_Handle]bool, context.temp_allocator)
	for ref in ir.order {
		switch ref.kind {
		case .Invalid, .Macro, .Bit_Set:
		case .Func:
			func := ir.funcs[ref.index]
			report_unsupported_calling_conv_in_type(ir, func.return_type, &seen_types)
			for p in func.params {
				report_unsupported_calling_conv_in_type(ir, p.type, &seen_types)
			}
		case .Var:
			report_unsupported_calling_conv_in_type(ir, ir.vars[ref.index].type, &seen_types)
		case .Typedef:
			report_unsupported_calling_conv_in_type(ir, ir.typedefs[ref.index].aliased, &seen_types)
		case .Record:
			record := ir.records[ref.index]
			for f in record.fields {
				report_unsupported_calling_conv_in_type(ir, f.type, &seen_types)
			}
		case .Enum:
		}
	}
}

report_unsupported_calling_conv_in_type :: proc(ir: ^IR, handle: Type_Handle, seen: ^map[Type_Handle]bool) {
	if handle == 0 || handle in seen^ {
		return
	}
	seen^[handle] = true
	info := ir_type(ir, handle)
	switch variant in info.variant {
	case Type_Proc:
		if _, ok := calling_conv_odin_spelling(variant.calling_conv); !ok {
			ir_diag(
				ir,
				.Unsupported_Calling_Conv,
				"procedure type uses calling convention %s which has no Odin spelling",
				calling_conv_label(variant.calling_conv),
			)
		}
		report_unsupported_calling_conv_in_type(ir, variant.return_type, seen)
		for p in variant.params {
			report_unsupported_calling_conv_in_type(ir, p.type, seen)
		}
	case Type_Pointer:
		report_unsupported_calling_conv_in_type(ir, variant.pointee, seen)
	case Type_Lowered_Pointer:
		report_unsupported_calling_conv_in_type(ir, variant.pointee, seen)
	case Type_Array:
		report_unsupported_calling_conv_in_type(ir, variant.element, seen)
	case Type_Builtin, Type_Std, Type_Idiomatic_Leaf, Type_Record_Ref, Type_Enum_Ref, Type_Typedef_Ref, Type_Bit_Set:
	}
}
