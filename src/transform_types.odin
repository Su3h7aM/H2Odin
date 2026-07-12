package h2odin

import "core:fmt"

// Spec 0005: typedefs of pointers to incomplete records emit
// `Name :: distinct rawptr` (C already distinguishes those types). Multiple
// typedefs of the same incomplete record stay mutually assignable — first in
// declaration order is distinct; later ones alias it. Incomplete *Impl
// records are dropped from emission. void* typedefs stay plain rawptr unless
// listed in types.distinct.
apply_opaque_handles :: proc(ir: ^IR, policy: ^Policy) {
	distinct_names: map[string]bool
	if len(policy.types_distinct) > 0 {
		distinct_names = make(map[string]bool, context.temp_allocator)
		for name in policy.types_distinct {
			distinct_names[name] = true
		}
	}

	// Incomplete record index → first typedef Decl_Handle that claimed it.
	first_for_record := make(map[Decl_Handle]Decl_Handle, context.temp_allocator)
	records_to_drop := make(map[Decl_Handle]bool, context.temp_allocator)
	changed := false

	for ref in ir.order {
		if ref.kind != .Typedef {
			continue
		}
		td_handle := Decl_Handle(ref.index)
		td := &ir.typedefs[ref.index]
		if td.is_unresolvable || td.name == "" {
			continue
		}

		if record, is_opaque := opaque_handle_record(ir, td.aliased); is_opaque {
			if first, found := first_for_record[record]; found {
				// Same incomplete record as an earlier typedef: stay an alias
				// so C's mutual assignability is preserved. Type_Typedef_Ref
				// tracks renames of the first handle.
				td.aliased = ir_add_type(ir, Type_Info{variant = Type_Typedef_Ref{decl = first}})
			} else {
				first_for_record[record] = td_handle
				records_to_drop[record] = true
				td.aliased = ir_add_type(
					ir,
					Type_Info{variant = Type_Idiomatic_Leaf{original = td.aliased, spelling = SPELLING_DISTINCT_RAWPTR, reason = .Opaque_Handle}},
				)
			}
			changed = true
			continue
		}

		// void* (and other rawptr) typedefs: opt-in only.
		if len(distinct_names) > 0 && distinct_names[td.name] && type_is_rawptr(ir, td.aliased) {
			td.aliased = ir_add_type(
				ir,
				Type_Info{variant = Type_Idiomatic_Leaf{original = td.aliased, spelling = SPELLING_DISTINCT_RAWPTR, reason = .Opaque_Handle}},
			)
			changed = true
			continue
		}

		// Pure `typedef void Name` (curl's CURL, miniaudio's ma_data_source):
		// a common C opaque-handle idiom where the typedef names an incomplete
		// type. Emit as `Name :: distinct rawptr` — references via
		// Type_Typedef_Ref already use the name, and `Name *` becomes `^Name`
		// naturally. No pointer level is collapsed (unlike incomplete-tag
		// handles) because the void typedef has no separate record to peel.
		if type_is_void_builtin(ir, td.aliased) {
			td.aliased = ir_add_type(
				ir,
				Type_Info{variant = Type_Idiomatic_Leaf{original = td.aliased, spelling = SPELLING_DISTINCT_RAWPTR, reason = .Opaque_Handle}},
			)
			changed = true
		}
	}

	if !changed && len(records_to_drop) == 0 {
		return
	}

	// Drop incomplete records that only existed as opaque-handle targets.
	if len(records_to_drop) == 0 {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		if ref.kind == .Record && records_to_drop[Decl_Handle(ref.index)] {
			continue
		}
		append(&kept, ref)
	}
	ir.order = kept
}

// Pointer-to-incomplete-record after lowering: the C opaque-handle idiom.
opaque_handle_record :: proc(ir: ^IR, handle: Type_Handle) -> (record: Decl_Handle, ok: bool) {
	ptr, is_ptr := ir_type(ir, handle).variant.(Type_Lowered_Pointer)
	if !is_ptr || ptr.kind != .Single {
		return 0, false
	}
	rec, is_rec := ir_type(ir, ptr.pointee).variant.(Type_Record_Ref)
	if !is_rec {
		return 0, false
	}
	if ir.records[rec.decl].is_complete {
		return 0, false
	}
	return rec.decl, true
}

type_is_rawptr :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	#partial switch variant in ir_type(ir, handle).variant {
	case Type_Lowered_Pointer:
		return variant.kind == .Rawptr
	case Type_Idiomatic_Leaf:
		return variant.spelling == SPELLING_RAWPTR
	}
	return false
}

// True when the type is a bare C void builtin — not a void pointer (that is
// a lowered rawptr). Used to detect the `typedef void Name` opaque-handle
// idiom that must emit as `distinct rawptr`, never as the unspellable void.
type_is_void_builtin :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	builtin, is_builtin := ir_type(ir, handle).variant.(Type_Builtin)
	return is_builtin && builtin.kind == .Void
}

// Spec 0007: incomplete tag records may emit as handle style
// (`T :: distinct rawptr`, one pointer level collapsed: T* → T, T** → ^T).
// Mode sets the default (ABI faithful, idiomatic collapses); types.opaque
// is a per-name bool override in either direction. Complete records never
// auto-collapse; forcing them via types.opaque fails closed.
apply_opaque_tag_records :: proc(ir: ^IR, policy: ^Policy, mode: Type_Mode) {
	idiomatic_default := mode == .Idiomatic
	if !idiomatic_default && len(policy.types_opaque) == 0 {
		return
	}

	opaque_records := make(map[Decl_Handle]bool, context.temp_allocator)
	for &record, i in ir.records {
		if record.name == "" {
			continue
		}
		// Override: Some(true)/Some(false). Absent → mode default.
		want_handle: bool
		if forced, has_override := policy.types_opaque[record.name]; has_override {
			want_handle = forced
		} else if !idiomatic_default {
			continue // ABI default: faithful
		} else {
			want_handle = true // idiomatic default: collapse incomplete tags
		}

		if !want_handle {
			continue
		}
		if record.is_complete {
			// Collapse would change layout. Only diagnose when the user
			// forced handle style; idiomatic auto-skip of complete records
			// is silent (they are not incomplete tags).
			if _, forced := policy.types_opaque[record.name]; forced {
				ir_diag(
					ir,
					.Opaque_Record_Complete,
					"types.opaque %q names a complete record; leaving faithful emission (struct body + pointers)",
					record.name,
				)
			}
			continue
		}
		record.emit_as_handle = true
		opaque_records[Decl_Handle(i)] = true
	}
	if len(opaque_records) == 0 {
		return
	}

	// Collapse one pointer level: rewrite every Single lowered pointer whose
	// *immediate* pointee resolves to an opaque tag record into a bare
	// Type_Record_Ref. Real headers usually spell `typedef struct T T`, so
	// the pointee is a Type_Typedef_Ref that must be peeled. Identify first,
	// then apply — rewriting in one pass would cascade (after ^T → T, ^^T
	// looks like pointer-to-record and collapses again). Outer pointers keep
	// their lowered-pointer form; emission writes ^T for what was T**.
	count := len(ir.types)
	to_collapse := make([dynamic]int, 0, 8, context.temp_allocator)
	collapse_to := make([]Decl_Handle, count, context.temp_allocator)
	for i in 0 ..< count {
		ptr, is_ptr := ir.types[i].variant.(Type_Lowered_Pointer)
		if !is_ptr || ptr.kind != .Single {
			continue
		}
		rec_decl, is_rec := type_as_record_decl(ir, ptr.pointee)
		if !is_rec || !opaque_records[rec_decl] {
			continue
		}
		append(&to_collapse, i)
		collapse_to[i] = rec_decl
	}
	for i in to_collapse {
		info := ir.types[i]
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Record_Ref{decl = collapse_to[i]},
		}
	}
}

// Peel typedef aliases to find a Type_Record_Ref (if any).
type_as_record_decl :: proc(ir: ^IR, handle: Type_Handle) -> (decl: Decl_Handle, ok: bool) {
	// Bound the peel so a pathological typedef cycle cannot hang.
	cur := handle
	for _ in 0 ..< 32 {
		#partial switch variant in ir_type(ir, cur).variant {
		case Type_Record_Ref:
			return variant.decl, true
		case Type_Typedef_Ref:
			td := ir.typedefs[variant.decl]
			if td.is_unresolvable {
				return 0, false
			}
			cur = td.aliased
		case:
			return 0, false
		}
	}
	return 0, false
}

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
		// Array-parameter decay is a declaration-shape proof of array
		// semantics — ABI-identical [^]T, not a guess (spec 0011).
		if variant.is_array_param_decay {
			// Still honor proven void*/const char*/function special cases if
			// the array element was one of those (rare); otherwise Multi.
			base := lower_pointer(ir, variant.pointee)
			if base.kind == .Single {
				base.kind = .Multi
				base.confidence = .Proven
				base.reason = .Array_Param_Decay
			}
			info.variant = base
		} else {
			info.variant = lower_pointer(ir, variant.pointee)
		}
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

// Force a lowered single (or already multi) pointer to [^]T. Returns false when
// the type is not a suitable data pointer (rawptr / cstring / proc / non-ptr).
force_multi_pointer :: proc(ir: ^IR, handle: Type_Handle, reason: Pointer_Lowering_Reason) -> bool {
	info := ir_type(ir, handle)
	lowered, is_lowered := info.variant.(Type_Lowered_Pointer)
	if !is_lowered {
		return false
	}
	#partial switch lowered.kind {
	case .Single, .Multi:
		lowered.kind = .Multi
		lowered.confidence = .Proven
		lowered.reason = reason
		info.variant = lowered
		ir.types[int(handle)] = info
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
