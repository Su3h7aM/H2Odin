package h2odin

import "core:fmt"

// Which spelling family Transformation aims for.
Type_Mode :: enum {
	ABI, // faithful core:c spellings; always correct
	Idiomatic, // fixed-width Odin spellings where proven safe on the target
}

// Transformation is where decisions are made. It reads the analyzed IR
// together with the configuration policy and records the choices — renames,
// drops, type picks, conversions. It is the only stage that consults policy.
//
transform :: proc(ir: ^IR, mode: Type_Mode, policy: ^Policy) {
	for _, i in ir.types {
		lower_type(ir, Type_Handle(i))
	}
	report_pointer_lowering_guesses(ir)

	if mode == .Idiomatic {
		substitute_leaf_types(ir)
	}

	filter_declarations(ir, policy)
	apply_renames(ir, policy)
}

// Offer every top-level declaration to the config's keep callback and
// rebuild the ordering list with the survivors. Dropping is an ordering-list
// operation only — the declaration stays in its pool, so handles held by
// other types remain valid. Members and fields are never offered: dropping
// one would change a layout or an enum the header defines.
filter_declarations :: proc(ir: ^IR, policy: ^Policy) {
	if !policy.has_keep {
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
		}
		// Anonymous declarations are spelled inline where they are used;
		// they stand or fall with their user, not on their own.
		if name == "" || policy_keep(policy, Symbol_Context{name = name, default_name = name, kind = kind}) {
			append(&kept, ref)
		}
	}
	ir.order = kept
}

// Offer every named symbol to the config's rename callback. Functions and
// variables that change name keep their C symbol via link_name; type names,
// enum members, constants, and fields are not linkage-visible and just take
// the new name.
apply_renames :: proc(ir: ^IR, policy: ^Policy) {
	if !policy.has_rename {
		return
	}
	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			decl := &ir.funcs[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Func, ""); decided {
				decl.link_name = decl.name
				decl.name = new_name
			}
		case .Var:
			decl := &ir.vars[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Var, ""); decided {
				decl.link_name = decl.name
				decl.name = new_name
			}
		case .Record:
			decl := &ir.records[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
			for &field in decl.fields {
				if new_name, decided := rename_of(policy, field.name, .Field, decl.name); decided {
					field.name = new_name
				}
			}
		case .Enum:
			decl := &ir.enums[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
			for &member in decl.members {
				if new_name, decided := rename_of(policy, member.name, .Enum_Member, decl.name); decided {
					member.name = new_name
				}
			}
		case .Typedef:
			decl := &ir.typedefs[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
		case .Macro:
			decl := &ir.macros[ref.index]
			if new_name, decided := rename_of(policy, decl.name, .Const, ""); decided {
				decl.name = new_name
			}
		}
	}
}

// Anonymous symbols have nothing to rename; everything else goes to the
// policy with the generator's default (currently the original name — the
// keyword-safe and prefix-stripped defaults land on top of this).
rename_of :: proc(policy: ^Policy, name: string, kind: Symbol_Kind, parent: string) -> (string, bool) {
	if name == "" {
		return "", false
	}
	new_name, decided := policy_rename(policy, Symbol_Context{name = name, default_name = name, kind = kind, parent = parent})
	if !decided || new_name == name {
		return "", false
	}
	return new_name, true
}

// Replace each leaf C type with its fixed-width Odin spelling when that is
// provably safe: either core:c defines the name as the same Odin type on
// every target, or the size libclang measured during extraction equals the
// Odin type's size. Anything unproven keeps its ABI spelling — correctness
// over convenience, never a guess.
substitute_leaf_types :: proc(ir: ^IR) {
	count := len(ir.types) // slots appended below carry no leaves to revisit
	for i in 0 ..< count {
		info := ir.types[i]
		spelling: string
		independent: bool
		measured: int
		#partial switch variant in info.variant {
		case Type_Builtin:
			row := builtin_spellings[variant.kind]
			spelling = row.idiomatic
			independent = row.target_independent
			measured = variant.size
		case Type_Std:
			row, known := std_mapping_for(variant.name)
			if !known {
				continue
			}
			spelling = row.idiomatic
			independent = row.target_independent
			measured = variant.size
		case:
			continue
		}
		if spelling == "" {
			// No idiomatic form decided for this type.
			continue
		}

		reason: Idiomatic_Reason
		switch {
		case independent:
			reason = .Target_Independent
		case measured >= 0 && measured == odin_type_size(spelling):
			reason = .Size_Proven
		case:
			// Unknown or mismatched size on this target: unproven, keep the
			// ABI spelling.
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
		if variant.kind == .Char && pointee_info.is_const {
			return Type_Lowered_Pointer{pointee = pointee, kind = .CString, confidence = .Proven, reason = .Const_Char_Pointer}
		}
	case Type_Proc:
		return Type_Lowered_Pointer{pointee = pointee, kind = .Proc, confidence = .Proven, reason = .Function_Pointer}
	}

	return Type_Lowered_Pointer{pointee = pointee, kind = .Single, confidence = .Guessed, reason = .Single_Pointer_Default}
}

report_pointer_lowering_guesses :: proc(ir: ^IR) {
	for ref in ir.order {
		switch ref.kind {
		case .Invalid, .Macro:
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
			fmt.eprintfln("h2odin: guessed pointer lowering in %s: defaulted to ^T", site)
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
