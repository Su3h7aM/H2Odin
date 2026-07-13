package h2odin

import "core:strings"

apply_renames :: proc(ir: ^IR, policy: ^Policy) {
	for declaration in ir.order {
		switch declaration.kind {
		case .Invalid:
		case .Func:
			function := &ir.funcs[declaration.index]
			function_c_name := function.name
			if new_name, decided := rename_of(ir, policy, function_c_name, .Func, "", function.deprecated); decided {
				function.link_name = link_name_for(policy, function_c_name, new_name)
				function.name = new_name
			}
			rename_params(ir, policy, function_c_name, function.params)
		case .Var:
			variable := &ir.vars[declaration.index]
			if new_name, decided := rename_of(ir, policy, variable.name, .Var, "", variable.deprecated); decided {
				variable.link_name = link_name_for(policy, variable.name, new_name)
				variable.name = new_name
			}
		case .Record:
			record := &ir.records[declaration.index]
			record_c_name := record.name
			if new_name, decided := rename_of(ir, policy, record_c_name, .Type, "", record.deprecated); decided {
				record.name = new_name
			}
			for &field in record.fields {
				if new_name, decided := rename_of(ir, policy, field.name, .Field, record_c_name); decided {
					field.name = new_name
				}
			}
		case .Enum:
			enum_declaration := &ir.enums[declaration.index]
			enum_c_name := enum_declaration.name
			if new_name, decided := rename_of(ir, policy, enum_c_name, .Type, "", enum_declaration.deprecated); decided {
				enum_declaration.name = new_name
			}
			for &member in enum_declaration.members {
				if new_name, decided := rename_of(ir, policy, member.name, .Enum_Member, enum_c_name); decided {
					member.name = new_name
				}
			}
		case .Typedef:
			typedef := &ir.typedefs[declaration.index]
			if new_name, decided := rename_of(ir, policy, typedef.name, .Type, "", typedef.deprecated); decided {
				typedef.name = new_name
			}
		case .Macro:
			macro := &ir.macros[declaration.index]
			if new_name, decided := rename_of(ir, policy, macro.name, .Const, "", macro.deprecated); decided {
				macro.name = new_name
			}
		case .Bit_Set:
			bit_set_declaration := &ir.bit_sets[declaration.index]
			if new_name, decided := rename_of(ir, policy, bit_set_declaration.name, .Type, ""); decided {
				bit_set_declaration.name = new_name
			}
		case .Wrapper:
		// Wrappers are materialized after renames with final public names.
		}
	}

	// Function-pointer types carry parameter names of their own.
	for &type_info in ir.types {
		if procedure_type, is_procedure := &type_info.variant.(Type_Proc); is_procedure {
			rename_params(ir, policy, "", procedure_type.params)
		}
	}
}

// When foreign.link_prefix is set and C name == prefix + Odin name, the
// foreign block's link_prefix already builds the symbol — no per-decl
// @(link_name) needed. Otherwise keep the original C name as link_name.
link_name_for :: proc(policy: ^Policy, c_name: string, odin_name: string) -> string {
	prefix := policy.foreign_link_prefix
	if prefix != "" && len(c_name) == len(prefix) + len(odin_name) && strings.has_prefix(c_name, prefix) && c_name[len(prefix):] == odin_name {
		return ""
	}
	return c_name
}

// Anonymous symbols have nothing to rename; everything else goes through
// the naming pipeline. Returns decided=false when the final name equals
// the original C name (no IR write needed).
//
// Keyword safety is a generator invariant — emitting an Odin keyword as an
// identifier is invalid syntax, never a naming preference — so it gates the
// final name whichever path produced it: the absolute map, the override
// callback, or the generator default. default_odin_name already escapes on
// the default path; re-running here is idempotent and covers the other two.
rename_of :: proc(ir: ^IR, policy: ^Policy, c_name: string, symbol_kind: Symbol_Kind, parent_c_name: string, deprecated := false) -> (string, bool) {
	if c_name == "" {
		return "", false
	}

	// Absolute map wins before automatic naming.
	if odin_name, ok := policy.naming_overrides[c_name]; ok {
		new_name := keyword_safe_default(odin_name)
		if new_name == c_name {
			return "", false
		}
		if new_name == odin_name {
			new_name = strings.clone(new_name)
		}
		return new_name, true
	}

	default_name := default_odin_name(ir, policy, c_name, symbol_kind)

	new_name, decided := policy_rename(
		policy,
		Symbol_Context{name = c_name, default_name = default_name, kind = symbol_kind, parent = parent_c_name, deprecated = deprecated},
	)
	if !decided {
		new_name = default_name
	}
	new_name = keyword_safe_default(new_name)
	if new_name == c_name {
		return "", false
	}
	return new_name, true
}

// Generator default for a symbol: strip configured affixes, then keyword
// safety. Spelling case is left as in the header (foreign porting convention).
// If known_tokens is set and the stripped form still has an ambiguous split,
// emit naming_ambiguity so the user can override that one symbol.
default_odin_name :: proc(ir: ^IR, policy: ^Policy, c_name: string, symbol_kind: Symbol_Kind) -> string {
	stripped := strip_configured_affixes(policy, c_name, symbol_kind)
	if len(policy.known_tokens) > 0 {
		// Touch the tokenizer so known_tokens collisions surface even when
		// we do not recase — the dictionary is still load-bearing for
		// callbacks that call h2o.naming.* on sym.default / related names.
		_, ambiguous := naming_tokenize(stripped, policy.known_tokens, context.temp_allocator)
		if ambiguous {
			ir_diag(ir, .Naming_Ambiguity, "%q has an uncertain word split; set naming.overrides or refine known_tokens", c_name)
		}
	}
	return keyword_safe_default(stripped)
}

// Strip the first matching configured prefix, then the first matching
// suffix, for this symbol kind.
strip_configured_affixes :: proc(policy: ^Policy, c_name: string, symbol_kind: Symbol_Kind) -> string {
	prefixes: []string
	suffixes: []string
	#partial switch symbol_kind {
	case .Func, .Param:
		prefixes = policy.strip_prefix_proc
		suffixes = policy.strip_suffix_proc
	case .Type:
		prefixes = policy.strip_prefix_type
		suffixes = policy.strip_suffix_type
	case .Const:
		prefixes = policy.strip_prefix_const
		suffixes = policy.strip_suffix_const
	case .Enum_Member:
		prefixes = policy.strip_prefix_enum
		suffixes = policy.strip_suffix_enum
	}
	result := c_name
	for prefix in prefixes {
		if stripped := str_strip_prefix(result, prefix); stripped != result {
			result = stripped
			break
		}
	}
	for suffix in suffixes {
		if stripped := str_strip_suffix(result, suffix); stripped != result {
			result = stripped
			break
		}
	}
	return result
}

// Parameters go through the same naming pipeline as fields. The owning
// procedure's C name remains the stable callback parent even when that
// procedure has already received its Odin name.
rename_params :: proc(ir: ^IR, policy: ^Policy, parent_c_name: string, params: []Param) {
	for &param in params {
		if param.name == "" {
			continue
		}
		if new_name, decided := rename_of(ir, policy, param.name, .Param, parent_c_name); decided {
			param.name = new_name
		}
	}
}

// A C name that collides with an Odin keyword gets a deterministic default:
// one trailing underscore. Deterministic so reruns and configs can rely on
// it; the rename callback sees it as the default and may override.
keyword_safe_default :: proc(name: string) -> string {
	if !is_odin_keyword(name) {
		return name
	}
	return strings.concatenate({name, "_"})
}

// Legal non-keyword Odin identifier: [A-Za-z_][A-Za-z0-9_]*.
is_odin_identifier :: proc(name: string) -> bool {
	if name == "" || is_odin_keyword(name) {
		return false
	}
	if !is_ascii_alpha(name[0]) && name[0] != '_' {
		return false
	}
	for i in 1 ..< len(name) {
		c := name[i]
		if !is_ascii_alpha(c) && !is_ascii_digit(c) && c != '_' {
			return false
		}
	}
	return true
}

// Default package name from a header stem (e.g. "my-library.h" → "my_library").
// Hyphens and other non-identifier characters become underscores; leading
// digits get a leading underscore; empty collapses later to "bindings";
// keyword collisions get a trailing underscore.
sanitize_package_stem :: proc(stem: string) -> string {
	if stem == "" {
		return ""
	}
	b := make([dynamic]u8, 0, len(stem) + 1, context.temp_allocator)
	for i in 0 ..< len(stem) {
		c := stem[i]
		if is_ascii_alpha(c) || is_ascii_digit(c) || c == '_' {
			append(&b, c)
		} else {
			// my-library, lib.foo → underscores rather than dropping
			if len(b) == 0 || b[len(b) - 1] != '_' {
				append(&b, '_')
			}
		}
	}
	// Trim trailing underscores from consecutive junk at the end.
	for len(b) > 0 && b[len(b) - 1] == '_' {
		pop(&b)
	}
	if len(b) == 0 {
		return ""
	}
	// Identifiers cannot start with a digit.
	if is_ascii_digit(b[0]) {
		inject_at(&b, 0, '_')
	}
	name := string(b[:])
	if is_odin_keyword(name) {
		return strings.concatenate({name, "_"}, context.temp_allocator)
	}
	return name
}

// foreign.import_lib content (after "system:"). Empty and control/quote
// characters would make invalid or surprising Odin; reject them.
is_safe_foreign_lib :: proc(name: string) -> bool {
	if name == "" {
		return false
	}
	for i in 0 ..< len(name) {
		c := name[i]
		if c < 0x20 || c == 0x7f || c == '"' || c == '\\' {
			return false
		}
	}
	return true
}

is_odin_keyword :: proc(name: string) -> bool {
	switch name {
	case "asm",
	     "auto_cast",
	     "bit_field",
	     "bit_set",
	     "break",
	     "case",
	     "cast",
	     "context",
	     "continue",
	     "defer",
	     "distinct",
	     "do",
	     "dynamic",
	     "else",
	     "enum",
	     "fallthrough",
	     "for",
	     "foreign",
	     "if",
	     "import",
	     "in",
	     "map",
	     "matrix",
	     "not_in",
	     "or_break",
	     "or_continue",
	     "or_else",
	     "or_return",
	     "package",
	     "proc",
	     "return",
	     "struct",
	     "switch",
	     "transmute",
	     "typeid",
	     "union",
	     "using",
	     "when",
	     "where":
		return true
	}
	return false
}
