package h2odin

import "core:fmt"

substitute_leaf_types :: proc(ir: ^IR) {
	count := len(ir.types) // slots appended below carry no leaves to revisit
	for i in 0 ..< count {
		info := ir.types[i]
		spelling: string
		reason: Idiomatic_Reason
		measured := -1

		#partial switch variant in info.variant {
		case Type_Builtin:
			if variant.kind == .Void {
				// No scalar shape; void is handled elsewhere (bare returns,
				// void* pointer lowering), never substituted as a leaf.
				continue
			}
			if variant.size == -1 {
				// Builtins are pre-seeded for every kind at ir_init, whether
				// or not the header actually uses them; a real capture
				// always measures a size (builtins are never incomplete).
				// -1 here means this kind was never used, not a genuine
				// measurement failure — nothing to diagnose.
				continue
			}
			measured = variant.size
			spelling, reason = resolve_leaf_spelling(builtin_spellings[variant.kind].idiomatic, measured, builtin_is_unsigned(variant.kind))
		case Type_Std:
			row, known := std_mapping_for(variant.name)
			if !known {
				continue
			}
			measured = variant.size
			spelling, reason = resolve_leaf_spelling(row.idiomatic, measured, variant.unsigned)
		case:
			continue
		}

		if spelling == "" {
			report_unresolved_idiomatic_leaf(ir, info, measured)
			continue
		}

		// Rewriting the shared slot in place substitutes every use at once —
		// interned builtins and enum backing types included. The original
		// moves to a fresh slot first.
		original := ir_add_type(ir, info)
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = spelling, reason = reason},
		}
	}
}

// Rungs 1 and 2 of the substitution ladder: prefer the table's semantic
// spelling if the measured size confirms it on this target, otherwise
// derive a fixed-width native spelling straight from the measured size and
// signedness. Returns "" when neither is possible — rung 3, the fallback,
// is the caller's job.
resolve_leaf_spelling :: proc(preferred: string, measured: int, unsigned: bool) -> (spelling: string, reason: Idiomatic_Reason) {
	if preferred != "" && measured >= 0 && measured == odin_type_size(preferred) {
		return preferred, .Table_Preference
	}
	if derived := derive_native_spelling(measured, unsigned); derived != "" {
		return derived, .Derived_From_Measurement
	}
	return "", {}
}

// A fixed-width Odin spelling for an integer leaf of the given measured
// size and signedness. Size and signedness together are a complete
// determination for any C integer type — there is no partial case here,
// only "measurable" or not.
derive_native_spelling :: proc(size: int, unsigned: bool) -> string {
	switch size {
	case 1:
		return "u8" if unsigned else "i8"
	case 2:
		return "u16" if unsigned else "i16"
	case 4:
		return "u32" if unsigned else "i32"
	case 8:
		return "u64" if unsigned else "i64"
	}
	return ""
}

// Rung 3: the type could not be resolved to a native Odin spelling on this
// target. Idiomatic mode keeps the ABI spelling for it, but this should be
// rare, so it is collected for the end-of-run diagnostics report.
report_unresolved_idiomatic_leaf :: proc(ir: ^IR, info: Type_Info, measured: int) {
	name: string
	#partial switch variant in info.variant {
	case Type_Builtin:
		name = builtin_spellings[variant.kind].abi
	case Type_Std:
		name = variant.name
	}
	ir_diag(
		ir,
		.Unresolved_Idiomatic_Leaf,
		"idiomatic mode: %s has no provable native spelling on this target (measured size %d); keeping ABI spelling",
		name,
		measured,
	)
}

lower_type :: proc(ir: ^IR, handle: Type_Handle) {
	info := ir_type(ir, handle)
	#partial switch variant in info.variant {
	case Type_Pointer:
		lower_type(ir, variant.pointee)
		lowering := lower_pointer(ir, variant.pointee)
		info.variant = lowering
		ir.types[int(handle)] = info
	case Type_Array:
		lower_type(ir, variant.element)
	case Type_Proc:
		lower_type(ir, variant.return_type)
		for param in variant.params {
			lower_type(ir, param.type)
		}
	}
}

lower_pointer :: proc(ir: ^IR, pointee: Type_Handle) -> Type_Lowered_Pointer {
	pointee_info := ir_type(ir, pointee)
	#partial switch variant in pointee_info.variant {
	case Type_Builtin:
		if variant.kind == .Void {
			return Type_Lowered_Pointer{pointee = pointee, kind = .Rawptr, confidence = .Proven, reason = .Void_Pointer}
		}
		if (variant.kind == .Char_Signed || variant.kind == .Char_Unsigned) && pointee_info.is_const {
			return Type_Lowered_Pointer{pointee = pointee, kind = .CString, confidence = .Proven, reason = .Const_Char_Pointer}
		}
	case Type_Proc:
		return Type_Lowered_Pointer{pointee = pointee, kind = .Proc, confidence = .Proven, reason = .Function_Pointer}
	}

	return Type_Lowered_Pointer{pointee = pointee, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}
}

report_pointer_lowering_guesses :: proc(ir: ^IR, opaque_records: []bool = nil) {
	for ref in ir.order {
		switch ref.kind {
		case .Invalid, .Macro, .Bit_Set:
		case .Func:
			decl := ir.funcs[ref.index]
			report_type_guesses(ir, decl.return_type, fmt.tprintf("function %q return type", decl.name))
			for param, i in decl.params {
				site: string
				if param.name != "" {
					site = fmt.tprintf("function %q parameter %q", decl.name, param.name)
				} else {
					site = fmt.tprintf("function %q parameter %d", decl.name, i)
				}
				if param.facts.has_length_like_neighbour {
					length_param := decl.params[param.facts.length_param_index]
					site = fmt.tprintf("%s (length-like neighbour %q)", site, length_param.name)
				}
				report_type_guesses(ir, param.type, site)
			}
		case .Record:
			decl := ir.records[ref.index]
			emission_fallback := len(opaque_records) == len(ir.records) && opaque_records[ref.index]
			if !decl.is_complete || decl.has_unrepresentable_fields || emission_fallback {
				continue
			}
			for field in decl.fields {
				if field.name != "" {
					report_type_guesses(ir, field.type, fmt.tprintf("record %q field %q", record_display_name(decl), field.name))
				} else {
					report_type_guesses(ir, field.type, fmt.tprintf("record %q anonymous field", record_display_name(decl)))
				}
			}
		case .Enum:
		case .Typedef:
			decl := ir.typedefs[ref.index]
			if !decl.is_unresolvable {
				report_type_guesses(ir, decl.aliased, fmt.tprintf("typedef %q", decl.name))
			}
		case .Var:
			decl := ir.vars[ref.index]
			report_type_guesses(ir, decl.type, fmt.tprintf("global variable %q", decl.name))
		}
	}
}

report_type_guesses :: proc(ir: ^IR, handle: Type_Handle, site: string) {
	#partial switch variant in ir_type(ir, handle).variant {
	case Type_Lowered_Pointer:
		if variant.confidence == .Guessed {
			ir_diag(ir, .Pointer_Lowering_Guess, "guessed pointer lowering in %s: defaulted to ^T", site)
		}
		report_type_guesses(ir, variant.pointee, site)
	case Type_Array:
		report_type_guesses(ir, variant.element, site)
	case Type_Proc:
		report_type_guesses(ir, variant.return_type, site)
		for param in variant.params {
			report_type_guesses(ir, param.type, site)
		}
	}
}
