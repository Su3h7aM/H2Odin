package h2odin_e2e

import "core:os"
import "core:strings"
import "core:sync"
import "core:testing"

// os.process_start (used by process_exec) is not thread-safe. The e2e suite
// runs multi-threaded and every test spawns build/h2odin; serialize only the
// spawn/capture so the rest of each test stays free to run in parallel.
process_mu: sync.Mutex

run_process :: proc(command: []string) -> (state: os.Process_State, stdout: []byte, stderr: []byte, err: os.Error) {
	sync.mutex_lock(&process_mu)
	defer sync.mutex_unlock(&process_mu)
	return os.process_exec(os.Process_Desc{command = command}, context.allocator)
}

run_h2odin :: proc(t: ^testing.T, command: []string) -> ([]byte, []byte, bool) {
	state, stdout, stderr, err := run_process(command)
	if err != nil {
		testing.expectf(t, false, "process_exec failed: %v", err)
		return stdout, stderr, false
	}
	if !state.success || state.exit_code != 0 {
		testing.expectf(t, false, "command failed with exit %d\nstderr:\n%s", state.exit_code, string(stderr))
		return stdout, stderr, false
	}
	return stdout, stderr, true
}

run_h2odin_expect_failure :: proc(t: ^testing.T, command: []string) -> ([]byte, []byte, int, bool) {
	state, stdout, stderr, err := run_process(command)
	if err != nil {
		testing.expectf(t, false, "process_exec failed: %v", err)
		return stdout, stderr, 0, false
	}
	if state.success && state.exit_code == 0 {
		testing.expectf(t, false, "command unexpectedly succeeded\nstdout:\n%s", string(stdout))
		return stdout, stderr, state.exit_code, false
	}
	return stdout, stderr, state.exit_code, true
}

expect_contains :: proc(t: ^testing.T, haystack: []byte, needle: string) {
	testing.expectf(t, strings.contains(string(haystack), needle), "expected output to contain %q", needle)
}

expect_not_contains :: proc(t: ^testing.T, haystack: []byte, needle: string) {
	testing.expectf(t, !strings.contains(string(haystack), needle), "expected output not to contain %q", needle)
}

// Generate a project fixture (tests/fixtures/configs/<name>/H2Odin.lua) to
// stdout. Caller owns the returned bytes.
generate_fixture :: proc(t: ^testing.T, name: string) -> (stdout: []byte, ok: bool) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)
	proj := strings.concatenate({cwd, "/tests/fixtures/configs/", name})
	defer delete(proj)

	cmd := [?]string{"build/h2odin", "-destination:stdout", proj}
	out, stderr, run_ok := run_h2odin(t, cmd[:])
	defer delete(stderr)
	if !run_ok {
		delete(out)
		return nil, false
	}
	return out, true
}

// Generated bindings must compile: `odin check` the emitted package.
check_generated_output :: proc(t: ^testing.T, content: []byte, out_dir: string) {
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	path := strings.concatenate({out_dir, "/generated.odin"})
	defer delete(path)
	testing.expect_value(t, os.write_entire_file(path, content), nil)

	cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	testing.expect(t, ok)
}

@(test)
test_add_fixture_abi_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/add.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package add")
	expect_contains(t, stdout, "import \"core:c\"")
	expect_contains(t, stdout, "add :: proc(a: c.int, b: c.int) -> c.int ---")
}

@(test)
test_add_fixture_idiomatic_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/add_idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package add")
	expect_not_contains(t, stdout, "import \"core:c\"")
	expect_contains(t, stdout, "add :: proc(a: i32, b: i32) -> i32 ---")
}

@(test)
test_idiomatic_mode_defaults_to_native_leaf_types :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Rung 1: table preference, size-verified.
	expect_contains(t, stdout, "checksum :: proc(data: rawptr, nbytes: u64) -> u32 ---")
	expect_contains(t, stdout, "ticks :: proc() -> i64 ---")
	expect_contains(t, stdout, "uticks :: proc() -> u64 ---")
	// Rung 1 for both: size_t -> uint, and plain char -> u8 (matching
	// core:c.char, not the true per-target signedness).
	expect_contains(t, stdout, "payload_len :: proc(tag: u8) -> uint ---")
	// Enum backing types substitute through the same ladder.
	expect_contains(t, stdout, "Mode :: enum u32")
	expect_contains(t, stdout, "get_mode :: proc() -> Mode ---")
	// The ABI fallback (c.X) should not appear anywhere on the idiomatic
	// surface for this fixture — every leaf here is determinable, so
	// nothing pulls in core:c at all.
	expect_not_contains(t, stdout, "import \"core:c\"")
}

@(test)
test_basic_config_sets_package_foreign_lib_and_type_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/basic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package mylib")
	expect_contains(t, stdout, "foreign import lib \"system:mylib_native\"")
	expect_contains(t, stdout, "add :: proc(a: i32, b: i32) -> i32 ---")
}

@(test)
test_keyword_safe_defaults_emit_link_name :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/keywords.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "@(link_name = \"matrix\")")
	expect_contains(t, stdout, "matrix_: [16]c.float")
	// C names are kept (foreign porting convention); keyword collisions get _.
	expect_contains(t, stdout, "map_ :: struct")
	expect_contains(t, stdout, "context_: c.int")
}

@(test)
test_declarative_config_applies_prefixes_and_type_map :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/declarative.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "MAX_POINTS :: 64")
	expect_contains(t, stdout, "@(link_name = \"gl_Distance\")")
	// types.overrides on a typedef emits a named alias; use sites keep the name.
	expect_contains(t, stdout, "Vector2 :: [2]f32")
	expect_contains(t, stdout, "Distance :: proc(a: Vector2, b: Vector2) -> c.int ---")
	expect_not_contains(t, stdout, "gl_Vector2 :: struct")
	expect_not_contains(t, stdout, "Vector2 :: struct")
}

@(test)
test_remove_where_filters_top_level_decls :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/keep.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "VERSION :: 3")
	expect_contains(t, stdout, "distance :: proc(a: Point, b: Point) -> c.int ---")
	expect_contains(t, stdout, "visible_count: c.int")
	expect_not_contains(t, stdout, "internal_BUILD")
	expect_not_contains(t, stdout, "internal_reset")
	expect_not_contains(t, stdout, "internal_count")
}

@(test)
test_diagnostics_report_lists_guessed_pointer_lowerings :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/pointers.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Bindings on stdout via -destination:stdout; the report is a single stderr block.
	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, "warning[pointer_lowering_guess]:")
	expect_contains(t, stderr, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
	expect_contains(t, stderr, `guessed pointer lowering in function "make_row" return type: defaulted to ^T`)
	// Proven lowerings (void*, const char*, function pointers) must not appear.
	expect_not_contains(t, stderr, `function "on_event"`)
	expect_not_contains(t, stderr, `function "log_fmt"`)
}

@(test)
test_diagnostics_report_lists_unknown_size_extern_arrays :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/extern_arrays.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "version:")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, "warning[incomplete_extern_array]:")
	expect_contains(t, stderr, `extern array "version" has unknown size; emitted as [0]T`)
	expect_contains(t, stderr, `extern array "values" has unknown size; emitted as [0]T`)
	// Known bounds are certain — no note for them.
	expect_not_contains(t, stderr, "known_values")
}

@(test)
test_quiet_suppresses_diagnostics_report :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/pointers.lua", "-quiet"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "fill :: proc")
	expect_not_contains(t, stderr, "non-certain")
	expect_not_contains(t, stderr, "pointer_lowering_guess")
}

@(test)
test_diagnostics_error_severity_exits_nonzero_after_emit :: proc(t: ^testing.T) {
	// pointer_lowering_guess = error still emits bindings, then fails the run.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/diag_pointer_error.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "error[pointer_lowering_guess]:")
	expect_contains(t, stderr, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
}

@(test)
test_bad_config_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bad_type_map.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `types.overrides["Foo"] must be a string`)
}

@(test)
test_unknown_config_key_fails_with_clear_message :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/unknown_key.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `unknown key "typo_mode"`)
}

@(test)
test_unsupported_config_key_fails_with_clear_message :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/unsupported_key.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `"wrappers" is not yet supported`)
}

@(test)
test_m9_macro_groups_synthesize_enum :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m9_macros.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Grouped integer macros become an enum; contiguous 0..n omit `= N`,
	// non-default values stay explicit. Originals dropped.
	expect_contains(t, stdout, "Result_Code :: enum")
	expect_contains(t, stdout, "OK")
	expect_contains(t, stdout, "ERR")
	expect_contains(t, stdout, "ROW = 100")
	expect_not_contains(t, stdout, "OK = 0")
	expect_not_contains(t, stdout, "ERR = 1")
	expect_not_contains(t, stdout, "LIB_OK ::")
	// Excluded prefix stays as standalone consts; non-integers are not enum members.
	expect_contains(t, stdout, "LIB_OPEN_RO ::")
	expect_contains(t, stdout, "LIB_TITLE ::")
}

@(test)
test_m9_enum_policies_anonymous_member_bit_set :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m9_enums.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Keyboard_Key :: enum")
	expect_contains(t, stdout, "NULL")
	// Sequential 0..n: no explicit values.
	expect_not_contains(t, stdout, "NULL = 0")
	// FLAG_COUNT removed by enums.member; remaining flags log2'd to 0,1,2.
	expect_contains(t, stdout, "Config_Flag :: enum")
	expect_contains(t, stdout, "VSYNC")
	expect_contains(t, stdout, "FULLSCREEN")
	expect_contains(t, stdout, "MSAA")
	expect_not_contains(t, stdout, "VSYNC = 0")
	expect_not_contains(t, stdout, "FULLSCREEN = 1")
	expect_not_contains(t, stdout, "MSAA = 2")
	expect_not_contains(t, stdout, "COUNT")
	expect_contains(t, stdout, "Config_Flags :: bit_set[Config_Flag; u32]")
}

@(test)
test_m9_naming_overrides_and_remove_tiers :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m9_naming.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Widget ::")
	expect_contains(t, stdout, "size_t_like ::") // strip_suffixes type _t
	expect_contains(t, stdout, "@(link_name = \"lib_open\")")
	expect_contains(t, stdout, "open :: proc")
	expect_contains(t, stdout, "@(link_name = \"lib_special_do_thing\")")
	expect_contains(t, stdout, "do_thing :: proc")
	expect_not_contains(t, stdout, "lib_internal")
	expect_not_contains(t, stdout, "LIB_ITEM_COUNT")
	expect_contains(t, stdout, "LIB_OK ::")
}

@(test)
test_parse_error_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bad_parse.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, "did not parse cleanly")
}

@(test)
test_m10_structs_procs_and_link_prefix :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m10_structs.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, `@(link_prefix = "rl_")`)
	// structs.fields: tag + type spelling
	expect_contains(t, stdout, "name: [32]c.char `fmt:\"s,0\"`")
	expect_contains(t, stdout, "parent: i32")
	// structs.align
	expect_contains(t, stdout, "Mesh :: struct #align(16)")
	// structs.field callback
	expect_contains(t, stdout, "vertexCount: c.int")
	// procs.params / results / param callback
	expect_contains(t, stdout, "SetConfigFlags :: proc(flags: ConfigFlags)")
	expect_contains(t, stdout, "GetKeyPressed :: proc() -> c.int")
	expect_contains(t, stdout, "DrawTexturePro :: proc(tint: Color = WHITE)")
}

@(test)
test_m10_multi_header_inputs :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m10_inputs.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m10i")
	expect_contains(t, stdout, "m10_from_a :: proc")
	expect_contains(t, stdout, "m10_from_b :: proc")
}

@(test)
test_m13_sibling_input_typedef_keeps_name :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m13_sibling.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m13s")
	expect_contains(t, stdout, "Sibling_Id ::")
	// Use site in a.h must reference the sibling typedef, not peel to c.int.
	expect_contains(t, stdout, "m13_use_sibling :: proc(id: Sibling_Id)")
	expect_contains(t, stdout, "m13_make_sibling :: proc")
	expect_contains(t, stdout, "M13_SIBLING_FLAG")
	// No duplicate emission of the sibling proc.
	count := strings.count(string(stdout), "m13_make_sibling :: proc")
	testing.expect_value(t, count, 1)
}

// A project header that config.inputs does not list is still ours: the
// umbrella-header pattern (Box3D lists box3d.h and reaches types.h through
// it) depends on it. Only system headers are foreign (spec 0010), so
// Hidden_Id keeps its name instead of peeling to the underlying builtin.
@(test)
test_unlisted_project_header_typedef_is_ours :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m13_peel.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m13p")
	expect_contains(t, stdout, "Hidden_Id :: c.int")
	expect_contains(t, stdout, "m13_use_hidden :: proc(id: Hidden_Id)")
}

@(test)
test_m10_preprocess_include_and_define :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m10_preprocess.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// -D M10_ENABLE makes this declaration visible; -I finds the include.
	expect_contains(t, stdout, "m10_enabled :: proc")
}

@(test)
test_m10_output_footer_and_interleave :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/m10_output.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m10o")
	expect_contains(t, stdout, "add :: proc")
	// footer_per_header appends configs/add_footer.odin (next to the config).
	expect_contains(t, stdout, "FOOTER_MARKER")
}

@(test)
test_comments_default_emits_docs :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/docs.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "A documented record")
	expect_contains(t, stdout, "Does documented work")
	expect_contains(t, stdout, "Documented :: struct")
	expect_contains(t, stdout, "documented :: proc")
}

@(test)
test_comments_false_suppresses_docs :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/no_comments.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_not_contains(t, stdout, "A documented record")
	expect_not_contains(t, stdout, "Does documented work")
	expect_not_contains(t, stdout, "Current API version")
	expect_contains(t, stdout, "Documented :: struct")
	expect_contains(t, stdout, "documented :: proc")
	expect_contains(t, stdout, "API_VERSION :: 1")
}

// Spec 0009: C-deprecated decls propagate as @(deprecated) / Deprecated: lines.
@(test)
test_deprecated_propagates_by_default :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/deprecated.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Proc and type: Odin attribute with the C message verbatim.
	expect_contains(t, stdout, `@(deprecated = "use new_fn instead")`)
	expect_contains(t, stdout, "old_fn :: proc()")
	expect_contains(t, stdout, `@(deprecated = "use New_Type instead")`)
	expect_contains(t, stdout, "Old_Type :: struct")
	// Variable and constant: semantic Deprecated: doc line.
	expect_contains(t, stdout, "Deprecated: use new_var instead")
	expect_contains(t, stdout, "old_var:")
	expect_contains(t, stdout, "Deprecated: use NEW_CONST instead")
	expect_contains(t, stdout, "OLD_CONST :: 42")
	// Attribute without a message → fixed fallback.
	expect_contains(t, stdout, `@(deprecated = "deprecated in the C header")`)
	expect_contains(t, stdout, "bare_deprecated_fn :: proc()")
	// Live API is untouched.
	expect_contains(t, stdout, "live_fn :: proc()")
}

@(test)
test_deprecated_doc_line_survives_comments_false :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/deprecated_no_comments.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Deprecated: use new_var instead")
	expect_contains(t, stdout, "Deprecated: use NEW_CONST instead")
	expect_contains(t, stdout, `@(deprecated = "use new_fn instead")`)
}

@(test)
test_deprecated_remove_drops_all :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/deprecated_remove.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_not_contains(t, stdout, "old_fn")
	expect_not_contains(t, stdout, "Old_Type")
	expect_not_contains(t, stdout, "old_var")
	expect_not_contains(t, stdout, "OLD_CONST")
	expect_not_contains(t, stdout, "bare_deprecated_fn")
	expect_contains(t, stdout, "live_fn :: proc()")
}

@(test)
test_deprecated_where_predicate_sees_flag :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/deprecated_where.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// where returns sym.deprecated → same drop set as remove.deprecated.
	expect_not_contains(t, stdout, "old_fn")
	expect_not_contains(t, stdout, "Old_Type")
	expect_not_contains(t, stdout, "old_var")
	expect_not_contains(t, stdout, "OLD_CONST")
	expect_contains(t, stdout, "live_fn :: proc()")
}

@(test)
test_m10_output_folder_writes_file :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-m10-out"
	_ = os.remove_all(out_dir)

	// Config lives under /tmp, so inputs must be absolute (relative paths
	// resolve against the config directory).
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	header := strings.concatenate({cwd, "/tests/fixtures/add.h"})
	defer delete(header)

	cfg_path := "/tmp/h2odin-m10-out-config.lua"
	cfg := strings.concatenate(
		{
			`local h2o = require "h2odin"
local config = h2o.config()
config.package = "m10f"
config.foreign.import_lib = "m10f"
config.inputs = { "`,
			header,
			`" }
config.output_folder = "/tmp/h2odin-m10-out"
return config
`,
		},
	)
	defer delete(cfg)
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-config:/tmp/h2odin-m10-out-config.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	// Main goes to disk; stdout should be empty.
	testing.expect_value(t, len(stdout), 0)

	main_data, main_err := os.read_entire_file("/tmp/h2odin-m10-out/add.odin", context.allocator)
	defer delete(main_data)
	testing.expect(t, main_err == nil)
	expect_contains(t, main_data, "package m10f")
	expect_contains(t, main_data, "add :: proc")
	// Prelude (package + foreign import) lives in the same file.
	expect_contains(t, main_data, "foreign import lib")
}

@(test)
test_m12_bit_fields_emit_proven_layout_and_fail_closed :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bit_fields.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "H2O_IndexOptions :: struct")
	expect_contains(t, stdout, "using _: bit_field u16 {")
	expect_contains(t, stdout, "ExcludeDeclarationsFromPCH: u16 | 1")
	expect_contains(t, stdout, "_: u16 | 13")
	expect_contains(t, stdout, "H2O_Plain :: struct")
	expect_contains(t, stdout, "x: c.int")
	expect_contains(t, stdout, "H2O_Overlapping :: struct {}")
	expect_contains(t, stderr, "warning[bit_field_layout_fallback]:")
	expect_not_contains(t, stderr, `record "H2O_Overlapping" field "pointer"`)

	out_dir := "/tmp/h2odin-m12-bit-fields"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-m12-bit-fields/generated.odin", stdout), nil)
	// Fixture keeps C field spellings; generated libclang uses Odin snake_case.
	layout_check := `package bit_fields

import clang "vendored:libclang"

#assert(size_of(H2O_IndexOptions) == size_of(clang.Index_Options))
#assert(offset_of(H2O_IndexOptions, PreambleStoragePath) == offset_of(clang.Index_Options, preamble_storage_path))
#assert(offset_of(H2O_IndexOptions, InvocationEmissionPath) == offset_of(clang.Index_Options, invocation_emission_path))
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-m12-bit-fields/layout_check.odin", layout_check), nil)

	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point", "-collection:vendored=./vendored"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)

	override_cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bit_fields_override.lua"}
	override_stdout, override_stderr, override_ok := run_h2odin(t, override_cmd[:])
	defer delete(override_stdout)
	defer delete(override_stderr)
	if override_ok {
		expect_contains(t, override_stdout, "H2O_IndexOptions :: struct {}")
		expect_contains(t, override_stderr, `warning[bit_field_layout_fallback]: "H2O_IndexOptions"`)
	}
}

@(test)
test_m14_per_header_writes_partitioned_package :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-m14-out"
	_ = os.remove_all(out_dir)

	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m14_per_header.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect_value(t, len(stdout), 0)

	a_data, a_err := os.read_entire_file("/tmp/h2odin-m14-out/m14_a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "package m14")
	expect_contains(t, a_data, "foreign import lib")
	expect_contains(t, a_data, "M14_A_Id ::")
	expect_contains(t, a_data, "m14_from_a :: proc")
	expect_contains(t, a_data, "M14_A_FLAG")
	expect_not_contains(t, a_data, "m14_from_b")
	expect_not_contains(t, a_data, "M14_B_Rec")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-m14-out/m14_b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_contains(t, b_data, "package m14")
	expect_contains(t, b_data, "foreign import lib")
	expect_contains(t, b_data, "M14_B_Rec ::")
	expect_contains(t, b_data, "m14_from_b :: proc")
	expect_not_contains(t, b_data, "m14_from_a")

	empty_data, empty_err := os.read_entire_file("/tmp/h2odin-m14-out/m14_empty.odin", context.allocator)
	defer delete(empty_data)
	testing.expect(t, empty_err == nil)
	expect_contains(t, empty_data, "package m14")
	// Function-like macros are not emitted; file is still valid Odin.
	expect_not_contains(t, empty_data, "M14_EMPTY_HELPER")

	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)
}

@(test)
test_m14_per_header_footer_per_unit :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-m14-footer"
	_ = os.remove_all(out_dir)

	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	a_h := strings.concatenate({cwd, "/tests/fixtures/m14_a.h"})
	defer delete(a_h)
	b_h := strings.concatenate({cwd, "/tests/fixtures/m14_b.h"})
	defer delete(b_h)

	// Footers live next to the config (config dir search).
	cfg_dir := "/tmp/h2odin-m14-footer-cfg"
	_ = os.remove_all(cfg_dir)
	testing.expect_value(t, os.make_directory_all(cfg_dir), nil)
	footer_a, fa_err := os.read_entire_file("tests/fixtures/configs/m14_a_footer.odin", context.allocator)
	defer delete(footer_a)
	testing.expect(t, fa_err == nil)
	footer_b, fb_err := os.read_entire_file("tests/fixtures/configs/m14_b_footer.odin", context.allocator)
	defer delete(footer_b)
	testing.expect(t, fb_err == nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-m14-footer-cfg/m14_a_footer.odin", footer_a), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-m14-footer-cfg/m14_b_footer.odin", footer_b), nil)

	cfg := strings.concatenate(
		{
			`local h2o = require "h2odin"
local config = h2o.config()
config.package = "m14f"
config.foreign.import_lib = "m14f"
config.inputs = { "`,
			a_h,
			`", "`,
			b_h,
			`" }
config.output_folder = "/tmp/h2odin-m14-footer"
config.output.layout = "per_header"
config.output.footer_per_header = true
return config
`,
		},
	)
	defer delete(cfg)
	cfg_path := "/tmp/h2odin-m14-footer-cfg/config.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	config_arg := strings.concatenate({"-config:", cfg_path})
	defer delete(config_arg)
	cmd := [?]string{"build/h2odin", config_arg}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	a_data, a_err := os.read_entire_file("/tmp/h2odin-m14-footer/m14_a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "FOOTER_A_MARKER")
	expect_not_contains(t, a_data, "FOOTER_B_MARKER")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-m14-footer/m14_b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_contains(t, b_data, "FOOTER_B_MARKER")
	expect_not_contains(t, b_data, "FOOTER_A_MARKER")
}

@(test)
test_rejects_imports_file :: proc(t: ^testing.T) {
	cfg := `local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "tests/fixtures/add.h" }
config.output.imports_file = "imports.odin"
return config
`
	cfg_path := "/tmp/h2odin-imports-file-reject.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:/tmp/h2odin-imports-file-reject.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "output.imports_file")
	expect_contains(t, stderr, "was removed")
}

@(test)
test_m14_per_header_requires_output_folder :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	header := strings.concatenate({cwd, "/tests/fixtures/m14_a.h"})
	defer delete(header)
	cfg := strings.concatenate(
		{`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "`, header, `" }
config.output.layout = "per_header"
return config
`},
	)
	defer delete(cfg)
	cfg_path := "/tmp/h2odin-m14-nofolder.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:/tmp/h2odin-m14-nofolder.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "output_folder")
}

@(test)
test_m14_unknown_layout_rejected_at_load :: proc(t: ^testing.T) {
	cfg := `local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "x.h" }
config.output.layout = "by_category"
return config
`
	cfg_path := "/tmp/h2odin-m14-bad-layout.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:/tmp/h2odin-m14-bad-layout.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "output.layout")
}

@(test)
test_opaque_tags_abi_default_faithful :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_contains(t, stdout, "take_tag :: proc(t: ^Opaque_Tag")
	expect_contains(t, stdout, "out: ^^Opaque_Tag")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
}

@(test)
test_opaque_tags_idiomatic_default_handle :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
	expect_contains(t, stdout, "take_tag :: proc(t: Opaque_Tag")
	expect_contains(t, stdout, "out: ^Opaque_Tag")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_not_contains(t, stdout, "^^Opaque_Tag")
}

@(test)
test_opaque_tags_abi_opt_in_handle :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_opt_in.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
	expect_contains(t, stdout, "take_tag :: proc(t: Opaque_Tag")
	expect_contains(t, stdout, "out: ^Opaque_Tag")
	expect_not_contains(t, stdout, "^^Opaque_Tag")

	out_dir := "/tmp/h2odin-opaque-tags"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-tags/generated.odin", stdout), nil)
	ok_src := `package opaque_tags

nil_ok :: proc() -> Opaque_Tag {
	return nil
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-tags/ok.odin", ok_src), nil)
	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)
}

@(test)
test_opaque_tags_idiomatic_opt_out_faithful :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_opt_out.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_contains(t, stdout, "take_tag :: proc(t: ^Opaque_Tag")
	expect_contains(t, stdout, "out: ^^Opaque_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
}

@(test)
test_opaque_tags_complete_fails_closed :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_complete.lua"}
	stdout, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	// Generator still emits (faithful), but error severity fails the run.
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)

	expect_contains(t, stderr, "opaque_record_complete")
	expect_contains(t, stderr, "Complete_Tag")
	// Faithful emission retained for the complete record.
	expect_contains(t, stdout, "Complete_Tag :: struct")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Complete_Tag :: distinct rawptr")
}

@(test)
test_opaque_handles_distinct_rawptr :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_handles.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Incomplete-record handles are distinct automatically.
	expect_contains(t, stdout, "Opaque_A :: distinct rawptr")
	expect_contains(t, stdout, "Opaque_B :: distinct rawptr")
	// Shared record: first is distinct; second aliases the first.
	expect_contains(t, stdout, "Shared_Handle :: distinct rawptr")
	expect_contains(t, stdout, "Shared_Alias :: Shared_Handle")
	// types.distinct opts void* in; unlisted void* stays plain.
	expect_contains(t, stdout, "Void_Handle :: distinct rawptr")
	expect_contains(t, stdout, "Void_Plain :: rawptr")
	// Complete record pointer is still a pointer, not collapsed.
	expect_contains(t, stdout, "Complete_Ptr ::")
	expect_contains(t, stdout, "^Complete_Rec")
	// Incomplete *Impl records are not emitted as empty structs.
	expect_not_contains(t, stdout, "Opaque_A_Impl")
	expect_not_contains(t, stdout, "Shared_Impl")

	out_dir := "/tmp/h2odin-opaque-handles"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/generated.odin", stdout), nil)

	// Cross-assignment of distinct handles must fail; same-record aliases and
	// nil assignment must succeed (odin check of a companion file).
	check_src := `package opaque_handles

cross_assign :: proc(a: Opaque_A) -> Opaque_B {
	return a // should not type-check
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/cross.odin", check_src), nil)
	cross_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	_, cross_stderr, cross_code, cross_ok := run_h2odin_expect_failure(t, cross_cmd[:])
	defer delete(cross_stderr)
	if !cross_ok {
		return
	}
	testing.expect(t, cross_code != 0)

	// Positive check: aliases assign; nil works; no cross-file needed beyond generated.
	_ = os.remove("/tmp/h2odin-opaque-handles/cross.odin")
	ok_src := `package opaque_handles

shared_ok :: proc(s: Shared_Handle) -> Shared_Alias {
	return s
}

nil_ok :: proc() -> Opaque_A {
	return nil
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/ok.odin", ok_src), nil)
	ok_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	ok_stdout, ok_stderr, ok_ok := run_h2odin(t, ok_cmd[:])
	defer delete(ok_stdout)
	defer delete(ok_stderr)
	testing.expect(t, ok_ok)
}

@(test)
test_default_destination_requires_output_folder :: proc(t: ^testing.T) {
	// Without -destination:stdout, bindings must go to config.output_folder.
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/add.lua"}
	stdout, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, "output_folder")
	expect_contains(t, stderr, "-destination:stdout")
}

@(test)
test_project_dir_loads_h2odin_lua :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	header := strings.concatenate({cwd, "/tests/fixtures/add.h"})
	defer delete(header)

	proj := "/tmp/h2odin-project-dir"
	_ = os.remove_all(proj)
	testing.expect_value(t, os.make_directory_all(proj), nil)

	cfg := strings.concatenate(
		{
			`local h2o = require "h2odin"
local config = h2o.config()
config.package = "projdir"
config.foreign.import_lib = "projdir"
config.inputs = { "`,
			header,
			`" }
config.output_folder = "/tmp/h2odin-project-dir-out"
return config
`,
		},
	)
	defer delete(cfg)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-project-dir/H2Odin.lua", cfg), nil)
	_ = os.remove_all("/tmp/h2odin-project-dir-out")

	cmd := [?]string{"build/h2odin", proj}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect_value(t, len(stdout), 0)

	data, err := os.read_entire_file("/tmp/h2odin-project-dir-out/add.odin", context.allocator)
	defer delete(data)
	testing.expect(t, err == nil)
	expect_contains(t, data, "package projdir")
	expect_contains(t, data, "add :: proc")
}

@(test)
test_verbose_diagnostics_include_guidance :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-verbose", "-config:tests/fixtures/configs/pointers.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "warning[pointer_lowering_guess]:")
	expect_contains(t, stderr, "cause:")
	expect_contains(t, stderr, "fix:")
	expect_contains(t, stderr, "procs.params")
	// -verbose also prints linked libclang + resource-dir provenance.
	expect_contains(t, stderr, "h2odin: libclang:")
	expect_contains(t, stderr, "h2odin: resource-dir:")
}

@(test)
test_calling_conv_unsupported_exits_nonzero :: proc(t: ^testing.T) {
	// vectorcall is captured but has no Odin spelling → error diagnostic,
	// still emits, exit non-zero (Milestone 16 P0).
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/calling_conv.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	expect_contains(t, stderr, "error[unsupported_calling_conv]:")
	// Still emits the rest of the surface (same posture as other error diags).
	expect_contains(t, stdout, "plain_c :: proc")
}

@(test)
test_calling_conv_supported_emits_stdcall_and_callback_types :: proc(t: ^testing.T) {
	// Drop vectorcall so the run succeeds; check stdcall/fastcall on decls
	// and nested callback typedefs.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/calling_conv_supported.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_not_contains(t, stderr, "unsupported_calling_conv")
	expect_contains(t, stdout, "plain_c :: proc(")
	// Non-C conventions must be stated on foreign decls.
	// On targets where the attribute does not stick, libclang may still
	// report C — then the spelling stays the foreign default. Accept either
	// the explicit convention or the plain form, but never a wrong rewrite.
	out := string(stdout)
	if strings.contains(out, "stdcall_fn :: proc \"stdcall\"") {
		// preferred path when libclang reports Stdcall
	} else {
		expect_contains(t, stdout, "stdcall_fn :: proc(")
	}
	if strings.contains(out, "Stdcall_Cb :: ") {
		// Callback typedef should spell the convention on the proc type when known.
		// e.g. `Stdcall_Cb :: proc "stdcall" ()` or `^proc "stdcall" ()` depending
		// on pointer lowering (function pointers lower to bare proc types).
		if strings.contains(out, "proc \"stdcall\"") || strings.contains(out, "proc \"c\"") {
			// ok — captured fact serialized
		} else {
			testing.expectf(t, false, "Stdcall_Cb missing procedure-type convention spelling:\n%s", out)
		}
	}
}

@(test)
test_void_opaque_typedef_emits_distinct_rawptr :: proc(t: ^testing.T) {
	// Pure `typedef void Name` (curl's CURL, miniaudio's ma_data_source) is
	// a common C opaque-handle idiom. The typedef names an incomplete type;
	// the API only passes `Name *`. Generation must not panic, and the
	// typedef should emit `Name :: distinct rawptr` with all references
	// (direct, callback typedef, record field) resolving to ^Name.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/void_opaque.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "CURL :: distinct rawptr")
	expect_contains(t, stdout, "CURLM :: distinct rawptr")
	// Direct use: return type and parameter.
	expect_contains(t, stdout, "curl_easy_init :: proc() -> ^CURL")
	expect_contains(t, stdout, "curl_easy_cleanup :: proc(handle: ^CURL)")
	// Callback typedef references the opaque name.
	expect_contains(t, stdout, "^CURL")
	// Record field references the opaque name.
	expect_contains(t, stdout, "easy: ^CURL")

	// odin check: the generated package must be valid Odin.
	out_dir := "/tmp/h2odin-void-opaque"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-void-opaque/generated.odin", stdout), nil)
	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)
}

@(test)
test_foreign_record_emitted_as_incomplete_stub :: proc(t: ^testing.T) {
	// A system type the built-in map does not know (FILE), used only behind a
	// pointer: incomplete stub, never a copy of the system layout.
	stdout, ok := generate_fixture(t, "foreign_ref")
	defer delete(stdout)
	if !ok {
		return
	}

	expect_contains(t, stdout, "log_sink :: struct")
	expect_contains(t, stdout, ":: struct {}")
	// The system header's fields must not appear in our package.
	expect_not_contains(t, stdout, "_IO_read_ptr")
	expect_not_contains(t, stdout, "_flags")

	check_generated_output(t, stdout, "/tmp/h2odin-foreign-ref")
}

@(test)
test_foreign_sockaddr_maps_to_posix :: proc(t: ^testing.T) {
	// Known system type sockaddr → core:sys/posix.sockaddr (vendor:curl style).
	// Embedded by value, so a struct {} stub would have the wrong size.
	stdout, ok := generate_fixture(t, "posix_sockaddr")
	defer delete(stdout)
	if !ok {
		return
	}

	expect_contains(t, stdout, "import \"core:sys/posix\"")
	expect_contains(t, stdout, "addr: posix.sockaddr")
	expect_contains(t, stdout, "curl_sockaddr :: struct")
	// Must not emit a local sockaddr claiming the system layout. The newline
	// anchors the declaration: "curl_sockaddr :: struct" ends the same way.
	expect_not_contains(t, stdout, "\nsockaddr :: struct")
	expect_not_contains(t, stdout, "sa_family")

	check_generated_output(t, stdout, "/tmp/h2odin-posix-sockaddr")
}

// Spec 0010: named POSIX/libc scalars keep one spelling in both type modes —
// they are distinct, OS-width-specific Odin types, not an integer ladder rung.
// ISO C names (size_t) still follow the mode.
@(test)
test_posix_scalars_same_spelling_in_abi_mode :: proc(t: ^testing.T) {
	stdout, ok := generate_fixture(t, "posix_scalars_abi")
	defer delete(stdout)
	if !ok {
		return
	}

	expect_contains(t, stdout, "import \"core:sys/posix\"")
	expect_contains(t, stdout, "import \"core:c/libc\"")
	expect_contains(t, stdout, "offset: posix.off_t) -> posix.off_t")
	expect_contains(t, stdout, "lib_owner :: proc() -> posix.pid_t")
	expect_contains(t, stdout, "out: ^libc.time_t) -> libc.time_t")
	// ISO C stays on the c.* ladder in ABI mode, and no foreign typedef
	// declaration leaks into our package.
	expect_contains(t, stdout, "-> c.size_t")
	expect_not_contains(t, stdout, "off_t ::")
	expect_not_contains(t, stdout, "time_t ::")

	check_generated_output(t, stdout, "/tmp/h2odin-posix-scalars-abi")
}

@(test)
test_posix_scalars_same_spelling_in_idiomatic_mode :: proc(t: ^testing.T) {
	stdout, ok := generate_fixture(t, "posix_scalars_idiomatic")
	defer delete(stdout)
	if !ok {
		return
	}

	// Identical to ABI mode: no peel to i64/i32.
	expect_contains(t, stdout, "offset: posix.off_t) -> posix.off_t")
	expect_contains(t, stdout, "lib_owner :: proc() -> posix.pid_t")
	expect_contains(t, stdout, "out: ^libc.time_t) -> libc.time_t")
	// ISO C size_t does follow the mode.
	expect_contains(t, stdout, "-> uint")

	check_generated_output(t, stdout, "/tmp/h2odin-posix-scalars-idiomatic")
}

@(test)
test_types_map_beats_builtin_posix_map :: proc(t: ^testing.T) {
	stdout, ok := generate_fixture(t, "posix_scalars_override")
	defer delete(stdout)
	if !ok {
		return
	}

	// types.map = { pid_t = "i32" } wins over the built-in posix.pid_t;
	// unmapped names still take the built-in spelling.
	expect_contains(t, stdout, "lib_owner :: proc() -> i32")
	expect_not_contains(t, stdout, "posix.pid_t")
	expect_contains(t, stdout, "offset: posix.off_t")

	check_generated_output(t, stdout, "/tmp/h2odin-posix-scalars-override")
}

@(test)
test_project_dir_missing_h2odin_lua_fails :: proc(t: ^testing.T) {
	proj := "/tmp/h2odin-empty-project"
	_ = os.remove_all(proj)
	testing.expect_value(t, os.make_directory_all(proj), nil)

	cmd := [?]string{"build/h2odin", proj}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "H2Odin.lua")
}

// Spec 0008: package-scope collision after strip_prefixes.
@(test)
test_symbol_collision_package_scope_exits_error :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)
	proj := strings.concatenate({cwd, "/tests/fixtures/configs/symbol_collision"})
	defer delete(proj)

	cmd := [?]string{"build/h2odin", "-destination:stdout", proj}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, exit_code != 0)
	// Output is still written (fail closed after emit).
	expect_contains(t, stdout, "Open :: proc")
	expect_contains(t, stderr, "error[symbol_collision]:")
	expect_contains(t, stderr, `package-scope name "Open"`)
}

// Spec 0008: field name shadows a type used again in the same record.
@(test)
test_field_shadow_exits_error :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)
	proj := strings.concatenate({cwd, "/tests/fixtures/configs/field_shadow"})
	defer delete(proj)

	cmd := [?]string{"build/h2odin", "-destination:stdout", proj}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, exit_code != 0)
	expect_contains(t, stdout, "format ::")
	expect_contains(t, stderr, "error[symbol_collision]:")
	expect_contains(t, stderr, "shadows type")
	expect_contains(t, stderr, "format")
}

// Spec 0008: param name shadows a type used by a later parameter.
@(test)
test_param_shadow_exits_error :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)
	proj := strings.concatenate({cwd, "/tests/fixtures/configs/param_shadow"})
	defer delete(proj)

	cmd := [?]string{"build/h2odin", "-destination:stdout", proj}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, exit_code != 0)
	expect_contains(t, stdout, "formadd :: proc")
	expect_contains(t, stderr, "error[symbol_collision]:")
	expect_contains(t, stderr, "parameter")
	expect_contains(t, stderr, "httppost")
}

// Spec 0008: downgrade to warn still emits and succeeds the run.
@(test)
test_symbol_collision_warn_still_succeeds :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	cfg_dir := "/tmp/h2odin-collision-warn"
	_ = os.remove_all(cfg_dir)
	testing.expect_value(t, os.make_directory_all(cfg_dir), nil)

	// Copy header
	hdr, herr := os.read_entire_file("tests/fixtures/configs/symbol_collision/input.h", context.allocator)
	defer delete(hdr)
	testing.expect(t, herr == nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-collision-warn/input.h", hdr), nil)

	cfg := `local h2o = require "h2odin"
local config = h2o.config()
config.package = "symbol_collision"
config.foreign.import_lib = "symbol_collision"
config.inputs = { "input.h" }
config.output_folder = "."
config.type_mode = "abi"
config.naming.strip_prefixes = { proc = { "gl_", "vk_" } }
config.diagnostics.symbol_collision = "warn"
return config
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-collision-warn/H2Odin.lua", cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", cfg_dir}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	expect_contains(t, stdout, "Open :: proc")
	expect_contains(t, stderr, "warning[symbol_collision]:")
}
