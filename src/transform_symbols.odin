package h2odin

import "core:path/slashpath"

apply_type_rewrites :: proc(ir: ^IR, type_spelling: map[string]string, drop_decls: bool) {
	if type_spelling == nil {
		return
	}
	count := len(ir.types) // don't revisit slots appended below
	for i in 0 ..< count {
		info := ir.types[i]
		name: string
		#partial switch variant in info.variant {
		case Type_Record_Ref:
			name = ir.records[variant.decl].name
		case Type_Enum_Ref:
			name = ir.enums[variant.decl].name
		case Type_Typedef_Ref:
			name = ir.typedefs[variant.decl].name
		case Type_Std:
			name = variant.name
		case:
			continue
		}
		spelling, mapped := type_spelling[name]
		if !mapped {
			continue
		}
		original := ir_add_type(ir, info)
		ir.types[i] = Type_Info {
			is_const = info.is_const,
			variant = Type_Idiomatic_Leaf{original = original, spelling = spelling, reason = .Config_Override},
		}
	}

	if !drop_decls {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		name: string
		#partial switch ref.kind {
		case .Record:
			name = ir.records[ref.index].name
		case .Enum:
			name = ir.enums[ref.index].name
		case .Typedef:
			name = ir.typedefs[ref.index].name
		}
		if _, mapped := type_spelling[name]; name != "" && mapped {
			continue
		}
		append(&kept, ref)
	}
	ir.order = kept
}

// symbols.remove: names → patterns → where. Rebuild the ordering list with
// survivors. Dropping is an ordering-list operation only — pool entries stay
// so handles remain valid. Members and fields are never offered here.
filter_declarations :: proc(ir: ^IR, policy: ^Policy) {
	has_names := len(policy.remove_names) > 0
	has_patterns := len(policy.remove_patterns) > 0
	if !has_names && !has_patterns && !policy.has_remove_where {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		name: string
		kind: Symbol_Kind
		switch ref.kind {
		case .Invalid:
			continue
		case .Func:
			name = ir.funcs[ref.index].name
			kind = .Func
		case .Record:
			name = ir.records[ref.index].name
			kind = .Type
		case .Enum:
			name = ir.enums[ref.index].name
			kind = .Type
		case .Typedef:
			name = ir.typedefs[ref.index].name
			kind = .Type
		case .Var:
			name = ir.vars[ref.index].name
			kind = .Var
		case .Macro:
			name = ir.macros[ref.index].name
			kind = .Const
		case .Bit_Set:
			name = ir.bit_sets[ref.index].name
			kind = .Type
		}
		// Anonymous declarations are spelled inline where they are used;
		// they stand or fall with their user, not on their own.
		if name == "" || !should_remove_symbol(policy, name, kind) {
			append(&kept, ref)
		}
	}
	ir.order = kept
}

should_remove_symbol :: proc(policy: ^Policy, name: string, kind: Symbol_Kind) -> bool {
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
	if policy.has_remove_where {
		return policy_remove_where(policy, Symbol_Context{name = name, default_name = name, kind = kind})
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
