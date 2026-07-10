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

	// Absolute, cleaned paths of every header in config.inputs. A declaration
	// is "ours" when its source file is in this set — not merely when it is
	// the current TU's main file. That keeps typedef names declared in a
	// sibling input (clang-c/CXString.h used from Index.h) instead of peeling
	// them to the underlying type at use sites.
	input_files: map[string]struct{},
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
	index := clang.createIndex(0, 0) // diagnostics are printed by check_parse_diagnostics
	defer clang.disposeIndex(index)

	state := Extract_State {
		ctx         = context,
		ir          = ir,
		decl_map    = make(map[string]Decl_Ref),
		input_files = make_input_file_set(header_paths),
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
		tu := clang.parseTranslationUnit(index, path, raw_data(base_args[:]), c.int(len(base_args)), nil, 0, {.DetailedPreprocessingRecord})
		if tu == nil {
			fmt.eprintfln("h2odin: failed to parse %q", header_path)
			return false
		}
		if !check_parse_diagnostics(tu, header_path) {
			clang.disposeTranslationUnit(tu)
			return false
		}
		state.tu = tu
		clang.visitChildren(clang.getTranslationUnitCursor(tu), visit_top_level, &state)
		clang.disposeTranslationUnit(tu)
	}
	return true
}

// Build the set of normalized absolute paths for every input header.
make_input_file_set :: proc(header_paths: []string) -> map[string]struct{} {
	files := make(map[string]struct{})
	for path in header_paths {
		if key := normalize_source_path(path); key != "" {
			files[key] = {}
		}
	}
	return files
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
	path := location_source_path(location, context.temp_allocator)
	if path == "" {
		return false
	}
	_, found := state.input_files[path]
	return found
}

// Path clang reports for a source location, normalized like input_files keys.
location_source_path :: proc(location: clang.Source_Location, allocator := context.allocator) -> string {
	file: clang.File
	clang.getFileLocation(location, &file, nil, nil, nil)
	if file == nil {
		return ""
	}
	// Prefer the real path so an include found via -I matches the absolute
	// path we stored for that same header in config.inputs.
	if real := clone_clang_string_with(clang.File_tryGetRealPathName(file), allocator); real != "" {
		return normalize_source_path(real, allocator)
	}
	name := clone_clang_string_with(clang.getFileName(file), allocator)
	return normalize_source_path(name, allocator)
}

// Like clone_clang_string but into an explicit allocator (temp for probes).
clone_clang_string_with :: proc(s: clang.String, allocator := context.allocator) -> string {
	defer clang.disposeString(s)
	c_str := clang.getCString(s)
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
	for i in 0 ..< clang.getNumDiagnostics(tu) {
		diag := clang.getDiagnostic(tu, i)
		defer clang.disposeDiagnostic(diag)

		severity := clang.getDiagnosticSeverity(diag)
		if severity == .Ignored {
			continue
		}
		fmt.eprintln(clone_clang_string(clang.formatDiagnostic(diag, clang.defaultDiagnosticDisplayOptions())))
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
	state := cast(^Extract_State)client_data
	context = state.ctx

	// Bind declarations from any config.inputs header, not only the current
	// TU's main file. Sibling inputs included from another input (clang-c)
	// are still "ours"; system headers and unlisted includes are not.
	if !location_is_ours(state, clang.getCursorLocation(cursor)) {
		return .Continue
	}

	#partial switch clang.getCursorKind(cursor) {
	case .FunctionDecl:
		extract_func(state, cursor)
	case .StructDecl, .UnionDecl:
		record_decl_for_cursor(state, cursor)
	case .EnumDecl:
		enum_decl_for_cursor(state, cursor)
	case .TypedefDecl:
		typedef_decl_for_cursor(state, cursor)
	case .VarDecl:
		extract_var(state, cursor)
	case .MacroDefinition:
		extract_macro(state, cursor)
	}
	return .Continue
}

clone_clang_string :: proc(s: clang.String) -> string {
	defer clang.disposeString(s)
	c_str := clang.getCString(s)
	if c_str == nil {
		return ""
	}
	return strings.clone_from_cstring(c_str)
}

// A C parameter of array or function type is really a pointer — decay it
// explicitly at capture so the IR never lies about the ABI, whatever spelling
// the header used.
