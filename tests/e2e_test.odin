package h2odin_e2e

import "core:os"
import "core:strings"
import "core:testing"

run_h2odin :: proc(t: ^testing.T, command: []string) -> ([]byte, []byte, bool) {
	state, stdout, stderr, err := os.process_exec(os.Process_Desc{command = command}, context.allocator)
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
	state, stdout, stderr, err := os.process_exec(os.Process_Desc{command = command}, context.allocator)
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

@(test)
test_add_fixture_abi_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/add.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/add_idiomatic.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/idiomatic.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/basic.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/keywords.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/declarative.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/keep.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/pointers.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Generated code stays on stdout; the report is a single stderr block.
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/extern_arrays.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/pointers.lua", "-quiet"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/diag_pointer_error.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/bad_type_map.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/unknown_key.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/unsupported_key.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m9_macros.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Grouped integer macros become an explicit-valued enum; originals dropped.
	expect_contains(t, stdout, "Result_Code :: enum")
	expect_contains(t, stdout, "OK = 0")
	expect_contains(t, stdout, "ERR = 1")
	expect_contains(t, stdout, "ROW = 100")
	expect_not_contains(t, stdout, "LIB_OK ::")
	// Excluded prefix stays as standalone consts; non-integers are not enum members.
	expect_contains(t, stdout, "LIB_OPEN_RO ::")
	expect_contains(t, stdout, "LIB_TITLE ::")
}

@(test)
test_m9_enum_policies_anonymous_member_bit_set :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m9_enums.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Keyboard_Key :: enum")
	expect_contains(t, stdout, "NULL = 0")
	// FLAG_COUNT removed by enums.member; remaining flags log2'd.
	expect_contains(t, stdout, "Config_Flag :: enum")
	expect_contains(t, stdout, "VSYNC = 0")
	expect_contains(t, stdout, "FULLSCREEN = 1")
	expect_contains(t, stdout, "MSAA = 2")
	expect_not_contains(t, stdout, "COUNT")
	expect_contains(t, stdout, "Config_Flags :: bit_set[Config_Flag; u32]")
}

@(test)
test_m9_naming_overrides_and_remove_tiers :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m9_naming.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/bad_parse.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m10_structs.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m10_inputs.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m13_sibling.lua"}
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

@(test)
test_m13_non_input_include_typedef_peels :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m13_peel.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m13p")
	expect_not_contains(t, stdout, "Hidden_Id")
	expect_contains(t, stdout, "m13_use_hidden :: proc(id: c.int)")
}

@(test)
test_m10_preprocess_include_and_define :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m10_preprocess.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/m10_output.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/docs.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/no_comments.lua"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/bit_fields.lua"}
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

	override_cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/bit_fields_override.lua"}
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

	cmd := [?]string{"build/h2odin", "-config:/tmp/h2odin-imports-file-reject.lua"}
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

	cmd := [?]string{"build/h2odin", "-config:/tmp/h2odin-m14-nofolder.lua"}
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

	cmd := [?]string{"build/h2odin", "-config:/tmp/h2odin-m14-bad-layout.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "output.layout")
}
