package h2odin

import "core:fmt"
import "core:strings"

// Diagnostics are the generator's honesty report: every heuristic and
// fallback that is not certain lands here with a *named category* and a
// *severity*. Config can raise a category to error; the default posture is
// warn so runs still produce usable output (see docs/config-spec.md).

Diag_Severity :: enum u8 {
	Warn, // zero value — default posture
	Error,
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
	// types.opaque named a complete record (spec 0007); fail closed.
	Opaque_Record_Complete,
	// Spec-listed; reserved for future emitters.
	Duplicate_Enum_Value,
	Unresolved_Type,
	Unsupported_Macro,
	Symbol_Collision,
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
	}
	return {}, false
}

diag_severity_name :: proc(s: Diag_Severity) -> string {
	switch s {
	case .Warn:
		return "warning"
	case .Error:
		return "error"
	}
	return "unknown"
}

diag_severity_from_name :: proc(name: string) -> (Diag_Severity, bool) {
	switch name {
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

// Print the end-of-run report on stderr. Quiet when empty or when `quiet` is
// set (process-level -quiet still fails the run on error severities).
// Returns false when any diagnostic resolved to error (caller should exit
// non-zero after still having emitted output).
report_diagnostics :: proc(ir: ^IR, policy: ^Policy, quiet := false) -> bool {
	n := len(ir.diagnostics)
	if n == 0 {
		return true
	}

	n_warn := 0
	n_err := 0
	severities := make([]Diag_Severity, n, context.temp_allocator)
	for d, i in ir.diagnostics {
		sev := diag_resolve_severity(d, policy)
		severities[i] = sev
		if sev == .Error {
			n_err += 1
		} else {
			n_warn += 1
		}
	}

	if !quiet {
		// Header: keep "non-certain" for the all-warn case so existing e2e
		// strings still match; mention errors when present.
		if n_err == 0 {
			label := "decision" if n == 1 else "decisions"
			fmt.eprintfln("h2odin: %d non-certain %s:", n, label)
		} else {
			fmt.eprintfln(
				"h2odin: %d diagnostic%s (%d warning%s, %d error%s):",
				n,
				"" if n == 1 else "s",
				n_warn,
				"" if n_warn == 1 else "s",
				n_err,
				"" if n_err == 1 else "s",
			)
		}

		for d, i in ir.diagnostics {
			sev := severities[i]
			fmt.eprintfln("  - %s[%s]: %s", diag_severity_name(sev), diag_category_name(d.category), d.message)
		}
	}

	return n_err == 0
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
