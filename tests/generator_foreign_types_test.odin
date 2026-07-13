package h2odin_e2e

import "core:os"
import "core:testing"

@(test)
test_foreign_targets_emits_when_chain :: proc(t: ^testing.T) {
	// Structured foreign.targets → deterministic when/else; package checks on
	// host plus Windows and Linux targets (paths need not exist for check).
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/foreign_targets.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "when ODIN_OS == .Windows {")
	expect_contains(t, stdout, `"lib/foo.lib"`)
	expect_contains(t, stdout, `"system:user32.lib"`)
	expect_contains(t, stdout, "} else when ODIN_OS == .Linux && ODIN_ARCH == .amd64 {")
	expect_contains(t, stdout, `"lib/libfoo.a"`)
	expect_contains(t, stdout, `"system:pthread"`)
	expect_contains(t, stdout, "} else {")
	expect_contains(t, stdout, `foreign import lib "system:foo"`)
	// Shorthand system: path must not appear when targets are set.
	expect_not_contains(t, stdout, `foreign import lib "system:ftargs"`)
	expect_contains(t, stdout, "add :: proc")

	out_dir := "/tmp/h2odin-foreign-targets-check"
	check_generated_output(t, stdout, out_dir)
	check_generated_output_target(t, out_dir, "windows_amd64")
	check_generated_output_target(t, out_dir, "linux_amd64")
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

// Named POSIX/libc scalars keep one spelling in both type modes —
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
