package h2odin

import "core:path/slashpath"

// Apply symbols.remove in its documented order: exact names, patterns,
// deprecation, then the predicate callback. Filtering compacts ir.order in
// place; declaration pools remain intact so every existing handle stays
// valid.
filter_declarations :: proc(ir: ^IR, policy: ^Policy) {
	has_exact_names := len(policy.remove_names) > 0
	has_patterns := len(policy.remove_patterns) > 0
	has_deprecation_filter := policy.remove_deprecated
	has_predicate := policy.has_remove_where
	if !has_exact_names && !has_patterns && !has_deprecation_filter && !has_predicate {
		return
	}

	exact_names: map[string]struct{}
	if has_exact_names {
		exact_names = make(map[string]struct{}, context.temp_allocator)
		for name in policy.remove_names {
			exact_names[name] = {}
		}
	}

	kept_count := 0
	for declaration in ir.order {
		symbol, valid := declaration_symbol_context(ir, declaration)
		if !valid {
			continue
		}

		remove := false
		if symbol.name == "" {
			remove = should_remove_anonymous_declaration(policy, declaration.kind, symbol)
		} else {
			remove = should_remove_named_declaration(policy, exact_names, symbol)
		}
		if remove {
			continue
		}

		ir.order[kept_count] = declaration
		kept_count += 1
	}
	resize(&ir.order, kept_count)
}

// Build the stable policy view for a top-level declaration. Invalid ordering
// entries have no declaration and are discarded by the filtering boundary.
declaration_symbol_context :: proc(ir: ^IR, declaration: Decl_Ref) -> (symbol: Symbol_Context, valid: bool) {
	switch declaration.kind {
	case .Invalid:
		return {}, false
	case .Func:
		decl := ir.funcs[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Func,
			deprecated   = decl.deprecated,
		}
	case .Record:
		decl := ir.records[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Type,
			deprecated   = decl.deprecated,
		}
	case .Enum:
		decl := ir.enums[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Type,
			deprecated   = decl.deprecated,
		}
	case .Typedef:
		decl := ir.typedefs[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Type,
			deprecated   = decl.deprecated,
		}
	case .Var:
		decl := ir.vars[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Var,
			deprecated   = decl.deprecated,
		}
	case .Macro:
		decl := ir.macros[declaration.index]
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Const,
			deprecated   = decl.deprecated,
		}
	case .Bit_Set:
		decl := ir.bit_sets[declaration.index]
		// Generated bit-set aliases do not inherit C deprecation.
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Type,
		}
	case .Wrapper:
		decl := ir.wrappers[declaration.index]
		// Wrappers materialize after filtering, but keeping this case makes the
		// ordering boundary total and safe if that sequencing changes.
		symbol = {
			name         = decl.name,
			default_name = decl.name,
			kind         = .Func,
		}
	}
	return symbol, true
}

should_remove_named_declaration :: proc(policy: ^Policy, exact_names: map[string]struct{}, symbol: Symbol_Context) -> bool {
	if symbol.name in exact_names {
		return true
	}
	for pattern in policy.remove_patterns {
		matched, match_error := slashpath.match(pattern, symbol.name)
		if match_error == nil && matched {
			return true
		}
	}
	if policy.remove_deprecated && symbol.deprecated {
		return true
	}
	if policy.has_remove_where {
		return policy_remove_where(policy, symbol)
	}
	return false
}

// Anonymous records are emitted inline and stand or fall with their users.
// Anonymous enums emit free constants, so deprecation policy may remove the
// enum declaration. The predicate sees a deprecated anonymous enum to support
// the equivalent `return sym.deprecated` policy without exposing inline types.
should_remove_anonymous_declaration :: proc(policy: ^Policy, kind: Decl_Kind, symbol: Symbol_Context) -> bool {
	if kind != .Enum || !symbol.deprecated {
		return false
	}
	if policy.remove_deprecated {
		return true
	}
	return policy.has_remove_where && policy_remove_where(policy, symbol)
}
