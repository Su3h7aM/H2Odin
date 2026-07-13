package h2odin

// Which spelling family Transformation aims for.
// This file defines pass order; transform_*.odin files hold the passes.

Type_Mode :: enum {
	ABI, // faithful core:c spellings; always correct
	Idiomatic, // fixed-width Odin spellings where proven safe on the target
}

// Transformation is where decisions are made. It reads the analyzed IR
// together with the configuration policy and records the choices — renames,
// drops, and type picks. It is the only stage that consults policy.
//
// Macro grouping and enum policies run first because they synthesize ordinary
// IR declarations that must participate in naming and validation.
transform :: proc(ir: ^IR, type_mode: Type_Mode, policy: ^Policy) {
	for _, type_index in ir.types {
		lower_type(ir, Type_Handle(type_index))
	}

	if type_mode == .Idiomatic {
		substitute_leaf_types(ir)
	}

	apply_macro_groups(ir, policy)
	apply_enum_policies(ir, policy)

	// Resolve both opaque C idioms before map/overrides so an explicit user
	// spelling can still win.
	apply_opaque_types(ir, policy, type_mode)

	// Foreign (non-input) types: built-in POSIX/libc map, then
	// incomplete stubs for pointer refs and a diagnostic for by-value use.
	// After the opaque passes so drop lists settle; before the rewrites below
	// because config must win — the pass skips any name config already names.
	apply_foreign_type_stubs(ir, policy)

	// map first, then overrides so a types.overrides entry wins on conflict.
	apply_type_rewrites(ir, policy.type_map, drop_decls = false)
	apply_type_rewrites(ir, policy.type_overrides, drop_decls = true)

	// Signature/layout spellings before naming so map keys still use C names.
	apply_struct_adjustments(ir, policy)
	apply_proc_adjustments(ir, policy, type_mode)

	filter_declarations(ir, policy)

	// Wrapper plans key on C names; resolve before renames, materialize after
	// so public wrapper names and param result names are final Odin spellings.
	wrapper_plans := resolve_wrapper_plans(ir, policy, type_mode)
	apply_renames(ir, policy)
	materialize_wrapper_plans(ir, wrapper_plans)

	// Detect package/member collisions and field/param type
	// shadowing after every rename is final. Reports only — never renames.
	validate_symbol_names(ir)
}
