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
	cmd := [?]string{"build/h2odin", "tests/fixtures/add.h"}
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
	cmd := [?]string{"build/h2odin", "-mode:idiomatic", "tests/fixtures/add.h"}
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
	cmd := [?]string{"build/h2odin", "-mode:idiomatic", "tests/fixtures/idiomatic.h"}
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
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/basic.lua", "tests/fixtures/add.h"}
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
	cmd := [?]string{"build/h2odin", "tests/fixtures/keywords.h"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "@(link_name = \"matrix\")")
	expect_contains(t, stdout, "matrix_: [16]c.float")
	expect_contains(t, stdout, "map_ :: struct")
	expect_contains(t, stdout, "context_: c.int")
}

@(test)
test_declarative_config_applies_prefixes_and_type_map :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/declarative.lua", "tests/fixtures/declarative.h"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "MAX_POINTS :: 64")
	expect_contains(t, stdout, "@(link_name = \"gl_Distance\")")
	expect_contains(t, stdout, "Distance :: proc(a: [2]f32, b: [2]f32) -> c.int ---")
	expect_not_contains(t, stdout, "gl_Vector2 :: struct")
	expect_not_contains(t, stdout, "Vector2 ::")
}

@(test)
test_keep_config_filters_top_level_decls :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/keep.lua", "tests/fixtures/filtering.h"}
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
	cmd := [?]string{"build/h2odin", "tests/fixtures/pointers.h"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Generated code stays on stdout; the report is a single stderr block.
	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
	expect_contains(t, stderr, `guessed pointer lowering in function "make_row" return type: defaulted to ^T`)
	// Proven lowerings (void*, const char*, function pointers) must not appear.
	expect_not_contains(t, stderr, `function "on_event"`)
	expect_not_contains(t, stderr, `function "log_fmt"`)
}

@(test)
test_diagnostics_report_lists_unknown_size_extern_arrays :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "tests/fixtures/extern_arrays.h"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "version:")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, `extern array "version" has unknown size; emitted as [0]T`)
	expect_contains(t, stderr, `extern array "values" has unknown size; emitted as [0]T`)
	// Known bounds are certain — no note for them.
	expect_not_contains(t, stderr, "known_values")
}

@(test)
test_bad_config_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/bad_type_map.lua", "tests/fixtures/add.h"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, "type_map[\"Foo\"] must be a string")
}

@(test)
test_parse_error_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "tests/fixtures/bad_parse.h"}
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
