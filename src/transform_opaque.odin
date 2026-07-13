package h2odin

// Opaque C types use two related representations. Pointer typedef handles
// preserve C's distinct handle types, while incomplete tag records may also
// collapse one pointer level in idiomatic mode or by explicit policy.
apply_opaque_types :: proc(ir: ^IR, policy: ^Policy, type_mode: Type_Mode) {
	apply_opaque_pointer_typedefs(ir, policy)
	apply_opaque_tag_records(ir, policy, type_mode)
}

// A typedef of a pointer to an incomplete record is already a distinct C
// handle type, so emit it as `distinct rawptr`. Multiple typedefs of the same
// record remain aliases of the first handle to preserve mutual assignability.
// A pure `typedef void Name` follows the same handle convention; void pointer
// typedefs opt in through types.distinct.
apply_opaque_pointer_typedefs :: proc(ir: ^IR, policy: ^Policy) {
	distinct_names := make(map[string]bool, context.temp_allocator)
	for name in policy.types_distinct {
		distinct_names[name] = true
	}

	first_handle_by_record := make(map[Decl_Handle]Decl_Handle, context.temp_allocator)
	drop_candidates := make(map[Decl_Handle]bool, context.temp_allocator)

	for declaration in ir.order {
		if declaration.kind != .Typedef {
			continue
		}

		typedef_handle := Decl_Handle(declaration.index)
		typedef := &ir.typedefs[declaration.index]
		if typedef.is_unresolvable || typedef.name == "" {
			continue
		}

		if record, is_handle := opaque_pointer_typedef_record(ir, typedef.aliased); is_handle {
			if first_handle, found := first_handle_by_record[record]; found {
				typedef.aliased = ir_add_type(ir, Type_Info{variant = Type_Typedef_Ref{decl = first_handle}})
			} else {
				first_handle_by_record[record] = typedef_handle
				drop_candidates[record] = true
				typedef.aliased = add_opaque_handle_type(ir, typedef.aliased)
			}
			continue
		}

		if distinct_names[typedef.name] && type_is_rawptr(ir, typedef.aliased) {
			typedef.aliased = add_opaque_handle_type(ir, typedef.aliased)
			continue
		}

		if type_is_void_builtin(ir, typedef.aliased) {
			typedef.aliased = add_opaque_handle_type(ir, typedef.aliased)
		}
	}

	drop_unused_opaque_record_declarations(ir, drop_candidates, first_handle_by_record)
}

add_opaque_handle_type :: proc(ir: ^IR, original: Type_Handle) -> Type_Handle {
	// Keep a separate provenance copy for diagnostics and ABI auditing. The
	// original slot may also be a live direct `struct Impl *` use and can
	// therefore be canonicalized to the new typedef below.
	audit_original := ir_add_type(ir, ir_type(ir, original))
	return ir_add_type(ir, Type_Info{variant = Type_Idiomatic_Leaf{original = audit_original, spelling = SPELLING_DISTINCT_RAWPTR, reason = .Opaque_Handle}})
}

// Pointer-to-incomplete-record after pointer lowering: the C opaque-handle
// idiom. Complete records and non-single pointers retain their faithful form.
opaque_pointer_typedef_record :: proc(ir: ^IR, handle: Type_Handle) -> (record: Decl_Handle, ok: bool) {
	pointer, is_pointer := ir_type(ir, handle).variant.(Type_Lowered_Pointer)
	if !is_pointer || pointer.kind != .Single {
		return {}, false
	}
	record_reference, is_record := ir_type(ir, pointer.pointee).variant.(Type_Record_Ref)
	if !is_record || ir.records[record_reference.decl].is_complete {
		return {}, false
	}
	return record_reference.decl, true
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

// A bare C void builtin is distinct from void*, which pointer lowering has
// already represented as rawptr.
type_is_void_builtin :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	builtin, is_builtin := ir_type(ir, handle).variant.(Type_Builtin)
	return is_builtin && builtin.kind == .Void
}

// Canonicalize direct `struct Impl *` uses to the equivalent public handle,
// then remove implementation records only when no other live type refers to
// them. This keeps the handle representation singular without leaving dangling
// record names.
drop_unused_opaque_record_declarations :: proc(ir: ^IR, candidates: map[Decl_Handle]bool, canonical_handles: map[Decl_Handle]Decl_Handle) {
	if len(candidates) == 0 {
		return
	}

	referenced_records := canonicalize_opaque_record_references(ir, canonical_handles)
	kept_count := 0
	for declaration in ir.order {
		should_drop := declaration.kind == .Record && candidates[Decl_Handle(declaration.index)] && !referenced_records[Decl_Handle(declaration.index)]
		if should_drop {
			continue
		}
		ir.order[kept_count] = declaration
		kept_count += 1
	}
	resize(&ir.order, kept_count)
}

canonicalize_opaque_record_references :: proc(ir: ^IR, canonical_handles: map[Decl_Handle]Decl_Handle) -> map[Decl_Handle]bool {
	referenced_records := make(map[Decl_Handle]bool, context.temp_allocator)
	visited_types := make([]bool, len(ir.types), context.temp_allocator)

	for declaration in ir.order {
		#partial switch declaration.kind {
		case .Func:
			function := ir.funcs[declaration.index]
			canonicalize_opaque_record_reference(ir, function.return_type, canonical_handles, &visited_types, &referenced_records)
			for parameter in function.params {
				canonicalize_opaque_record_reference(ir, parameter.type, canonical_handles, &visited_types, &referenced_records)
			}
		case .Record:
			for field in ir.records[declaration.index].fields {
				canonicalize_opaque_record_reference(ir, field.type, canonical_handles, &visited_types, &referenced_records)
			}
		case .Enum:
			canonicalize_opaque_record_reference(ir, ir.enums[declaration.index].backing, canonical_handles, &visited_types, &referenced_records)
		case .Typedef:
			canonicalize_opaque_record_reference(ir, ir.typedefs[declaration.index].aliased, canonical_handles, &visited_types, &referenced_records)
		case .Var:
			canonicalize_opaque_record_reference(ir, ir.vars[declaration.index].type, canonical_handles, &visited_types, &referenced_records)
		case .Bit_Set:
			canonicalize_opaque_record_reference(ir, ir.bit_sets[declaration.index].elem, canonical_handles, &visited_types, &referenced_records)
		case .Macro, .Wrapper:
		}
	}

	return referenced_records
}

canonicalize_opaque_record_reference :: proc(
	ir: ^IR,
	handle: Type_Handle,
	canonical_handles: map[Decl_Handle]Decl_Handle,
	visited: ^[]bool,
	referenced_records: ^map[Decl_Handle]bool,
) {
	if handle == 0 || visited^[handle] {
		return
	}
	visited^[handle] = true

	type_info := ir_type(ir, handle)
	#partial switch variant in type_info.variant {
	case Type_Record_Ref:
		referenced_records^[variant.decl] = true
	case Type_Pointer:
		canonicalize_opaque_record_reference(ir, variant.pointee, canonical_handles, visited, referenced_records)
	case Type_Lowered_Pointer:
		if variant.kind == .Single {
			if record_reference, is_record := ir_type(ir, variant.pointee).variant.(Type_Record_Ref); is_record {
				if canonical_handle, found := canonical_handles[record_reference.decl]; found {
					ir.types[handle] = Type_Info {
						is_const = type_info.is_const,
						variant = Type_Typedef_Ref{decl = canonical_handle},
					}
					return
				}
			}
		}
		canonicalize_opaque_record_reference(ir, variant.pointee, canonical_handles, visited, referenced_records)
	case Type_Array:
		canonicalize_opaque_record_reference(ir, variant.element, canonical_handles, visited, referenced_records)
	case Type_Proc:
		canonicalize_opaque_record_reference(ir, variant.return_type, canonical_handles, visited, referenced_records)
		for parameter in variant.params {
			canonicalize_opaque_record_reference(ir, parameter.type, canonical_handles, visited, referenced_records)
		}
	case Type_Typedef_Ref:
		typedef := ir.typedefs[variant.decl]
		if !typedef.is_unresolvable {
			canonicalize_opaque_record_reference(ir, typedef.aliased, canonical_handles, visited, referenced_records)
		}
	case Type_Bit_Set:
		canonicalize_opaque_record_reference(ir, variant.elem, canonical_handles, visited, referenced_records)
	case Type_Idiomatic_Leaf:
		// The decided spelling is terminal. Its original type remains only for
		// diagnostics and ABI auditing; emission does not follow it.
		return
	}
}

// Incomplete tag records may emit as handle style (`T :: distinct rawptr`,
// one pointer level collapsed: T* -> T, T** -> ^T). Idiomatic mode enables
// this by default; types.opaque provides a per-name override. Complete records
// always retain their layout, and an explicit attempt to collapse one reports
// a diagnostic.
apply_opaque_tag_records :: proc(ir: ^IR, policy: ^Policy, type_mode: Type_Mode) {
	idiomatic_default := type_mode == .Idiomatic
	if !idiomatic_default && len(policy.types_opaque) == 0 {
		return
	}

	opaque_records := make([]bool, len(ir.records), context.temp_allocator)
	opaque_record_count := 0
	for &record, record_index in ir.records {
		if record.name == "" {
			continue
		}

		should_collapse := idiomatic_default
		if configured_value, configured := policy.types_opaque[record.name]; configured {
			should_collapse = configured_value
		} else if !idiomatic_default {
			continue
		}
		if !should_collapse {
			continue
		}

		if record.is_complete {
			if _, explicitly_configured := policy.types_opaque[record.name]; explicitly_configured {
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
		opaque_records[record_index] = true
		opaque_record_count += 1
	}
	if opaque_record_count == 0 {
		return
	}

	// Identify every collapse before mutating the shared type pool. Rewriting
	// as we scan would make an outer pointer observe the rewritten inner slot
	// and collapse more than one level.
	type_count := len(ir.types)
	types_to_collapse := make([dynamic]int, 0, 8, context.temp_allocator)
	collapse_targets := make([]Decl_Handle, type_count, context.temp_allocator)
	for type_index in 0 ..< type_count {
		pointer, is_pointer := ir.types[type_index].variant.(Type_Lowered_Pointer)
		if !is_pointer || pointer.kind != .Single {
			continue
		}
		record, resolves_to_record := resolve_record_reference(ir, pointer.pointee)
		if !resolves_to_record || !opaque_records[record] {
			continue
		}
		append(&types_to_collapse, type_index)
		collapse_targets[type_index] = record
	}

	for type_index in types_to_collapse {
		type_info := ir.types[type_index]
		ir.types[type_index] = Type_Info {
			is_const = type_info.is_const,
			variant = Type_Record_Ref{decl = collapse_targets[type_index]},
		}
	}
}

// Follow typedef aliases to a record reference. A chain cannot visit more
// distinct type slots than the pool contains, so that bound also terminates
// malformed typedef cycles without imposing an arbitrary depth limit.
resolve_record_reference :: proc(ir: ^IR, handle: Type_Handle) -> (record: Decl_Handle, ok: bool) {
	current := handle
	for _ in 0 ..< len(ir.types) {
		#partial switch variant in ir_type(ir, current).variant {
		case Type_Record_Ref:
			return variant.decl, true
		case Type_Typedef_Ref:
			typedef := ir.typedefs[variant.decl]
			if typedef.is_unresolvable {
				return {}, false
			}
			current = typedef.aliased
		case:
			return {}, false
		}
	}
	return {}, false
}
