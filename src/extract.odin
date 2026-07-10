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
//
// File layout (see docs/source-layout.md): extract.odin is TU orchestration;
// extract_decls.odin holds per-declaration extraction; extract_types.odin
// holds capture_type and friends.

Extract_State :: struct {
	ctx:         runtime.Context,
	ir:          ^IR,
	tu:          clang.Translation_Unit,

	// USR → already-created declaration, so every mention of a tagged type
	// resolves to one IR decl. Anonymous declarations have no USR and are
	// never shared, so they skip the map. Funcs/vars/macros also register
	// here so a sibling input included from another input is not emitted
	// twice when both appear as config.inputs.
	decl_map:    map[string]Decl_Ref,

	// Absolute, cleaned paths of every header in config.inputs → home handle.
	// A declaration is "ours" when its source file is in this map — not merely
	// when it is the current TU's main file. That keeps typedef names declared
	// in a sibling input (clang-c/CXString.h used from Index.h) instead of
	// peeling them to the underlying type at use sites.
	input_files: map[string]Input_Header_Handle,
}

// Preprocess knobs passed into libclang as -I / -D. Paths and define values
// are already resolved by the caller (config-dir relative paths expanded).
Extract_Preprocess :: struct {
	include_paths: []string,
	defines:       map[string]string, // NAME → value; empty value → -DNAME
}

// Extract every header into one IR. Shared decl_map dedupes by USR across
// translation units so multi-header inputs do not re-declare the same type.
extract :: proc(header_paths: []string, ir: ^IR, preprocess: Extract_Preprocess = {}) -> bool {
	if len(header_paths) == 0 {
		fmt.eprintln("h2odin: no input headers")
		return false
	}
	index := clang.create_index(0, 0) // diagnostics are printed by check_parse_diagnostics
	defer clang.dispose_index(index)

	state := Extract_State {
		ctx         = context,
		ir          = ir,
		decl_map    = make(map[string]Decl_Ref),
		input_files = ir_register_input_headers(ir, header_paths),
	}

	// Build the shared clang args once: comments, resource dir, -I, -D.
	base_args := make([dynamic]cstring, context.temp_allocator)
	append(&base_args, "-fparse-all-comments")
	if resource_arg, found := clang_resource_dir_arg(); found {
		append(&base_args, resource_arg)
	}
	for path in preprocess.include_paths {
		append(&base_args, strings.clone_to_cstring(fmt.tprintf("-I%s", path), context.temp_allocator))
	}
	if preprocess.defines != nil {
		for name, value in preprocess.defines {
			if value == "" {
				append(&base_args, strings.clone_to_cstring(fmt.tprintf("-D%s", name), context.temp_allocator))
			} else {
				append(&base_args, strings.clone_to_cstring(fmt.tprintf("-D%s=%s", name, value), context.temp_allocator))
			}
		}
	}

	for header_path in header_paths {
		path := strings.clone_to_cstring(header_path, context.temp_allocator)
		tu := clang.parse_translation_unit(index, path, raw_data(base_args[:]), c.int(len(base_args)), nil, 0, {.Detailed_Preprocessing_Record})
		if tu == nil {
			fmt.eprintfln("h2odin: failed to parse %q", header_path)
			return false
		}
		if !check_parse_diagnostics(tu, header_path) {
			clang.dispose_translation_unit(tu)
			return false
		}
		state.tu = tu
		clang.visit_children(clang.get_translation_unit_cursor(tu), visit_top_level, clang.Client_Data(rawptr(&state)))
		clang.dispose_translation_unit(tu)
	}
	return true
}

// Absolute + cleaned form used as the input-set key. Falls back to a cleaned
// relative path when abs is unavailable so matching still works in tests that
// open headers by a stable relative spelling.
normalize_source_path :: proc(path: string, allocator := context.allocator) -> string {
	if path == "" {
		return ""
	}
	if abs, err := filepath.abs(path, allocator); err == nil {
		if cleaned, cerr := filepath.clean(abs, allocator); cerr == nil {
			return cleaned
		}
		return abs
	}
	if cleaned, err := filepath.clean(path, allocator); err == nil {
		return cleaned
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
clone_clang_string_with :: proc(s: clang.String, allocator := context.allocator) -> string {
	defer clang.dispose_string(s)
	c_str := clang.get_c_string(s)
	if c_str == nil {
		return ""
	}
	return strings.clone_from_cstring(c_str, allocator)
}

// Print every parse diagnostic; refuse to continue past errors. Clang
// error-recovers from a bad parse (a missing stddef.h turns size_t into
// int), so an AST with errors in it describes an ABI the header does not
// have — no output at all beats silently wrong output.
check_parse_diagnostics :: proc(tu: clang.Translation_Unit, header_path: string) -> bool {
	ok := true
	for i in 0 ..< clang.get_num_diagnostics(tu) {
		diag := clang.get_diagnostic(tu, i)
		defer clang.dispose_diagnostic(diag)

		severity := clang.get_diagnostic_severity(diag)
		if severity == .Ignored {
			continue
		}
		fmt.eprintln(clone_clang_string(clang.format_diagnostic(diag, clang.default_diagnostic_display_options())))
		if severity >= .Error {
			ok = false
		}
	}
	if !ok {
		fmt.eprintfln("h2odin: %q did not parse cleanly; refusing to generate from a guessed AST", header_path)
	}
	return ok
}

// The location of clang's builtin headers (stddef.h, stdbool.h, …). This
// binding does not expose it, but the clang driver knows it exactly. Without
// the right resource dir those headers are missing and clang error-recovers
// size_t to int — a silently wrong ABI, the worst failure mode there is.
// When the driver is unavailable the flag is simply omitted; the parse
// diagnostics then report whatever actually breaks.
clang_resource_dir_arg :: proc() -> (arg: cstring, ok: bool) {
	state, stdout, _, err := os.process_exec({command = {"clang", "-print-resource-dir"}}, context.temp_allocator)
	if err != nil || !state.exited || state.exit_code != 0 {
		return "", false
	}
	dir := strings.trim_space(string(stdout))
	if dir == "" {
		return "", false
	}
	return strings.clone_to_cstring(fmt.tprintf("-resource-dir=%s", dir), context.temp_allocator), true
}

visit_top_level :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	state := cast(^Extract_State)rawptr(client_data)
	context = state.ctx

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

clone_clang_string :: proc(s: clang.String) -> string {
	defer clang.dispose_string(s)
	c_str := clang.get_c_string(s)
	if c_str == nil {
		return ""
	}
	return strings.clone_from_cstring(c_str)
}

// A C parameter of array or function type is really a pointer — decay it
// explicitly at capture so the IR never lies about the ABI, whatever spelling
// the header used.
