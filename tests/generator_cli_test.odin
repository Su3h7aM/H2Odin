package h2odin_e2e

import "core:os"
import "core:strings"
import "core:testing"

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
	expect_contains(t, stderr, "warning[pointer_lowering_guess]")
	// Verbose expands every site and prints shared guidance once.
	expect_contains(t, stderr, `function "fill" parameter "out"`)
	expect_contains(t, stderr, "cause:")
	expect_contains(t, stderr, "fix:")
	expect_contains(t, stderr, "procs.params")
	// -verbose also prints linked libclang + resource-dir provenance.
	expect_contains(t, stderr, "h2odin: libclang:")
	expect_contains(t, stderr, "h2odin: resource-dir:")
}
