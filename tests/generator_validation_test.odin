package h2odin_e2e

import "core:os"
import "core:strings"
import "core:testing"

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

// Package-scope collision after strip_prefixes.
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
	expect_contains(t, stderr, "error[symbol_collision]")
	expect_contains(t, stderr, `package-scope name "Open"`)
}

// Field name shadows a type used again in the same record.
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
	expect_contains(t, stderr, "error[symbol_collision]")
	expect_contains(t, stderr, "shadows type")
	expect_contains(t, stderr, "format")
}

// Parameter name shadows a type used by a later parameter.
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
	expect_contains(t, stderr, "error[symbol_collision]")
	expect_contains(t, stderr, "parameter")
	expect_contains(t, stderr, "httppost")
}

// Downgrading the collision to a warning still emits and succeeds.
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
	expect_contains(t, stderr, "warning[symbol_collision]")
}
