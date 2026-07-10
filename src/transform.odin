package h2odin

// Which spelling family Transformation aims for.
//
// File layout (see docs/source-layout.md): transform.odin is the pass order;
// transform_*.odin hold individual passes.

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
