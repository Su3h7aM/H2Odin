package h2odin

import "core:strings"

apply_renames :: proc(ir: ^IR, policy: ^Policy) {
	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			decl := &ir.funcs[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Func, "", decl.deprecated); decided {
				decl.link_name = link_name_for(policy, decl.name, new_name)
				decl.name = new_name
			}
			rename_params(ir, policy, decl.name, decl.params)
		case .Var:
			decl := &ir.vars[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Var, "", decl.deprecated); decided {
				decl.link_name = link_name_for(policy, decl.name, new_name)
				decl.name = new_name
			}
		case .Record:
			decl := &ir.records[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, "", decl.deprecated); decided {
				decl.name = new_name
			}
			for &field in decl.fields {
				if new_name, decided := rename_of(ir, policy, field.name, .Field, decl.name, false); decided {
					field.name = new_name
				}
			}
		case .Enum:
			decl := &ir.enums[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, "", decl.deprecated); decided {
				decl.name = new_name
			}
			for &member in decl.members {
				if new_name, decided := rename_of(ir, policy, member.name, .Enum_Member, decl.name, false); decided {
					member.name = new_name
				}
			}
		case .Typedef:
			decl := &ir.typedefs[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, "", decl.deprecated); decided {
				decl.name = new_name
			}
		case .Macro:
			decl := &ir.macros[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Const, "", decl.deprecated); decided {
				decl.name = new_name
			}
		case .Bit_Set:
			decl := &ir.bit_sets[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, "", false); decided {
				decl.name = new_name
			}
		}
	}

	// Function-pointer types carry parameter names of their own.
	for &info in ir.types {
		if variant, is_proc := &info.variant.(Type_Proc); is_proc {
			rename_params(ir, policy, "", variant.params)
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
rename_of :: proc(ir: ^IR, policy: ^Policy, name: string, kind: Symbol_Kind, parent: string, deprecated := false) -> (string, bool) {
	if name == "" {
		return "", false
	}

	// Absolute map wins before automatic naming.
	if odin_name, ok := policy.naming_overrides[name]; ok {
		new_name := keyword_safe_default(odin_name)
		if new_name == name {
			return "", false
		}
		return new_name, true
	}

	default_name := default_odin_name(ir, policy, name, kind)

	new_name, decided := policy_rename(policy, Symbol_Context{name = name, default_name = default_name, kind = kind, parent = parent, deprecated = deprecated})
	if !decided {
		new_name = default_name
	}
	new_name = keyword_safe_default(new_name)
	if new_name == name {
		return "", false
	}
	return new_name, true
}

// Generator default for a symbol: strip configured affixes, then keyword
// safety. Spelling case is left as in the header (foreign porting convention).
// If known_tokens is set and the stripped form still has an ambiguous split,
// emit naming_ambiguity so the user can override that one symbol.
default_odin_name :: proc(ir: ^IR, policy: ^Policy, name: string, kind: Symbol_Kind) -> string {
	stripped := strip_configured_affixes(policy, name, kind)
	if len(policy.known_tokens) > 0 {
		// Touch the tokenizer so known_tokens collisions surface even when
		// we do not recase — the dictionary is still load-bearing for
		// callbacks that call h2o.naming.* on sym.default / related names.
		_, ambiguous := naming_tokenize(stripped, policy.known_tokens, context.temp_allocator)
		if ambiguous {
			ir_diag(ir, .Naming_Ambiguity, "%q has an uncertain word split; set naming.overrides or refine known_tokens", name)
		}
	}
	return keyword_safe_default(stripped)
}

// Strip the first matching configured prefix, then the first matching
// suffix, for this symbol kind.
strip_configured_affixes :: proc(policy: ^Policy, name: string, kind: Symbol_Kind) -> string {
	prefixes: []string
	suffixes: []string
	#partial switch kind {
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
	result := name
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

// Parameters go through the same naming pipeline as fields: affix strip,
// the override callback (kind = "param"), and keyword safety. Previously
// they got keyword safety only, which left C-case params like `Cursor` to
// shadow a recased type `Cursor` (libclang names many params after their
// type). Passing the owning proc name as parent matches the field contract
// and lets config target a specific proc's params if needed.
rename_params :: proc(ir: ^IR, policy: ^Policy, proc_name: string, params: []Param) {
	for &param in params {
		if param.name == "" {
			continue
		}
		if new_name, decided := rename_of(ir, policy, param.name, .Param, proc_name); decided {
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

// Replace each leaf C type with its fixed-width Odin spelling when that is
// provably safe: either core:c defines the name as the same Odin type on
// every target, or the size libclang measured during extraction equals the
// Odin type's size. Anything unproven keeps its ABI spelling — correctness
// over convenience, never a guess.
// Idiomatic mode's default is a native Odin spelling; the ABI spelling
// (core:c) is the fallback of last resort, used only when the target
// genuinely gives us too little to choose a native type. Every leaf in the
// type pool is resolved through a three-rung ladder:
//
//  1. Table preference — the type table names a semantic spelling for this
//     C type (size_t -> uint). Used once the size libclang measured on the
//     target confirms it; that confirmation is a honesty check, not a real
//     expectation of failure.
//  2. Derived from measurement — no table preference applies. Size and
//     signedness, as libclang measured them, are a complete determination
//     for any integer leaf, so a fixed-width native spelling (i16, u32,
//     ...) is derived directly, never guessed.
//  3. Fallback — the size is unknown, or the type has no scalar shape to
//     derive from (e.g. void). The ABI spelling is kept, and this rung is
//     diagnosed since it should be rare in practice.
