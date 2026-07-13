package h2odin

import "core:path/slashpath"

// symbols.remove: names → patterns → deprecated → where. Rebuild the ordering
// list with survivors. Dropping is an ordering-list operation only — pool
// entries stay so handles remain valid. Members and fields are never offered
// here.
filter_declarations :: proc(ir: ^IR, policy: ^Policy) {
	has_names := len(policy.remove_names) > 0
	has_patterns := len(policy.remove_patterns) > 0
	if !has_names && !has_patterns && !policy.remove_deprecated && !policy.has_remove_where {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		name: string
		kind: Symbol_Kind
		deprecated: bool
		switch ref.kind {
		case .Invalid:
			continue
		case .Func:
			name = ir.funcs[ref.index].name
			kind = .Func
			deprecated = ir.funcs[ref.index].deprecated
		case .Record:
			name = ir.records[ref.index].name
			kind = .Type
			deprecated = ir.records[ref.index].deprecated
		case .Enum:
			name = ir.enums[ref.index].name
			kind = .Type
			deprecated = ir.enums[ref.index].deprecated
		case .Typedef:
			name = ir.typedefs[ref.index].name
			kind = .Type
			deprecated = ir.typedefs[ref.index].deprecated
		case .Var:
			name = ir.vars[ref.index].name
			kind = .Var
			deprecated = ir.vars[ref.index].deprecated
		case .Macro:
			name = ir.macros[ref.index].name
			kind = .Const
			deprecated = ir.macros[ref.index].deprecated
		case .Bit_Set:
			name = ir.bit_sets[ref.index].name
			kind = .Type
			// bit_set aliases inherit nothing; they are generator-authored.
			deprecated = false
		case .Wrapper:
			// Materialized after filter; should not appear during remove.
			name = ir.wrappers[ref.index].name
			kind = .Func
			deprecated = false
		}
		// Anonymous records are spelled inline where they are used and stand
		// or fall with their user. Anonymous enums, however, emit as free
		// constants (NAME :: value); a C-deprecated one is a top-level
		// constant for remove.deprecated.
		if name == "" {
			if ref.kind == .Enum && deprecated && policy.remove_deprecated {
				continue
			}
			// where can also drop them when the predicate reads sym.deprecated
			// (name is empty; kind is type; deprecated is true).
			if ref.kind == .Enum && deprecated && policy.has_remove_where {
				if should_remove_symbol(policy, name, kind, deprecated) {
					continue
				}
			}
			append(&kept, ref)
			continue
		}
		if !should_remove_symbol(policy, name, kind, deprecated) {
			append(&kept, ref)
		}
	}
	ir.order = kept
}

should_remove_symbol :: proc(policy: ^Policy, name: string, kind: Symbol_Kind, deprecated: bool) -> bool {
	for n in policy.remove_names {
		if n == name {
			return true
		}
	}
	for pattern in policy.remove_patterns {
		matched, err := slashpath.match(pattern, name)
		if err == nil && matched {
			return true
		}
	}
	// Fourth declarative tier: drop every C-deprecated symbol.
	if policy.remove_deprecated && deprecated {
		return true
	}
	if policy.has_remove_where {
		return policy_remove_where(policy, Symbol_Context{name = name, default_name = name, kind = kind, deprecated = deprecated})
	}
	return false
}

// Decide the Odin-visible name of every named symbol.
//
// Pipeline: naming.overrides → (strip affixes + keyword_safe as default) →
// naming.override callback. Functions/variables keep the C symbol via
// link_name when the Odin name changes.
//
// Case conversion is NOT applied automatically. Odin's foreign guidance is to
// keep the original authors' case so C and Odin call sites stay parallel
// (odin-lang.org/docs/overview/#foreign-system — vendor note). Users who want
// Ada/snake recasing use h2o.naming.ada_case / snake_case in an override, or
// set naming.overrides. known_tokens feeds those helpers when the generator
// builds sym.default with optional case (see default_odin_name).
