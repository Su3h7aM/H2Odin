package h2odin

import "core:fmt"

substitute_leaf_types :: proc(ir: ^IR) {
	original_type_count := len(ir.types) // slots appended below carry no leaves to revisit
	for type_index in 0 ..< original_type_count {
		type_info := ir.types[type_index]
		spelling: string
		reason: Idiomatic_Reason
		measured_size := -1

		#partial switch variant in type_info.variant {
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
			measured_size = variant.size
			preferred_spelling := builtin_spellings[variant.kind].idiomatic
			if builtin_is_integer(variant.kind) {
				spelling, reason = resolve_integer_leaf_spelling(preferred_spelling, measured_size, builtin_is_unsigned(variant.kind))
			} else if measured_size == odin_type_size(preferred_spelling) {
				spelling = preferred_spelling
				reason = .Table_Preference
			}
		case Type_Std:
			mapping, known := std_mapping_for(variant.name)
			if !known {
				continue
			}
			measured_size = variant.size
			spelling, reason = resolve_integer_leaf_spelling(mapping.idiomatic, measured_size, variant.unsigned)
		case:
			continue
		}

		if spelling == "" {
			report_unresolved_idiomatic_leaf(ir, type_info, measured_size)
			continue
		}

		// Rewriting the shared slot in place substitutes every use at once —
		// interned builtins and enum backing types included. The original
		// moves to a fresh slot first.
		original_type := ir_add_type(ir, type_info)
		ir.types[type_index] = Type_Info {
			is_const = type_info.is_const,
			variant = Type_Idiomatic_Leaf{original = original_type, spelling = spelling, reason = reason},
		}
	}
}

// Rungs 1 and 2 for integer leaves: prefer the table's semantic spelling
// when its width matches, otherwise derive a fixed-width spelling from the
// measured size and signedness. Non-integer builtins never use this fallback.
resolve_integer_leaf_spelling :: proc(preferred_spelling: string, measured_size: int, unsigned: bool) -> (spelling: string, reason: Idiomatic_Reason) {
	if preferred_spelling != "" && measured_size >= 0 && measured_size == odin_type_size(preferred_spelling) {
		return preferred_spelling, .Table_Preference
	}
	if derived_spelling := derive_native_integer_spelling(measured_size, unsigned); derived_spelling != "" {
		return derived_spelling, .Derived_From_Measurement
	}
	return "", {}
}

// A fixed-width Odin spelling for an integer leaf of the given measured
// size and signedness. Size and signedness together are a complete
// determination for any C integer type — there is no partial case here,
// only "measurable" or not.
derive_native_integer_spelling :: proc(measured_size: int, unsigned: bool) -> string {
	switch measured_size {
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
report_unresolved_idiomatic_leaf :: proc(ir: ^IR, type_info: Type_Info, measured_size: int) {
	name: string
	#partial switch variant in type_info.variant {
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
		measured_size,
	)
}

lower_type :: proc(ir: ^IR, type_handle: Type_Handle) {
	type_info := ir_type(ir, type_handle)
	#partial switch variant in type_info.variant {
	case Type_Pointer:
		lower_type(ir, variant.pointee)
		// Array-parameter decay is a declaration-shape proof of array
		// semantics — ABI-identical [^]T, not a guess.
		if variant.is_array_param_decay {
			// Still honor proven void*/const char*/function special cases if
			// the array element was one of those (rare); otherwise Multi.
			lowered_pointer := lower_pointer(ir, variant.pointee)
			if lowered_pointer.kind == .Single {
				lowered_pointer.kind = .Multi
				lowered_pointer.confidence = .Proven
				lowered_pointer.reason = .Array_Param_Decay
			}
			type_info.variant = lowered_pointer
		} else {
			type_info.variant = lower_pointer(ir, variant.pointee)
		}
		ir.types[int(type_handle)] = type_info
	case Type_Array:
		lower_type(ir, variant.element)
	case Type_Proc:
		lower_type(ir, variant.return_type)
		for parameter in variant.params {
			lower_type(ir, parameter.type)
		}
	}
}

lower_pointer :: proc(ir: ^IR, pointee_type: Type_Handle) -> Type_Lowered_Pointer {
	pointee_info := ir_type(ir, pointee_type)
	#partial switch variant in pointee_info.variant {
	case Type_Builtin:
		if variant.kind == .Void {
			return Type_Lowered_Pointer{pointee = pointee_type, kind = .Rawptr, confidence = .Proven, reason = .Void_Pointer}
		}
		if (variant.kind == .Char_Signed || variant.kind == .Char_Unsigned) && pointee_info.is_const {
			return Type_Lowered_Pointer{pointee = pointee_type, kind = .CString, confidence = .Proven, reason = .Const_Char_Pointer}
		}
	case Type_Proc:
		return Type_Lowered_Pointer{pointee = pointee_type, kind = .Proc, confidence = .Proven, reason = .Function_Pointer}
	}

	return Type_Lowered_Pointer{pointee = pointee_type, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}
}

// Force a lowered single (or already multi) pointer to [^]T. Returns false when
// the type is not a suitable data pointer (rawptr / cstring / proc / non-ptr).
force_multi_pointer :: proc(ir: ^IR, type_handle: Type_Handle, reason: Pointer_Lowering_Reason) -> bool {
	type_info := ir_type(ir, type_handle)
	lowered, is_lowered := type_info.variant.(Type_Lowered_Pointer)
	if !is_lowered {
		return false
	}
	#partial switch lowered.kind {
	case .Single, .Multi:
		lowered.kind = .Multi
		lowered.confidence = .Proven
		lowered.reason = reason
		type_info.variant = lowered
		ir.types[int(type_handle)] = type_info
		return true
	}
	return false
}

report_pointer_lowering_guesses :: proc(ir: ^IR, opaque_records: []bool = nil) {
	for ref in ir.order {
		switch ref.kind {
		case .Invalid, .Macro, .Bit_Set, .Wrapper:
		case .Func:
			decl := ir.funcs[ref.index]
			if decl.return_type_spelling == "" {
				report_type_guesses(ir, decl.return_type, fmt.tprintf("function %q return type", decl.name))
			}
			for param, i in decl.params {
				if param.type_spelling != "" {
					continue
				}
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
			if !record_body_emits_fields(decl, emission_fallback) {
				continue
			}
			for field in decl.fields {
				if field.type_spelling != "" {
					continue
				}
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
			if param.type_spelling == "" {
				report_type_guesses(ir, param.type, site)
			}
		}
	}
}
