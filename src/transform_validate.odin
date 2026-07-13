package h2odin

import "core:fmt"

// Post-rename name validation detects and reports; it never
// auto-renames. A collision has no conservative default spelling, so the
// generator fails closed (default severity error) and the user resolves it
// via naming.overrides / naming.override.

validate_symbol_names :: proc(ir: ^IR) {
	validate_package_scope(ir)

	for ref in ir.order {
		switch ref.kind {
		case .Invalid, .Func, .Var, .Typedef, .Macro, .Bit_Set, .Wrapper:
		// package scope above; params below
		case .Record:
			rec := ir.records[ref.index]
			if rec.name == "" {
				continue
			}
			outer := make(map[string]bool, context.temp_allocator)
			validate_record_scope(ir, rec, rec.name, outer)
		case .Enum:
			enm := ir.enums[ref.index]
			if enm.name == "" {
				continue
			}
			validate_enum_members(ir, enm)
		}
	}

	// Proc params (top-level funcs + function-pointer types).
	for ref in ir.order {
		if ref.kind != .Func {
			continue
		}
		fn := ir.funcs[ref.index]
		validate_params(ir, fn.params, fmt.tprintf("proc %s", fn.name))
	}
	for info in ir.types {
		if variant, is_proc := info.variant.(Type_Proc); is_proc {
			validate_params(ir, variant.params, "proc type")
		}
	}
}

validate_package_scope :: proc(ir: ^IR) {
	// Final Odin name → first kind tag, then collision count.
	first_kind := make(map[string]string, context.temp_allocator)
	count := make(map[string]int, context.temp_allocator)

	// C `typedef struct Foo Foo` / `typedef enum Bar Bar` put both the tag and
	// the typedef in the ordering list under the same name; Emission merges
	// them into one Odin type. Treat that pair as a single package name.
	tag_names := make(map[string]bool, context.temp_allocator)
	for ref in ir.order {
		#partial switch ref.kind {
		case .Record:
			if n := ir.records[ref.index].name; n != "" {
				tag_names[n] = true
			}
		case .Enum:
			if n := ir.enums[ref.index].name; n != "" {
				tag_names[n] = true
			}
		}
	}

	note :: proc(first_kind: ^map[string]string, count: ^map[string]int, name, kind: string) {
		if name == "" {
			return
		}
		count[name] += 1
		if name not_in first_kind {
			first_kind[name] = kind
		}
	}

	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			note(&first_kind, &count, ir.funcs[ref.index].name, "proc")
		case .Var:
			note(&first_kind, &count, ir.vars[ref.index].name, "var")
		case .Record:
			note(&first_kind, &count, ir.records[ref.index].name, "type")
		case .Enum:
			note(&first_kind, &count, ir.enums[ref.index].name, "type")
		case .Typedef:
			name := ir.typedefs[ref.index].name
			if tag_names[name] {
				continue // same-name tag+typedef idiom — one Odin type
			}
			note(&first_kind, &count, name, "type")
		case .Macro:
			note(&first_kind, &count, ir.macros[ref.index].name, "const")
		case .Bit_Set:
			note(&first_kind, &count, ir.bit_sets[ref.index].name, "type")
		case .Wrapper:
			note(&first_kind, &count, ir.wrappers[ref.index].name, "proc")
		}
	}

	for name, n in count {
		if n < 2 {
			continue
		}
		ir_diag(
			ir,
			.Symbol_Collision,
			"package-scope name %q is used by %d declarations (first kind %s); disambiguate with naming.overrides or strip_prefixes",
			name,
			n,
			first_kind[name],
		)
	}
}

validate_enum_members :: proc(ir: ^IR, enm: Enum_Decl) {
	seen := make(map[string]bool, context.temp_allocator)
	for m in enm.members {
		if m.name == "" {
			continue
		}
		if seen[m.name] {
			ir_diag(ir, .Symbol_Collision, "enum %q has duplicate member name %q; disambiguate with naming.overrides or enums.member", enm.name, m.name)
			continue
		}
		seen[m.name] = true
	}
}

validate_params :: proc(ir: ^IR, params: []Param, scope: string) {
	names := make(map[string]bool, context.temp_allocator)
	for p in params {
		if p.name == "" || p.name == "_" {
			continue
		}
		if names[p.name] {
			ir_diag(ir, .Symbol_Collision, "%s has duplicate parameter name %q", scope, p.name)
		}
		names[p.name] = true
	}

	// Shadowing: a parameter name that is also used as a type name by any
	// parameter in this list. Alone `httppost: ^^httppost` is legal in Odin;
	// a later param that also needs the type is not.
	type_use_count := make(map[string]int, context.temp_allocator)
	for p in params {
		base := type_base_name(ir, p.type, p.type_spelling)
		if base != "" {
			type_use_count[base] += 1
		}
	}
	for p in params {
		if p.name == "" || p.name == "_" {
			continue
		}
		uses := type_use_count[p.name]
		if uses == 0 {
			continue
		}
		// Alone self-annotation: one type use, and this param's type is that use.
		self_base := type_base_name(ir, p.type, p.type_spelling)
		if uses == 1 && self_base == p.name {
			continue
		}
		ir_diag(
			ir,
			.Symbol_Collision,
			"%s: parameter %q shadows type %q used in the parameter list; rename the parameter (naming.override)",
			scope,
			p.name,
			p.name,
		)
	}
}

validate_record_scope :: proc(ir: ^IR, rec: Record_Decl, scope_name: string, outer_names: map[string]bool) {
	// Field names declared in this body.
	field_names := make(map[string]bool, context.temp_allocator)
	for f in rec.fields {
		if f.name == "" {
			continue
		}
		if field_names[f.name] {
			ir_diag(ir, .Symbol_Collision, "record %q has duplicate field name %q", scope_name, f.name)
		}
		field_names[f.name] = true
	}

	// Names in scope for type resolution: outer + this body's fields.
	// Nested bodies see parent field names (Odin nested-struct behaviour).
	in_scope := make(map[string]bool, context.temp_allocator)
	for n in outer_names {
		in_scope[n] = true
	}
	for n in field_names {
		in_scope[n] = true
	}

	// Count type-base uses at this level (not nested) for the alone-self rule.
	type_use_count := make(map[string]int, context.temp_allocator)
	for f in rec.fields {
		if _, ok := nested_anonymous_record(ir, f.type); ok {
			continue // nested fields are a separate body
		}
		base := type_base_name(ir, f.type, f.type_spelling)
		if base != "" {
			type_use_count[base] += 1
		}
	}

	for f in rec.fields {
		if nested, ok := nested_anonymous_record(ir, f.type); ok {
			// Nested anonymous body: sibling field names stay in scope, but
			// this field's own name does not — Odin allows
			// `vfs: struct { p: ^vfs }` while forbidding a sibling
			// `vfs: i32` from shadowing type uses in a nested neighbour.
			nested_outer := make(map[string]bool, context.temp_allocator)
			for n in outer_names {
				nested_outer[n] = true
			}
			for n in field_names {
				if n != f.name {
					nested_outer[n] = true
				}
			}
			nested_scope := scope_name
			if f.name != "" {
				nested_scope = fmt.tprintf("%s.%s", scope_name, f.name)
			}
			validate_record_scope(ir, nested, nested_scope, nested_outer)
			continue
		}

		base := type_base_name(ir, f.type, f.type_spelling)
		if base == "" || !in_scope[base] {
			continue
		}

		// Alone self-annotation in this body, not shadowed by an outer name:
		// `format: format` with no other type use of format here is legal.
		if f.name == base && !outer_names[base] && type_use_count[base] == 1 {
			continue
		}

		shadowing_field := f.name
		if field_names[base] {
			shadowing_field = base
		}
		ir_diag(
			ir,
			.Symbol_Collision,
			"record %q: field %q shadows type %q used in this declaration; rename the field (naming.override)",
			scope_name,
			shadowing_field,
			base,
		)
	}
}

// The package-level type name a field/param type refers to, peeling pointers
// and arrays. Empty when the type is not a simple named package type
// (builtin, qualified platform spelling, anonymous body, …).
type_base_name :: proc(ir: ^IR, handle: Type_Handle, spelling_override: string) -> string {
	if spelling_override != "" {
		return simple_ident(spelling_override)
	}
	if handle == 0 {
		return ""
	}
	info := ir_type(ir, handle)
	switch v in info.variant {
	case Type_Builtin, Type_Std, Type_Bit_Set, Type_Proc, Type_Pointer:
		return ""
	case Type_Idiomatic_Leaf:
		return simple_ident(v.spelling)
	case Type_Lowered_Pointer:
		if v.kind == .Rawptr || v.kind == .CString || v.kind == .Proc {
			return ""
		}
		return type_base_name(ir, v.pointee, "")
	case Type_Array:
		return type_base_name(ir, v.element, "")
	case Type_Record_Ref:
		rec := ir.records[v.decl]
		return rec.name // "" for anonymous — not a package name
	case Type_Enum_Ref:
		return ir.enums[v.decl].name
	case Type_Typedef_Ref:
		return ir.typedefs[v.decl].name
	}
	return ""
}

// Unqualified identifier: "format" stays, "posix.sockaddr" and "[2]f32" do not
// participate in package-name shadowing.
simple_ident :: proc(spelling: string) -> string {
	if spelling == "" {
		return ""
	}
	// Reject anything that is not a bare identifier.
	for r in spelling {
		if r == '.' || r == '[' || r == '^' || r == ' ' || r == '(' {
			return ""
		}
	}
	return spelling
}

// Anonymous record body inlined at a field (Type_Record_Ref with empty name).
nested_anonymous_record :: proc(ir: ^IR, handle: Type_Handle) -> (Record_Decl, bool) {
	if handle == 0 {
		return {}, false
	}
	info := ir_type(ir, handle)
	ref, is_ref := info.variant.(Type_Record_Ref)
	if !is_ref {
		return {}, false
	}
	rec := ir.records[ref.decl]
	if rec.name != "" {
		return {}, false
	}
	return rec, true
}
