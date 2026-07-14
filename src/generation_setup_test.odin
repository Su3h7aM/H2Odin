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

@(test)
test_emission_name_validation_and_stem_sanitization :: proc(t: ^testing.T) {
	testing.expect(t, is_odin_identifier("mylib"))
	testing.expect(t, is_odin_identifier("_private"))
	testing.expect(t, !is_odin_identifier(""))
	testing.expect(t, !is_odin_identifier("my-library"))
	testing.expect(t, !is_odin_identifier("2bad"))
	testing.expect(t, !is_odin_identifier("package"))

	testing.expect_value(t, sanitize_package_stem("my-library"), "my_library")
	testing.expect_value(t, sanitize_package_stem("lib.foo"), "lib_foo")
	testing.expect_value(t, sanitize_package_stem("2d_math"), "_2d_math")
	testing.expect_value(t, sanitize_package_stem("map"), "map_")
	testing.expect_value(t, sanitize_package_stem(""), "")
	testing.expect_value(t, sanitize_package_stem("---"), "")
}

@(test)
test_resolve_emit_options_rejects_invalid_explicit_names :: proc(t: ^testing.T) {
	invalid_package := Policy {
		package_name = "not-a-package",
	}
	_, package_ok := resolve_emit_options(&invalid_package, "library.h")
	testing.expect(t, !package_ok)

	invalid_library := Policy {
		package_name = "library",
		foreign_lib  = "bad\"library",
	}
	_, library_ok := resolve_emit_options(&invalid_library, "library.h")
	testing.expect(t, !library_ok)
}

@(test)
test_resolve_emit_options_uses_structured_foreign_targets :: proc(t: ^testing.T) {
	targets := []Foreign_Target{{key = .Fallback, paths = {"system:library"}}}
	policy := Policy {
		foreign_targets     = targets,
		foreign_link_prefix = "lib_",
	}

	options, ok := resolve_emit_options(&policy, "library.h")
	testing.expect(t, ok)
	testing.expect_value(t, options.package_name, "library")
	testing.expect_value(t, options.foreign_lib, "")
	testing.expect_value(t, len(options.foreign_targets), 1)
	testing.expect_value(t, options.foreign_targets[0].key, Foreign_Target_Key.Fallback)
	testing.expect_value(t, options.link_prefix, "lib_")
}
