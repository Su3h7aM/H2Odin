package h2odin

import "core:fmt"
import "core:strings"

// Diagnostics are the generator's honesty report: every heuristic and
// fallback that is not certain lands here with a *named category* and a
// *severity*. Config can raise or lower a category; the default posture for
// most categories is warn so runs still produce usable output.
//
// Levels (lowest → highest signal):
//   info    — stage progress / provenance (verbose-mode material)
//   hint    — pattern detected; configure to act (never changes output)
//   warning — suspicious; user should review
//   error   — generation failure for exit status (output may still exist)
//
// Visibility: quiet → errors only; default → hint+warning+error; verbose → all.

Diag_Severity :: enum u8 {
	Warn, // zero value — default posture for most categories
	Error,
	Info,
	Hint,
}

// Closed set of diagnostic categories. Lua keys use the snake_case name
// returned by diag_category_name. Reserved members may not fire yet; they
// exist so config can set severity before the emitter lands.
Diag_Category :: enum u8 {
	Pointer_Lowering_Guess,
	Unresolved_Idiomatic_Leaf,
	Opaque_Layout_Fallback,
	Bit_Field_Layout_Fallback,
	Naming_Ambiguity,
	Macro_Group_Conflict,
	Macro_Group_Empty,
	Bit_Set_Non_Power_Of_Two,
	Bit_Set_Target_Missing,
	Bit_Set_Backing_Mismatch,
	Incomplete_Extern_Array,
	// types.opaque named a complete record; fail closed.
	Opaque_Record_Complete,
	// Spec-listed; reserved for future emitters.
	Duplicate_Enum_Value,
	Unresolved_Type,
	Unsupported_Macro,
	Symbol_Collision,
	// C calling convention has no Odin spelling.
	Unsupported_Calling_Conv,
	// procs.wrappers plan rejected at generation time.
	Wrapper_Plan_Failed,
	// An unlisted project header is reachable from more than one root.
	Header_Ownership_Conflict,
}

Diagnostic :: struct {
	category:       Diag_Category,
	message:        string,
	// When set, a feature constructor's local diagnostics override beat the
	// global config.diagnostics table (resolved at report time still uses
	// this fixed value).
	local_severity: Maybe(Diag_Severity),
}

diag_category_name :: proc(c: Diag_Category) -> string {
	switch c {
	case .Pointer_Lowering_Guess:
		return "pointer_lowering_guess"
	case .Unresolved_Idiomatic_Leaf:
		return "unresolved_idiomatic_leaf"
	case .Opaque_Layout_Fallback:
		return "opaque_layout_fallback"
	case .Bit_Field_Layout_Fallback:
		return "bit_field_layout_fallback"
	case .Naming_Ambiguity:
		return "naming_ambiguity"
	case .Macro_Group_Conflict:
		return "macro_group_conflict"
	case .Macro_Group_Empty:
		return "macro_group_empty"
	case .Bit_Set_Non_Power_Of_Two:
		return "bit_set_non_power_of_two"
	case .Bit_Set_Target_Missing:
		return "bit_set_target_missing"
	case .Bit_Set_Backing_Mismatch:
		return "bit_set_backing_mismatch"
	case .Incomplete_Extern_Array:
		return "incomplete_extern_array"
	case .Opaque_Record_Complete:
		return "opaque_record_complete"
	case .Duplicate_Enum_Value:
		return "duplicate_enum_value"
	case .Unresolved_Type:
		return "unresolved_type"
	case .Unsupported_Macro:
		return "unsupported_macro"
	case .Symbol_Collision:
		return "symbol_collision"
	case .Unsupported_Calling_Conv:
		return "unsupported_calling_conv"
	case .Wrapper_Plan_Failed:
		return "wrapper_plan_failed"
	case .Header_Ownership_Conflict:
		return "header_ownership_conflict"
	}
	return "unknown"
}

diag_category_from_name :: proc(name: string) -> (Diag_Category, bool) {
	switch name {
	case "pointer_lowering_guess":
		return .Pointer_Lowering_Guess, true
	case "unresolved_idiomatic_leaf":
		return .Unresolved_Idiomatic_Leaf, true
	case "opaque_layout_fallback":
		return .Opaque_Layout_Fallback, true
	case "bit_field_layout_fallback":
		return .Bit_Field_Layout_Fallback, true
	case "naming_ambiguity":
		return .Naming_Ambiguity, true
	case "macro_group_conflict":
		return .Macro_Group_Conflict, true
	case "macro_group_empty":
		return .Macro_Group_Empty, true
	case "bit_set_non_power_of_two":
		return .Bit_Set_Non_Power_Of_Two, true
	case "bit_set_target_missing":
		return .Bit_Set_Target_Missing, true
	case "bit_set_backing_mismatch":
		return .Bit_Set_Backing_Mismatch, true
	case "incomplete_extern_array":
		return .Incomplete_Extern_Array, true
	case "opaque_record_complete":
		return .Opaque_Record_Complete, true
	case "duplicate_enum_value":
		return .Duplicate_Enum_Value, true
	case "unresolved_type":
		return .Unresolved_Type, true
	case "unsupported_macro":
		return .Unsupported_Macro, true
	case "symbol_collision":
		return .Symbol_Collision, true
	case "unsupported_calling_conv":
		return .Unsupported_Calling_Conv, true
	case "wrapper_plan_failed":
		return .Wrapper_Plan_Failed, true
	case "header_ownership_conflict":
		return .Header_Ownership_Conflict, true
	}
	return {}, false
}

diag_severity_name :: proc(s: Diag_Severity) -> string {
	switch s {
	case .Info:
		return "info"
	case .Hint:
		return "hint"
	case .Warn:
		return "warning"
	case .Error:
		return "error"
	}
	return "unknown"
}

diag_severity_from_name :: proc(name: string) -> (Diag_Severity, bool) {
	switch name {
	case "info":
		return .Info, true
	case "hint":
		return .Hint, true
	case "warn", "warning":
		return .Warn, true
	case "error":
		return .Error, true
	}
	return {}, false
}

// Resolve severity: local constructor override > policy.diagnostics > warn.
diag_resolve_severity :: proc(d: Diagnostic, policy: ^Policy) -> Diag_Severity {
	if sev, ok := d.local_severity.?; ok {
		return sev
	}
	if policy != nil {
		return policy.diag_severity[d.category]
	}
	return .Warn
}

// Whether a resolved severity is printed for this run's quiet/verbose flags.
// quiet → errors only; default → hint+warning+error; verbose → everything.
diag_severity_visible :: proc(sev: Diag_Severity, quiet: bool, verbose: bool) -> bool {
	switch sev {
	case .Error:
		return true
	case .Warn, .Hint:
		return !quiet
	case .Info:
		return verbose && !quiet
	}
	return false
}

// Local override map on a constructor (bit_set, macro group, …). Only
// categories present in the Lua diagnostics table are Some.
Diag_Local_Overrides :: struct {
	set: [Diag_Category]Maybe(Diag_Severity),
}

diag_local_severity :: proc(local: Diag_Local_Overrides, category: Diag_Category) -> Maybe(Diag_Severity) {
	return local.set[category]
}

// Record a diagnostic with no local severity override (resolved from
// policy at report time; default warn).
ir_diag :: proc(ir: ^IR, category: Diag_Category, format: string, args: ..any) {
	append(&ir.diagnostics, Diagnostic{category = category, message = fmt.aprintf(format, ..args)})
}

// Record a diagnostic with a severity fixed by a feature constructor's
// local diagnostics table.
ir_diag_local :: proc(ir: ^IR, category: Diag_Category, severity: Diag_Severity, format: string, args: ..any) {
	append(&ir.diagnostics, Diagnostic{category = category, message = fmt.aprintf(format, ..args), local_severity = severity})
}

// Emit using local overrides when present for this category, else global.
ir_diag_with_local :: proc(ir: ^IR, local: Diag_Local_Overrides, category: Diag_Category, format: string, args: ..any) {
	if sev, ok := local.set[category].?; ok {
		ir_diag_local(ir, category, sev, format, ..args)
		return
	}
	ir_diag(ir, category, format, ..args)
}

// Default report is summary-first: one block per (severity, category) with a
// count and a single explanation. Individual site messages are listed only
// for one-off diagnostics, for errors (capped), or under -verbose.
//
// Visibility: quiet → errors only; default → hint+warning+error;
// verbose → all levels, every site, and cause/fix guidance.
// Exit status is tied only to error severity (including escalations).

// Errors expand sites by default — they fail the run and need locations.
DIAG_DEFAULT_ERROR_EXPAND_MAX :: 5

// Print the end-of-run report on stderr.
report_diagnostics :: proc(ir: ^IR, policy: ^Policy, quiet := false, verbose := false) -> bool {
	n := len(ir.diagnostics)
	if n == 0 {
		return true
	}

	severities := make([]Diag_Severity, n, context.temp_allocator)
	n_info, n_hint, n_warn, n_err := 0, 0, 0, 0
	n_visible := 0
	for d, i in ir.diagnostics {
		sev := diag_resolve_severity(d, policy)
		severities[i] = sev
		switch sev {
		case .Info:
			n_info += 1
		case .Hint:
			n_hint += 1
		case .Warn:
			n_warn += 1
		case .Error:
			n_err += 1
		}
		if diag_severity_visible(sev, quiet, verbose) {
			n_visible += 1
		}
	}

	if n_visible > 0 {
		report_diagnostics_header(n_info, n_hint, n_warn, n_err, quiet, verbose)

		collapsed_any := false
		severity_order := [?]Diag_Severity{.Error, .Warn, .Hint, .Info}
		for sev in severity_order {
			if !diag_severity_visible(sev, quiet, verbose) {
				continue
			}
			for cat in Diag_Category {
				if report_diagnostics_group(ir, severities, sev, cat, verbose) {
					collapsed_any = true
				}
			}
		}
		if collapsed_any && !verbose {
			user_error("  (use -verbose to list every site)")
		}
	}

	return n_err == 0
}

// One clean summary line: "h2odin: 194 warnings" or "h2odin: 2 errors, 3 warnings".
report_diagnostics_header :: proc(n_info, n_hint, n_warn, n_err: int, quiet: bool, verbose: bool) {
	parts: [4]string
	part_count := 0
	// Most urgent first in the header.
	if n_err > 0 {
		parts[part_count] = fmt.tprintf("%d error%s", n_err, "" if n_err == 1 else "s")
		part_count += 1
	}
	if !quiet && n_warn > 0 {
		parts[part_count] = fmt.tprintf("%d warning%s", n_warn, "" if n_warn == 1 else "s")
		part_count += 1
	}
	if !quiet && n_hint > 0 {
		parts[part_count] = fmt.tprintf("%d hint%s", n_hint, "" if n_hint == 1 else "s")
		part_count += 1
	}
	if verbose && !quiet && n_info > 0 {
		parts[part_count] = fmt.tprintf("%d info", n_info)
		part_count += 1
	}

	if part_count == 0 {
		return
	}
	summary: string
	switch part_count {
	case 1:
		summary = parts[0]
	case 2:
		summary = fmt.tprintf("%s, %s", parts[0], parts[1])
	case 3:
		summary = fmt.tprintf("%s, %s, %s", parts[0], parts[1], parts[2])
	case 4:
		summary = fmt.tprintf("%s, %s, %s, %s", parts[0], parts[1], parts[2], parts[3])
	}
	user_errorf("h2odin: %s", summary)
}

// Print one (severity, category) group. Returns true when site details were
// collapsed (so the caller can print a single -verbose tip).
report_diagnostics_group :: proc(ir: ^IR, severities: []Diag_Severity, sev: Diag_Severity, cat: Diag_Category, verbose: bool) -> (collapsed: bool) {
	indices: [dynamic]int
	indices.allocator = context.temp_allocator
	for d, i in ir.diagnostics {
		if severities[i] == sev && d.category == cat {
			append(&indices, i)
		}
	}
	count := len(indices)
	if count == 0 {
		return false
	}

	sev_name := diag_severity_name(sev)
	cat_name := diag_category_name(cat)

	// One-off: keep a single readable line (message already carries the site).
	if count == 1 {
		user_errorf("  %s[%s]: %s", sev_name, cat_name, ir.diagnostics[indices[0]].message)
		if verbose {
			report_diagnostics_guidance(cat)
		}
		return false
	}

	// Multi: title with count, then either sites or one shared explanation.
	user_errorf("  %s[%s]  ×%d", sev_name, cat_name, count)
	expand_limit := diag_group_expand_limit(sev, count, verbose)

	if expand_limit > 0 {
		limit := min(count, expand_limit)
		for j in 0 ..< limit {
			user_errorf("    %s", ir.diagnostics[indices[j]].message)
		}
		if limit < count {
			user_errorf("    … and %d more", count - limit)
			collapsed = true
		}
		if verbose {
			report_diagnostics_guidance(cat)
		}
		return collapsed
	}

	// Summary mode: one explanation for the whole group, not N near-copies.
	cause, fix := diag_verbose_guidance(cat)
	if cause != "" {
		user_errorf("    %s", cause)
	} else {
		// Reserved categories without guidance: one sample site.
		user_errorf("    %s", ir.diagnostics[indices[0]].message)
		user_errorf("    … and %d more", count - 1)
	}
	if fix != "" {
		user_errorf("    fix: %s", fix)
	}
	return true
}

// How many site messages to print for a multi-member group.
// 0 means summary-only (shared cause/fix, no per-site lines).
// count == 1 is handled by the caller before this is used.
diag_group_expand_limit :: proc(sev: Diag_Severity, count: int, verbose: bool) -> int {
	if verbose {
		return count
	}
	if sev == .Error {
		// Failures need locations; cap so a flood still stays scannable.
		return min(count, DIAG_DEFAULT_ERROR_EXPAND_MAX)
	}
	// Warn/hint multi-groups: one shared explanation, never N near-copies.
	return 0
}

report_diagnostics_guidance :: proc(cat: Diag_Category) {
	cause, fix := diag_verbose_guidance(cat)
	if cause != "" {
		user_errorf("    cause: %s", cause)
	}
	if fix != "" {
		user_errorf("    fix:   %s", fix)
	}
}

// Probable cause and Lua-config resolution for a category. Empty strings
// mean "no extra guidance" (reserved / rare categories).
diag_verbose_guidance :: proc(c: Diag_Category) -> (cause: string, fix: string) {
	switch c {
	case .Pointer_Lowering_Guess:
		return "C does not distinguish single pointers, arrays, and out-params; defaulted to ^T.",
			"Set procs.params / structs.fields { pointer = \"multi\" } or an explicit type spelling (callbacks: procs.param / structs.field)."
	case .Unresolved_Idiomatic_Leaf:
		return "Idiomatic mode could not prove a native Odin leaf type for this C type on the current target.",
			"Keep type_mode = \"abi\", or map the C type via types.map / types.overrides to an explicit Odin spelling."
	case .Opaque_Layout_Fallback:
		return "The record layout could not be proven safe to emit field-by-field (incomplete or unrepresentable).",
			"Emit as an opaque handle with types.opaque[\"Name\"] = true (idiomatic default for incomplete tags), or leave faithful empty/opaque struct emission."
	case .Bit_Field_Layout_Fallback:
		return "libclang's target layout for this bit-field run could not be proven (size, alignment, or offsets).",
			"Accept the opaque-record fallback, or reshape the C type so bit-fields form a contiguous, measured run."
	case .Naming_Ambiguity:
		return "The identifier tokenizer could not split this C name into words with certainty.",
			"Add a naming.known_tokens entry for the domain vocabulary, or set naming.overrides[\"CName\"] = \"Odin_Name\"."
	case .Macro_Group_Conflict:
		return "A macro matched more than one macros.groups rule (or conflicted with another claimed name).",
			"Tighten include/exclude filters on h2o.macro_group.enum { … } so each macro is claimed by exactly one group."
	case .Macro_Group_Empty:
		return "A macros.groups entry matched no macros after filters.",
			"Check the group's prefix/include/exclude against the header, or remove the empty group."
	case .Bit_Set_Non_Power_Of_Two:
		return "enums.bit_sets mode \"log2\" requires every member value to be a power of two; at least one is not.",
			"Exclude non-power-of-two members (masks like _ALL / _NONE) via the bit_set rule filters, or drop the bit_set transform for this enum."
	case .Bit_Set_Target_Missing:
		return "enums.bit_sets named an enum that is missing or has no members after transforms.",
			"Fix the enum_name to match a C enum still present after symbols.remove / enums.member filtering."
	case .Bit_Set_Backing_Mismatch:
		return "A flag value does not fit the measured C enum integer width used as the bit_set backing type.",
			"Exclude oversized flags, or do not convert this enum to a bit_set."
	case .Incomplete_Extern_Array:
		return "An extern array has no known size in the header; emitted as [0]T.",
			"Override the variable type when the bound is known, or patch the binding after generation."
	case .Opaque_Record_Complete:
		return "types.opaque forced handle style on a complete (sized) record; collapsing it would change layout, so emission stayed faithful.",
			"Remove the types.opaque entry for that name, or set types.opaque[\"Name\"] = false if you only meant incomplete tags."
	case .Duplicate_Enum_Value:
		return "Two enum members share the same numeric value after transforms.",
			"Drop one via enums.member, or rename via naming.overrides if both must remain as distinct Odin names."
	case .Unresolved_Type:
		return "A type reference could not be resolved to a known IR type.",
			"Ensure the defining header is listed in config.inputs / preprocess.include_paths, or map the name with types.map."
	case .Unsupported_Macro:
		return "This macro form is not emitted as an Odin constant or group member.",
			"Ignore it, group related integer macros with macros.groups, or handle it outside the generator."
	case .Symbol_Collision:
		return "After renaming, two symbols share an Odin name, or a field/parameter name shadows a type used in the same declaration.",
			"Disambiguate with naming.overrides / naming.override (kind-aware for fields and params), adjust strip_prefixes, or symbols.remove."
	case .Unsupported_Calling_Conv:
		return "libclang reported a calling convention that Odin cannot spell on a foreign procedure or procedure type.",
			"This is not config-overridable: the C ABI cannot be represented faithfully. Drop the declaration (symbols.remove) or bind it by hand outside the generator."
	case .Wrapper_Plan_Failed:
		return "procs.wrappers named a conversion that cannot be applied from the header/IR facts.",
			"Fix out_params/slices names and types, or remove the wrapper entry. Validations run at generation time — not in the emitted body."
	case .Header_Ownership_Conflict:
		return "An unlisted project header was reached from multiple configured roots without another root between them.",
			"List the shared header in config.inputs to give it its own unit, reorder inputs to select the first owner, or set diagnostics.header_ownership_conflict = \"error\"."
	}
	return "", ""
}


// Format known category names for error messages (comma-separated).
diag_known_category_list :: proc(allocator := context.temp_allocator) -> string {
	b: strings.Builder
	strings.builder_init(&b, allocator)
	first := true
	for c in Diag_Category {
		if !first {
			strings.write_string(&b, ", ")
		}
		first = false
		strings.write_string(&b, diag_category_name(c))
	}
	return strings.to_string(b)
}
