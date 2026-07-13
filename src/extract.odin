package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import clang "vendored:libclang"

// Extraction is the only stage that talks to libclang. It walks the parsed
// header and copies what the header contains into the IR — faithfully,
// completely, and deciding nothing. Every libclang-owned string is copied
// into the generation arena at this boundary, so nothing downstream depends
// on libclang's lifetime; the library could be shut down the moment this
// stage returns.
// The orchestration lives here; declaration and type capture are split into
// extract_decls.odin and extract_types.odin.

Extract_State :: struct {
	caller_context:   runtime.Context,
	ir:               ^IR,
	translation_unit: clang.Translation_Unit,

	// USR → already-created declaration, so every mention of a tagged type
	// resolves to one IR decl. Anonymous declarations have no USR and are
	// never shared, so they skip the map. Funcs/vars/macros also register
	// here so a sibling input included from another input is not emitted
	// twice when both appear as config.inputs.
	decl_map:         map[string]Decl_Ref,

	// Absolute, cleaned paths of every header in config.inputs → home handle.
	// A declaration is "ours" when its source file is in this map — not merely
	// when it is the current TU's main file. That keeps typedef names declared
	// in a sibling input (clang-c/CXString.h used from Index.h) instead of
	// peeling them to the underlying type at use sites.
	input_files:      map[string]Input_Header_Handle,
}

// Preprocess knobs passed into libclang as -I / -D. Paths and define values
// are already resolved by the caller (config-dir relative paths expanded).
Extract_Preprocess :: struct {
	include_paths:    []string,
	defines:          map[string]string, // NAME → value; empty value → -DNAME
	// Explicit builtin-header resource directory (`-resource-dir=`). Empty:
	// query the `clang` driver on PATH (or the executable named by
	// `clang_executable` when set).
	resource_dir:     string,
	// Optional path/name of the clang driver used only for
	// `-print-resource-dir` when `resource_dir` is empty. Default: "clang".
	clang_executable: string,
}

// Where the selected resource directory came from (for -verbose provenance).
Resource_Dir_Source :: enum u8 {
	None, // no resource dir available
	Override, // preprocess.resource_dir / CLI -resource-dir:
	Clang_Driver, // `clang -print-resource-dir` (or configured executable)
}

// Linked libclang + resource-dir selection for a run. Filled by extract;
// printed under -verbose so users can verify that the selected builtin headers
// match the loaded libclang.
Clang_Provenance :: struct {
	libclang_version:    string, // arena-copied clang_getClangVersion()
	resource_dir:        string, // selected path, or ""
	resource_dir_source: Resource_Dir_Source,
}

// Extract every header into one IR. Shared decl_map dedupes by USR across
// translation units so multi-header inputs do not re-declare the same type.
// When `provenance` is non-nil, it is filled with the linked libclang version
// and the resource directory chosen for this run.
extract :: proc(header_paths: []string, ir: ^IR, preprocess: Extract_Preprocess = {}, provenance: ^Clang_Provenance = nil) -> bool {
	if len(header_paths) == 0 {
		user_error("h2odin: no input headers")
		return false
	}
	clang_index := clang.create_index(0, 0) // diagnostics are printed by check_parse_diagnostics
	if clang_index == nil {
		user_error("h2odin: failed to create the libclang index")
		return false
	}
	defer clang.dispose_index(clang_index)

	state := Extract_State {
		caller_context = context,
		ir             = ir,
		decl_map       = make(map[string]Decl_Ref, context.temp_allocator),
		input_files    = ir_register_input_headers(ir, header_paths, context.temp_allocator),
	}

	resource_dir, resource_source := resolve_clang_resource_dir(preprocess.resource_dir, preprocess.clang_executable)
	if provenance != nil {
		provenance^ = Clang_Provenance {
			libclang_version    = clone_clang_string(clang.get_clang_version()),
			resource_dir        = strings.clone(resource_dir) if resource_dir != "" else "",
			resource_dir_source = resource_source,
		}
	}
	clang_arguments := build_clang_arguments(preprocess, resource_dir)

	for header_path in header_paths {
		extract_header(clang_index, &state, header_path, clang_arguments[:]) or_return
	}
	return true
}

// Build the libclang arguments shared by every input translation unit.
// The returned array and formatted strings use the temporary allocator and
// remain valid for this Extraction call.
build_clang_arguments :: proc(preprocess: Extract_Preprocess, resource_dir: string) -> [dynamic]cstring {
	arguments := make([dynamic]cstring, context.temp_allocator)
	append(&arguments, "-fparse-all-comments")
	if resource_dir != "" {
		append(&arguments, fmt.ctprintf("-resource-dir=%s", resource_dir))
	}
	for include_path in preprocess.include_paths {
		append(&arguments, fmt.ctprintf("-I%s", include_path))
	}
	for name, value in preprocess.defines {
		if value == "" {
			append(&arguments, fmt.ctprintf("-D%s", name))
		} else {
			append(&arguments, fmt.ctprintf("-D%s=%s", name, value))
		}
	}
	return arguments
}

// Parse and visit one input while keeping the foreign translation-unit handle
// scoped to this procedure. No libclang handle survives Extraction.
extract_header :: proc(clang_index: clang.Index, state: ^Extract_State, header_path: string, clang_arguments: []cstring) -> bool {
	header_cstring := strings.clone_to_cstring(header_path, context.temp_allocator)
	translation_unit := clang.parse_translation_unit(
		clang_index,
		header_cstring,
		raw_data(clang_arguments),
		c.int(len(clang_arguments)),
		nil,
		0,
		{.Detailed_Preprocessing_Record},
	)
	if translation_unit == nil {
		user_errorf("h2odin: failed to parse %q", header_path)
		return false
	}
	defer clang.dispose_translation_unit(translation_unit)

	check_parse_diagnostics(translation_unit, header_path) or_return

	state.translation_unit = translation_unit
	defer state.translation_unit = nil
	clang.visit_children(clang.get_translation_unit_cursor(translation_unit), visit_top_level, clang.Client_Data(rawptr(state)))
	return true
}

// Absolute + cleaned form used as the input-set key. Falls back to a cleaned
// relative path when abs is unavailable so matching still works in tests that
// open headers by a stable relative spelling.
normalize_source_path :: proc(path: string, allocator := context.allocator) -> string {
	if path == "" {
		return ""
	}
	if absolute_path, path_error := filepath.abs(path, allocator); path_error == nil {
		if cleaned_path, clean_error := filepath.clean(absolute_path, allocator); clean_error == nil {
			return cleaned_path
		}
		return absolute_path
	}
	if cleaned_path, clean_error := filepath.clean(path, allocator); clean_error == nil {
		return cleaned_path
	}
	return path
}

// True when the source location sits in a file listed in config.inputs.
location_is_ours :: proc(state: ^Extract_State, location: clang.Source_Location) -> bool {
	return location_home(state, location) != 0
}

// Input-header handle for a source location, or 0 when not a configured input.
location_home :: proc(state: ^Extract_State, location: clang.Source_Location) -> Input_Header_Handle {
	path := location_source_path(location, context.temp_allocator)
	if path == "" {
		return 0
	}
	home, found := state.input_files[path]
	if !found {
		return 0
	}
	return home
}

// Home for a cursor's primary source location.
cursor_home :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Input_Header_Handle {
	return location_home(state, clang.get_cursor_location(cursor))
}

// Is this declaration the system's rather than the library's? clang knows: a
// header reached through the system search path (<sys/socket.h>, <time.h>) is
// flagged, while the library's own headers — including the ones an umbrella
// input pulls in via -I but config.inputs never lists — are not.
//
// This is the ownership fact, and it is not the same question as `home`. Home
// answers "which configured input places this declaration in the output", so
// a project header reached transitively has no home yet is still ours to emit.
// Foreignness answers "is this someone else's declaration", which is what
// decides whether H2Odin may claim its layout.
cursor_is_foreign :: proc(cursor: clang.Cursor) -> bool {
	return clang.location_is_in_system_header(clang.get_cursor_location(cursor)) != 0
}

// Path clang reports for a source location, normalized like input_files keys.
location_source_path :: proc(location: clang.Source_Location, allocator := context.allocator) -> string {
	file: clang.File
	clang.get_file_location(location, &file, nil, nil, nil)
	if file == nil {
		return ""
	}
	// Prefer the real path so an include found via -I matches the absolute
	// path we stored for that same header in config.inputs.
	if real := clone_clang_string_with(clang.file_try_get_real_path_name(file), allocator); real != "" {
		return normalize_source_path(real, allocator)
	}
	name := clone_clang_string_with(clang.get_file_name(file), allocator)
	return normalize_source_path(name, allocator)
}

// Like clone_clang_string but into an explicit allocator (temp for probes).
clone_clang_string_with :: proc(clang_string: clang.String, allocator := context.allocator) -> string {
	defer clang.dispose_string(clang_string)
	c_string := clang.get_c_string(clang_string)
	if c_string == nil {
		return ""
	}
	return strings.clone_from_cstring(c_string, allocator)
}

// Print every parse diagnostic; refuse to continue past errors. Clang
// error-recovers from a bad parse (a missing stddef.h turns size_t into
// int), so an AST with errors in it describes an ABI the header does not
// have — no output at all beats silently wrong output.
check_parse_diagnostics :: proc(translation_unit: clang.Translation_Unit, header_path: string) -> bool {
	parse_succeeded := true
	for diagnostic_index in 0 ..< clang.get_num_diagnostics(translation_unit) {
		diagnostic := clang.get_diagnostic(translation_unit, diagnostic_index)
		defer clang.dispose_diagnostic(diagnostic)

		severity := clang.get_diagnostic_severity(diagnostic)
		if severity == .Ignored {
			continue
		}
		user_error(clone_clang_string(clang.format_diagnostic(diagnostic, clang.default_diagnostic_display_options())))
		if severity >= .Error {
			parse_succeeded = false
		}
	}
	if !parse_succeeded {
		user_errorf("h2odin: %q did not parse cleanly; refusing to generate from a guessed AST", header_path)
	}
	return parse_succeeded
}

// Resolve the builtin-header resource directory. Prefer an explicit override
// (config/CLI); otherwise shell out to the clang driver. The linked libclang
// may still belong to a different LLVM — callers print both under -verbose.
resolve_clang_resource_dir :: proc(override_dir: string, clang_executable: string) -> (dir: string, source: Resource_Dir_Source) {
	if override_dir != "" {
		return override_dir, .Override
	}
	executable := clang_executable if clang_executable != "" else "clang"
	if resource_dir, ok := clang_print_resource_dir(executable); ok {
		return resource_dir, .Clang_Driver
	}
	return "", .None
}

// Ask a clang driver for its resource directory (`-print-resource-dir`).
// Result is temp-allocated. Empty/`ok=false` when the driver is missing or
// fails — the parse-diagnostics gate then reports whatever breaks.
clang_print_resource_dir :: proc(clang_executable: string) -> (dir: string, ok: bool) {
	process_state, standard_output, _, process_error := os.process_exec({command = {clang_executable, "-print-resource-dir"}}, context.temp_allocator)
	if process_error != nil || !process_state.exited || process_state.exit_code != 0 {
		return "", false
	}
	dir = strings.trim_space(string(standard_output))
	if dir == "" {
		return "", false
	}
	return dir, true
}

// Print linked libclang version and the chosen resource directory on stderr.
// Intended for -verbose so provenance mismatches are visible without changing
// generation.
report_clang_provenance :: proc(provenance: Clang_Provenance) {
	version := provenance.libclang_version if provenance.libclang_version != "" else "(unknown)"
	user_errorf("h2odin: libclang: %s", version)
	switch provenance.resource_dir_source {
	case .Override:
		user_errorf("h2odin: resource-dir: %s (override)", provenance.resource_dir)
	case .Clang_Driver:
		user_errorf("h2odin: resource-dir: %s (clang driver)", provenance.resource_dir)
	case .None:
		user_error("h2odin: resource-dir: (none; clang driver unavailable and no override)")
	}
}

visit_top_level :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	state := cast(^Extract_State)rawptr(client_data)
	context = state.caller_context

	// Bind declarations from any config.inputs header, not only the current
	// TU's main file. Sibling inputs included from another input (clang-c)
	// are still "ours"; system headers and unlisted includes are not.
	if !location_is_ours(state, clang.get_cursor_location(cursor)) {
		return .Continue
	}

	#partial switch clang.get_cursor_kind(cursor) {
	case .Function_Decl:
		extract_func(state, cursor)
	case .Struct_Decl, .Union_Decl:
		record_decl_for_cursor(state, cursor)
	case .Enum_Decl:
		enum_decl_for_cursor(state, cursor)
	case .Typedef_Decl:
		typedef_decl_for_cursor(state, cursor)
	case .Var_Decl:
		extract_var(state, cursor)
	case .Macro_Definition:
		extract_macro(state, cursor)
	}
	return .Continue
}

clone_clang_string :: proc(clang_string: clang.String) -> string {
	defer clang.dispose_string(clang_string)
	c_string := clang.get_c_string(clang_string)
	if c_string == nil {
		return ""
	}
	return strings.clone_from_cstring(c_string)
}

// A C parameter of array or function type is really a pointer — decay it
// explicitly at capture so the IR never lies about the ABI, whatever spelling
// the header used.
