package h2odin

import "core:testing"

@(test)
test_resolve_extract_preprocess_applies_config_relative_paths_and_cli_override :: proc(t: ^testing.T) {
	context.allocator = context.temp_allocator

	policy := Policy {
		config_dir       = "/project/config",
		include_paths    = {"include", "/system/include"},
		resource_dir     = "configured-resource",
		clang_executable = "clang-20",
	}

	preprocess, ok := resolve_extract_preprocess(&policy, "cli-resource")
	testing.expect(t, ok)
	testing.expect_value(t, len(preprocess.include_paths), 2)
	testing.expect_value(t, preprocess.include_paths[0], "/project/config/include")
	testing.expect_value(t, preprocess.include_paths[1], "/system/include")
	testing.expect_value(t, preprocess.resource_dir, "/project/config/cli-resource")
	testing.expect_value(t, preprocess.clang_executable, "clang-20")
}

@(test)
test_resolve_emit_options_uses_header_stem_defaults :: proc(t: ^testing.T) {
	policy := Policy {
		procedures_at_end = true,
		emit_comments     = true,
	}

	options, ok := resolve_emit_options(&policy, "/project/include/my-library.h")
	testing.expect(t, ok)
	testing.expect_value(t, options.package_name, "my_library")
	testing.expect_value(t, options.foreign_lib, "my-library")
	testing.expect(t, options.procedures_at_end)
	testing.expect(t, options.emit_comments)
}
