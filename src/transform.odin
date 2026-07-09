package h2odin

import "core:fmt"
import "core:path/slashpath"
import "core:strings"

// Which spelling family Transformation aims for.
Type_Mode :: enum {
	ABI, // faithful core:c spellings; always correct
	Idiomatic, // fixed-width Odin spellings where proven safe on the target
}

// Transformation is where decisions are made. It reads the analyzed IR
// together with the configuration policy and records the choices — renames,
// drops, and type picks. It is the only stage that consults policy.
//
// Pass order follows docs/config-spec.md (macro grouping and enum policies
// synthesize ordinary IR decls before naming and emission).
transform :: proc(ir: ^IR, mode: Type_Mode, policy: ^Policy) {
	for _, i in ir.types {
		lower_type(ir, Type_Handle(i))
	}
	report_pointer_lowering_guesses(ir)

	if mode == .Idiomatic {
		substitute_leaf_types(ir)
	}

	apply_macro_groups(ir, policy)
	apply_enum_policies(ir, policy)

	// map first, then overrides so a types.overrides entry wins on conflict.
	apply_type_rewrites(ir, policy.type_map, drop_decls = false)
	apply_type_rewrites(ir, policy.type_overrides, drop_decls = true)

	// Signature/layout spellings before naming so map keys still use C names.
	apply_struct_adjustments(ir, policy)
	apply_proc_adjustments(ir, policy)

	filter_declarations(ir, policy)
	apply_renames(ir, policy)
}

// structs.fields → structs.field → structs.align. Keys and align names are
// C names (this pass runs before naming).
apply_struct_adjustments :: proc(ir: ^IR, policy: ^Policy) {
	has_fields := policy.struct_fields != nil && len(policy.struct_fields) > 0
	has_align := policy.struct_align != nil && len(policy.struct_align) > 0
	if !has_fields && !policy.has_struct_field && !has_align {
		return
	}
	for &record in ir.records {
		if record.name == "" {
			continue
		}
		if has_align {
			if n, ok := policy.struct_align[record.name]; ok {
				record.align = n
			}
		}
		if !has_fields && !policy.has_struct_field {
			continue
		}
		for &field in record.fields {
			if field.name == "" {
				continue
			}
			key := fmt.tprintf("%s.%s", record.name, field.name)
			if has_fields {
				if action, ok := policy.struct_fields[key]; ok {
					apply_member_action_to_field(&field, action)
				}
			}
			if policy.has_struct_field {
				view_type := type_name_for_view(ir, field.type)
				if action, decided := policy_struct_field_action(policy, record.name, field.name, view_type); decided {
					apply_member_action_to_field(&field, action)
				}
			}
		}
	}
}

apply_member_action_to_field :: proc(field: ^Field, action: Member_Action) {
	if action.type != "" {
		field.type_spelling = action.type
	}
	if action.tag != "" {
		field.tag = action.tag
	}
}

// procs.params → procs.param; procs.results → procs.result.
apply_proc_adjustments :: proc(ir: ^IR, policy: ^Policy) {
	has_params := policy.proc_params != nil && len(policy.proc_params) > 0
	has_results := policy.proc_results != nil && len(policy.proc_results) > 0
	if !has_params && !has_results && !policy.has_proc_param && !policy.has_proc_result {
		return
	}
	for &fn in ir.funcs {
		if has_params || policy.has_proc_param {
			for &param in fn.params {
				key_name := param.name if param.name != "" else "_"
				key := fmt.tprintf("%s.%s", fn.name, key_name)
				if has_params {
					if action, ok := policy.proc_params[key]; ok {
						apply_member_action_to_param(&param, action)
					}
				}
				if policy.has_proc_param {
					view_type := type_name_for_view(ir, param.type)
					if action, decided := policy_proc_param_action(policy, fn.name, param.name, view_type); decided {
						apply_member_action_to_param(&param, action)
					}
				}
			}
		}
		if has_results {
			if action, ok := policy.proc_results[fn.name]; ok {
				if action.type != "" {
					fn.return_type_spelling = action.type
				}
			}
		}
		if policy.has_proc_result {
			view_type := type_name_for_view(ir, fn.return_type)
			if action, decided := policy_proc_result_action(policy, fn.name, view_type); decided {
				if action.type != "" {
					fn.return_type_spelling = action.type
				}
			}
		}
	}
}

apply_member_action_to_param :: proc(param: ^Param, action: Member_Action) {
	if action.type != "" {
		param.type_spelling = action.type
	}
	if action.default != "" {
		param.default = action.default
	}
}

// Best-effort type name for callback views — named refs only; complex types
// report empty so configs match on parent/child names instead.
type_name_for_view :: proc(ir: ^IR, handle: Type_Handle) -> string {
	info := ir_type(ir, handle)
	#partial switch variant in info.variant {
	case Type_Record_Ref:
		return ir.records[variant.decl].name
	case Type_Enum_Ref:
		return ir.enums[variant.decl].name
	case Type_Typedef_Ref:
		return ir.typedefs[variant.decl].name
	case Type_Std:
		return variant.name
	case Type_Idiomatic_Leaf:
		return variant.spelling
	case Type_Lowered_Pointer:
		return type_name_for_view(ir, variant.pointee)
	case Type_Pointer:
		return type_name_for_view(ir, variant.pointee)
	}
	return ""
}

// A config type spelling names an explicit Odin form for a C type by name —
// stronger than an idiomatic proof, since the user asked for it directly —
// so it applies in both type modes and can override an idiomatic
// substitution already made. Anything not named is untouched.
//
// types.map rewrites references only. types.overrides also drops the named
// record/enum/typedef from the ordering list: the user supplied its Odin
// spelling directly, so emitting the generator's own declaration would be
// redundant (and for "typedef struct { … } Name;" would emit the name twice).
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
apply_renames :: proc(ir: ^IR, policy: ^Policy) {
	for ref in ir.order {
		switch ref.kind {
		case .Invalid:
		case .Func:
			decl := &ir.funcs[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Func, ""); decided {
				decl.link_name = link_name_for(policy, decl.name, new_name)
				decl.name = new_name
			}
			fix_param_names(decl.params)
		case .Var:
			decl := &ir.vars[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Var, ""); decided {
				decl.link_name = link_name_for(policy, decl.name, new_name)
				decl.name = new_name
			}
		case .Record:
			decl := &ir.records[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
			for &field in decl.fields {
				if new_name, decided := rename_of(ir, policy, field.name, .Field, decl.name); decided {
					field.name = new_name
				}
			}
		case .Enum:
			decl := &ir.enums[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
			for &member in decl.members {
				if new_name, decided := rename_of(ir, policy, member.name, .Enum_Member, decl.name); decided {
					member.name = new_name
				}
			}
		case .Typedef:
			decl := &ir.typedefs[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
		case .Macro:
			decl := &ir.macros[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Const, ""); decided {
				decl.name = new_name
			}
		case .Bit_Set:
			decl := &ir.bit_sets[ref.index]
			if new_name, decided := rename_of(ir, policy, decl.name, .Type, ""); decided {
				decl.name = new_name
			}
		}
	}

	// Function-pointer types carry parameter names of their own.
	for &info in ir.types {
		if variant, is_proc := &info.variant.(Type_Proc); is_proc {
			fix_param_names(variant.params)
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
rename_of :: proc(ir: ^IR, policy: ^Policy, name: string, kind: Symbol_Kind, parent: string) -> (string, bool) {
	if name == "" {
		return "", false
	}

	// Absolute map wins before automatic naming.
	if odin_name, ok := policy.naming_overrides[name]; ok {
		if odin_name == name {
			return "", false
		}
		return odin_name, true
	}

	default_name := default_odin_name(ir, policy, name, kind)

	new_name, decided := policy_rename(policy, Symbol_Context{name = name, default_name = default_name, kind = kind, parent = parent})
	if !decided {
		new_name = default_name
	}
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
	case .Func:
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

// ---------------------------------------------------------------- Macros

// Synthesize explicit-valued enums from macros.groups. Consumed macros are
// dropped from the ordering list when emit_original_consts is false.
//
// Per-macro check order (config-spec): prefix → exclude_prefixes →
// value-kind (integer) → include last.
apply_macro_groups :: proc(ir: ^IR, policy: ^Policy) {
	if len(policy.macro_groups) == 0 {
		return
	}

	drop_macros := make(map[u32]bool, context.temp_allocator)
	claimed := make(map[u32]bool, context.temp_allocator)

	for group in policy.macro_groups {
		members := make([dynamic]Enum_Member, context.temp_allocator)
		for macro, mi in ir.macros {
			if macro.is_function_like {
				continue
			}
			if group.prefix != "" && !strings.has_prefix(macro.name, group.prefix) {
				continue
			}
			excluded := false
			for excl in group.exclude_prefixes {
				if excl != "" && strings.has_prefix(macro.name, excl) {
					excluded = true
					break
				}
			}
			if excluded {
				continue
			}
			value, is_int := macro_integer_value(macro)
			if !is_int {
				continue
			}
			if group.has_include && !policy_macro_include(policy, group, macro) {
				continue
			}
			if claimed[u32(mi)] {
				label := group.id if group.id != "" else group.name
				ir_diag_with_local(
					ir,
					group.diag_overrides,
					.Macro_Group_Conflict,
					"%q already claimed by an earlier group; skipping for %q",
					macro.name,
					label,
				)
				continue
			}
			claimed[u32(mi)] = true

			member_name := macro.name
			if group.member_strip_prefix != "" {
				member_name = str_strip_prefix(member_name, group.member_strip_prefix)
			}
			append(&members, Enum_Member{name = strings.clone(member_name), value = value})
			if !group.emit_original_consts {
				drop_macros[u32(mi)] = true
			}
		}
		if len(members) == 0 {
			label := group.id if group.id != "" else group.name
			ir_diag_with_local(ir, group.diag_overrides, .Macro_Group_Empty, "macro group %q matched no macros", label)
			continue
		}
		arena_members := make([]Enum_Member, len(members))
		for m, i in members {
			arena_members[i] = m
		}
		_ = ir_add_enum(ir, Enum_Decl{name = strings.clone(group.name), backing = ir_builtin_type(ir, .Int), members = arena_members})
	}

	if len(drop_macros) == 0 {
		return
	}
	kept := make([dynamic]Decl_Ref, 0, len(ir.order))
	for ref in ir.order {
		if ref.kind == .Macro && drop_macros[ref.index] {
			continue
		}
		append(&kept, ref)
	}
	ir.order = kept
}

// ---------------------------------------------------------------- Enums

apply_enum_policies :: proc(ir: ^IR, policy: ^Policy) {
	apply_enum_anonymous(ir, policy)
	apply_enum_member_policy(ir, policy)
	apply_enum_bit_sets(ir, policy)
}

apply_enum_anonymous :: proc(ir: ^IR, policy: ^Policy) {
	for rule in policy.enum_anonymous {
		for &decl in ir.enums {
			if decl.name != "" || decl.members == nil || len(decl.members) == 0 {
				continue
			}
			if decl.members[0].name == rule.first_member {
				decl.name = strings.clone(rule.name)
				break
			}
		}
	}
}

apply_enum_member_policy :: proc(ir: ^IR, policy: ^Policy) {
	if !policy.has_enum_member {
		return
	}
	for &decl in ir.enums {
		if decl.members == nil {
			continue
		}
		kept := make([dynamic]Enum_Member, 0, len(decl.members))
		enum_name := decl.name // may be "" for anonymous
		for member in decl.members {
			if policy_enum_member_remove(policy, enum_name, member.name, member.value) {
				continue
			}
			append(&kept, member)
		}
		if len(kept) != len(decl.members) {
			decl.members = kept[:]
		}
	}
}

apply_enum_bit_sets :: proc(ir: ^IR, policy: ^Policy) {
	for rule in policy.enum_bit_sets {
		enum_index := -1
		for decl, i in ir.enums {
			if decl.name == rule.enum_name {
				enum_index = i
				break
			}
		}
		if enum_index < 0 {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q not found", rule.enum_name)
			continue
		}
		decl := &ir.enums[enum_index]
		if decl.members == nil {
			ir_diag_with_local(ir, rule.diag_overrides, .Bit_Set_Target_Missing, "enums.bit_sets: enum %q has no members", rule.enum_name)
			continue
		}
		ok := true
		for &member in decl.members {
			if member.value <= 0 || !is_power_of_two_u64(u64(member.value)) {
				ir_diag_with_local(
					ir,
					rule.diag_overrides,
					.Bit_Set_Non_Power_Of_Two,
					"%s.%s = %d is not a power of two; skipping bit_set %q",
					rule.enum_name,
					member.name,
					member.value,
					rule.name,
				)
				ok = false
				break
			}
		}
		if !ok {
			continue
		}
		// Rewrite member values to bit positions (log2).
		for &member in decl.members {
			member.value = i64(log2_u64(u64(member.value)))
		}
		// Type handle for the enum (reuse an existing Type_Enum_Ref if any,
		// otherwise add one).
		enum_type := ir_add_type(ir, Type_Info{variant = Type_Enum_Ref{decl = Decl_Handle(enum_index)}})
		ir_add_bit_set(ir, Bit_Set_Decl{name = strings.clone(rule.name), elem = enum_type})
	}
}

is_power_of_two_u64 :: proc(v: u64) -> bool {
	return v != 0 && (v & (v - 1)) == 0
}

log2_u64 :: proc(v: u64) -> u64 {
	// v is a power of two ≥ 1.
	n: u64 = 0
	x := v
	for x > 1 {
		x >>= 1
		n += 1
	}
	return n
}

// Parameter names are not symbols — the policy is never consulted — but a
// name that collides with an Odin keyword still cannot be emitted verbatim.
// Case is left as in the header (same foreign-porting convention as symbols).
fix_param_names :: proc(params: []Param) {
	for &param in params {
		param.name = keyword_safe_default(param.name)
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
		if (variant.kind == .Char_Signed || variant.kind == .Char_Unsigned) && pointee_info.is_const {
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
		case .Invalid, .Macro, .Bit_Set:
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
