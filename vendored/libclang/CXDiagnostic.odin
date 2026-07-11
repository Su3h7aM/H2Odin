package clang

foreign import lib "system:clang"

Diagnostic_Severity :: enum u32 {
	Ignored,
	Note,
	Warning,
	Error,
	Fatal,
}

Diagnostic :: rawptr

Diagnostic_Set :: rawptr

Load_Diag_Error :: enum u32 {
	None,
	Unknown,
	Cannot_Load,
	Invalid_File,
}

Diagnostic_Display_Options :: enum u32 {
	Display_Source_Location = 1,
	Display_Column,
	Display_Source_Ranges = 4,
	Display_Option = 8,
	Display_Category_Id = 16,
	Display_Category_Name = 32,
}

foreign lib {
	@(link_name = "clang_getNumDiagnosticsInSet")
	get_num_diagnostics_in_set :: proc(diags: Diagnostic_Set) -> u32 ---
	@(link_name = "clang_getDiagnosticInSet")
	get_diagnostic_in_set :: proc(diags: Diagnostic_Set, index: u32) -> Diagnostic ---
	@(link_name = "clang_loadDiagnostics")
	load_diagnostics :: proc(file: cstring, error: ^Load_Diag_Error, error_string: ^String) -> Diagnostic_Set ---
	@(link_name = "clang_disposeDiagnosticSet")
	dispose_diagnostic_set :: proc(diags: Diagnostic_Set) ---
	@(link_name = "clang_getChildDiagnostics")
	get_child_diagnostics :: proc(d: Diagnostic) -> Diagnostic_Set ---
	@(link_name = "clang_disposeDiagnostic")
	dispose_diagnostic :: proc(diagnostic: Diagnostic) ---
	@(link_name = "clang_formatDiagnostic")
	format_diagnostic :: proc(diagnostic: Diagnostic, options: u32) -> String ---
	@(link_name = "clang_defaultDiagnosticDisplayOptions")
	default_diagnostic_display_options :: proc() -> u32 ---
	@(link_name = "clang_getDiagnosticSeverity")
	get_diagnostic_severity :: proc(_: Diagnostic) -> Diagnostic_Severity ---
	@(link_name = "clang_getDiagnosticLocation")
	get_diagnostic_location :: proc(_: Diagnostic) -> Source_Location ---
	@(link_name = "clang_getDiagnosticSpelling")
	get_diagnostic_spelling :: proc(_: Diagnostic) -> String ---
	@(link_name = "clang_getDiagnosticOption")
	get_diagnostic_option :: proc(diag: Diagnostic, disable: ^String) -> String ---
	@(link_name = "clang_getDiagnosticCategory")
	get_diagnostic_category :: proc(_: Diagnostic) -> u32 ---
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_getDiagnosticCategoryName")
	get_diagnostic_category_name :: proc(category: u32) -> String ---
	@(link_name = "clang_getDiagnosticCategoryText")
	get_diagnostic_category_text :: proc(_: Diagnostic) -> String ---
	@(link_name = "clang_getDiagnosticNumRanges")
	get_diagnostic_num_ranges :: proc(_: Diagnostic) -> u32 ---
	@(link_name = "clang_getDiagnosticRange")
	get_diagnostic_range :: proc(diagnostic: Diagnostic, range: u32) -> Source_Range ---
	@(link_name = "clang_getDiagnosticNumFixIts")
	get_diagnostic_num_fix_its :: proc(diagnostic: Diagnostic) -> u32 ---
	@(link_name = "clang_getDiagnosticFixIt")
	get_diagnostic_fix_it :: proc(diagnostic: Diagnostic, fix_it: u32, replacement_range: ^Source_Range) -> String ---
}
