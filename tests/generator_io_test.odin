package h2odin_e2e

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_multiple_input_headers_share_one_generated_package :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/multi_header_inputs.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m10i")
	expect_contains(t, stdout, "from_first_header :: proc")
	expect_contains(t, stdout, "from_second_header :: proc")
}

@(test)
test_sibling_input_typedef_keeps_its_declared_name :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/sibling_inputs.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m13s")
	expect_contains(t, stdout, "Sibling_Id ::")
	// Use site in a.h must reference the sibling typedef, not peel to c.int.
	expect_contains(t, stdout, "use_sibling_id :: proc(id: Sibling_Id)")
	expect_contains(t, stdout, "make_sibling_id :: proc")
	expect_contains(t, stdout, "SIBLING_FLAG")
	// No duplicate emission of the sibling proc.
	count := strings.count(string(stdout), "make_sibling_id :: proc")
	testing.expect_value(t, count, 1)
}

// A project header that config.inputs does not list is still ours: the
// umbrella-header pattern (Box3D lists box3d.h and reaches types.h through
// it) depends on it. Only system headers are foreign, so
// Hidden_Id keeps its name instead of peeling to the underlying builtin.
@(test)
test_unlisted_project_header_typedef_is_ours :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/transitive_typedef.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package m13p")
	expect_contains(t, stdout, "Hidden_Id :: c.int")
	expect_contains(t, stdout, "use_transitive_id :: proc(id: Hidden_Id)")
}

@(test)
test_single_root_folds_unlisted_project_header :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/roots_fold.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Folded_Id :: c.int")
	expect_contains(t, stdout, "from_folded_leaf :: proc")
	expect_contains(t, stdout, "from_root :: proc")
}

@(test)
test_project_header_outside_root_subtree_stays_unowned :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/roots_external.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "use_external_id :: proc(id: c.int)")
	expect_not_contains(t, stdout, "External_Id ::")
	expect_not_contains(t, stdout, "from_external_header :: proc")
}

@(test)
test_multiple_roots_default_to_one_output_unit_each :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-roots-auto-layout"
	_ = os.remove_all(out_dir)

	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/roots_auto_layout.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	a_data, a_err := os.read_entire_file("/tmp/h2odin-roots-auto-layout/multi_header_a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "from_first_header :: proc")
	expect_not_contains(t, a_data, "from_second_header")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-roots-auto-layout/multi_header_b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_contains(t, b_data, "from_second_header :: proc")
	expect_not_contains(t, b_data, "from_first_header")
}

@(test)
test_included_root_keeps_its_unit_and_owns_its_folded_headers :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-roots-nested"
	_ = os.remove_all(out_dir)

	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/roots_nested.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	a_data, a_err := os.read_entire_file("/tmp/h2odin-roots-nested/a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "from_nested_root_a :: proc")
	expect_not_contains(t, a_data, "from_nested_root_b")
	expect_not_contains(t, a_data, "from_nested_b_leaf")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-roots-nested/b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_contains(t, b_data, "from_nested_root_b :: proc")
	expect_contains(t, b_data, "from_nested_b_leaf :: proc")
}

@(test)
test_diamond_header_uses_first_root_and_reports_diagnostic :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-roots-diamond"
	_ = os.remove_all(out_dir)

	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/roots_diamond.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	a_data, a_err := os.read_entire_file("/tmp/h2odin-roots-diamond/a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "from_diamond_shared :: proc")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-roots-diamond/b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_not_contains(t, b_data, "from_diamond_shared")
	expect_contains(t, stderr, "warning[header_ownership_conflict]")

	error_cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/roots_diamond_error.lua"}
	_, error_stderr, code, failure_ok := run_h2odin_expect_failure(t, error_cmd[:])
	defer delete(error_stderr)
	if !failure_ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, error_stderr, "error[header_ownership_conflict]")
}

@(test)
test_preprocess_include_paths_and_defines_reach_clang :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/preprocess_options.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// -D FEATURE_ENABLED makes this declaration visible; -I finds the include.
	expect_contains(t, stdout, "enabled_by_define :: proc")
}

@(test)
test_output_policy_appends_footer_and_interleaves_procedures :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/output_options.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package output_options")
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

// C-deprecated declarations propagate as @(deprecated) / Deprecated: lines.
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
test_output_folder_writes_generated_file :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-output-folder"
	_ = os.remove_all(out_dir)

	// Config lives under /tmp, so inputs must be absolute (relative paths
	// resolve against the config directory).
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	header := strings.concatenate({cwd, "/tests/fixtures/add.h"})
	defer delete(header)

	cfg_path := "/tmp/h2odin-output-folder-config.lua"
	cfg := strings.concatenate(
		{
			`local h2o = require "h2odin"
local config = h2o.config()
config.package = "m10f"
config.foreign.import_lib = "m10f"
config.inputs = { "`,
			header,
			`" }
config.output_folder = "/tmp/h2odin-output-folder"
return config
`,
		},
	)
	defer delete(cfg)
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-config:/tmp/h2odin-output-folder-config.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	// Main goes to disk; stdout should be empty.
	testing.expect_value(t, len(stdout), 0)

	main_data, main_err := os.read_entire_file("/tmp/h2odin-output-folder/add.odin", context.allocator)
	defer delete(main_data)
	testing.expect(t, main_err == nil)
	expect_contains(t, main_data, "package m10f")
	expect_contains(t, main_data, "add :: proc")
	// Prelude (package + foreign import) lives in the same file.
	expect_contains(t, main_data, "foreign import lib")
}

@(test)
test_bit_fields_emit_only_when_layout_is_proven :: proc(t: ^testing.T) {
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
	expect_contains(t, stderr, "warning[bit_field_layout_fallback]")
	expect_not_contains(t, stderr, `record "H2O_Overlapping" field "pointer"`)

	out_dir := "/tmp/h2odin-bit-fields"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-bit-fields/generated.odin", stdout), nil)
	// Fixture keeps C field spellings; generated libclang uses Odin snake_case.
	layout_check := `package bit_fields

import clang "vendored:libclang"

#assert(size_of(H2O_IndexOptions) == size_of(clang.Index_Options))
#assert(offset_of(H2O_IndexOptions, PreambleStoragePath) == offset_of(clang.Index_Options, preamble_storage_path))
#assert(offset_of(H2O_IndexOptions, InvocationEmissionPath) == offset_of(clang.Index_Options, invocation_emission_path))
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-bit-fields/layout_check.odin", layout_check), nil)

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
		// Multi-site bit-field fallback is summarized (category + count + cause).
		expect_contains(t, override_stderr, "warning[bit_field_layout_fallback]")
		expect_contains(t, override_stderr, "×")
	}
}

@(test)
test_per_header_layout_writes_partitioned_package :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-per-header-output"
	_ = os.remove_all(out_dir)

	cmd := [?]string{"build/h2odin", "-config:tests/fixtures/configs/per_header_output.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect_value(t, len(stdout), 0)

	a_data, a_err := os.read_entire_file("/tmp/h2odin-per-header-output/per_header_a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "package per_header_output")
	expect_contains(t, a_data, "foreign import lib")
	expect_contains(t, a_data, "First_Header_Id ::")
	expect_contains(t, a_data, "from_header_a :: proc")
	expect_contains(t, a_data, "FIRST_HEADER_FLAG")
	expect_not_contains(t, a_data, "from_header_b")
	expect_not_contains(t, a_data, "Second_Header_Record")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-per-header-output/per_header_b.odin", context.allocator)
	defer delete(b_data)
	testing.expect(t, b_err == nil)
	expect_contains(t, b_data, "package per_header_output")
	expect_contains(t, b_data, "foreign import lib")
	expect_contains(t, b_data, "Second_Header_Record ::")
	expect_contains(t, b_data, "from_header_b :: proc")
	expect_not_contains(t, b_data, "from_header_a")

	empty_data, empty_err := os.read_entire_file("/tmp/h2odin-per-header-output/per_header_empty.odin", context.allocator)
	defer delete(empty_data)
	testing.expect(t, empty_err == nil)
	expect_contains(t, empty_data, "package per_header_output")
	// Function-like macros are not emitted; file is still valid Odin.
	expect_not_contains(t, empty_data, "EMPTY_HEADER_HELPER")

	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)
}

@(test)
test_per_header_layout_appends_footer_to_each_unit :: proc(t: ^testing.T) {
	out_dir := "/tmp/h2odin-per-header-footer"
	_ = os.remove_all(out_dir)

	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	a_h := strings.concatenate({cwd, "/tests/fixtures/per_header_a.h"})
	defer delete(a_h)
	b_h := strings.concatenate({cwd, "/tests/fixtures/per_header_b.h"})
	defer delete(b_h)

	// Footers live next to the config (config dir search).
	cfg_dir := "/tmp/h2odin-per-header-footer-config"
	_ = os.remove_all(cfg_dir)
	testing.expect_value(t, os.make_directory_all(cfg_dir), nil)
	footer_a, fa_err := os.read_entire_file("tests/fixtures/configs/per_header_a_footer.odin", context.allocator)
	defer delete(footer_a)
	testing.expect(t, fa_err == nil)
	footer_b, fb_err := os.read_entire_file("tests/fixtures/configs/per_header_b_footer.odin", context.allocator)
	defer delete(footer_b)
	testing.expect(t, fb_err == nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-per-header-footer-config/per_header_a_footer.odin", footer_a), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-per-header-footer-config/per_header_b_footer.odin", footer_b), nil)

	cfg := strings.concatenate(
		{
			`local h2o = require "h2odin"
local config = h2o.config()
config.package = "per_header_footer"
config.foreign.import_lib = "per_header_footer"
config.inputs = { "`,
			a_h,
			`", "`,
			b_h,
			`" }
config.output_folder = "/tmp/h2odin-per-header-footer"
config.output.layout = "per_header"
config.output.footer_per_header = true
return config
`,
		},
	)
	defer delete(cfg)
	cfg_path := "/tmp/h2odin-per-header-footer-config/config.lua"
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

	a_data, a_err := os.read_entire_file("/tmp/h2odin-per-header-footer/per_header_a.odin", context.allocator)
	defer delete(a_data)
	testing.expect(t, a_err == nil)
	expect_contains(t, a_data, "FOOTER_A_MARKER")
	expect_not_contains(t, a_data, "FOOTER_B_MARKER")

	b_data, b_err := os.read_entire_file("/tmp/h2odin-per-header-footer/per_header_b.odin", context.allocator)
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
test_multiple_output_units_reject_stdout :: proc(t: ^testing.T) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)

	header_a := strings.concatenate({cwd, "/tests/fixtures/per_header_a.h"})
	defer delete(header_a)
	header_b := strings.concatenate({cwd, "/tests/fixtures/per_header_b.h"})
	defer delete(header_b)
	cfg := strings.concatenate(
		{`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "`, header_a, `", "`, header_b, `" }
return config
`},
	)
	defer delete(cfg)
	cfg_path := "/tmp/h2odin-per-header-no-folder.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:/tmp/h2odin-per-header-no-folder.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "requires a single output unit")
	expect_contains(t, stderr, "output.layout = \"merged\"")
}

@(test)
test_unknown_output_layout_is_rejected_during_config_load :: proc(t: ^testing.T) {
	cfg := `local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "x.h" }
config.output.layout = "by_category"
return config
`
	cfg_path := "/tmp/h2odin-unknown-output-layout.lua"
	testing.expect_value(t, os.write_entire_file(cfg_path, cfg), nil)

	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:/tmp/h2odin-unknown-output-layout.lua"}
	_, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)
	expect_contains(t, stderr, "output.layout")
}
