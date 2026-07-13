package h2odin

import "core:testing"

@(test)
test_parse_output_destination_accepts_supported_values :: proc(t: ^testing.T) {
	destination, ok := parse_output_destination("config")
	testing.expect(t, ok)
	testing.expect_value(t, destination, Output_Destination.Config)

	destination, ok = parse_output_destination("stdout")
	testing.expect(t, ok)
	testing.expect_value(t, destination, Output_Destination.Stdout)

	_, ok = parse_output_destination("files")
	testing.expect(t, !ok)
}

@(test)
test_parse_command_line_collects_process_options :: proc(t: ^testing.T) {
	options, ok := parse_command_line({"-config:project.lua", "-destination:stdout", "-quiet", "-resource-dir:clang/include"})
	testing.expect(t, ok)
	testing.expect_value(t, options.config_path, "project.lua")
	testing.expect_value(t, options.destination, Output_Destination.Stdout)
	testing.expect(t, options.quiet)
	testing.expect(t, !options.verbose)
	testing.expect_value(t, options.resource_dir, "clang/include")
}

@(test)
test_parse_command_line_rejects_conflicting_options :: proc(t: ^testing.T) {
	_, ok := parse_command_line({"-config:project.lua", "-quiet", "-verbose"})
	testing.expect(t, !ok)

	_, ok = parse_command_line({"-config:project.lua", "project"})
	testing.expect(t, !ok)
}
