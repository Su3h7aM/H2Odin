package h2odin

import "core:fmt"
import "core:os"
import "core:testing"

write_test_config :: proc(t: ^testing.T, name: string, contents: string) -> (path: string, ok: bool) {
	path = fmt.tprintf("/tmp/h2odin-policy-test-%s.lua", name)
	err := os.write_entire_file(path, contents)
	testing.expect_value(t, err, nil)
	return path, err == nil
}

// Free strings/maps allocated by policy_load when tests do not use the
// generation arena. Lua state is closed by policy_destroy.
delete_policy_test_data :: proc(policy: ^Policy) {
	policy_free_owned(policy)
}

SECTIONED_DECLARATIVE :: `local h2o = require "h2odin"
local config = h2o.config()
config.package = "pkg"
config.foreign.import_lib = "native"
config.naming = h2o.naming.odin {
  strip_prefixes = { proc = "gl_", type = "GL", const = "GL_" },
}
config.types.overrides = { Vector2 = "[2]f32" }
config.types.distinct = { "CXIndex", "CXClientData" }
return config
`

@(test)
test_policy_load_declarative_fields :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(t, "declarative", SECTIONED_DECLARATIVE)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, policy.package_name, "pkg")
	testing.expect_value(t, policy.foreign_lib, "native")
	testing.expect(t, len(policy.strip_prefix_proc) == 1 && policy.strip_prefix_proc[0] == "gl_")
	testing.expect(t, len(policy.strip_prefix_type) == 1 && policy.strip_prefix_type[0] == "GL")
	testing.expect(t, len(policy.strip_prefix_const) == 1 && policy.strip_prefix_const[0] == "GL_")
	testing.expect_value(t, policy.type_overrides["Vector2"], "[2]f32")
	testing.expect(t, len(policy.types_distinct) == 2)
	testing.expect_value(t, policy.types_distinct[0], "CXIndex")
	testing.expect_value(t, policy.types_distinct[1], "CXClientData")
}

@(test)
test_policy_load_m10_sections :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"m10-sections",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h", "b.h" }
config.output_folder = "out"
config.preprocess.include_paths = { "include" }
config.preprocess.defines = { FEAT = "1" }
config.foreign.link_prefix = "lib_"
config.structs.fields = { ["Bone.name"] = { tag = 'fmt:"s,0"' } }
config.structs.align = { Mesh = 16 }
config.procs.params = { ["foo.x"] = { type = "i32", default = "0" } }
config.procs.results = { foo = { type = "c.int" } }
config.output.procedures_at_end = false
config.output.footer_per_header = true
config.output.layout = "merged"
config.comments = false
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect(t, len(policy.inputs) == 2 && policy.inputs[0] == "a.h")
	testing.expect_value(t, policy.output_folder, "out")
	testing.expect(t, len(policy.include_paths) == 1 && policy.include_paths[0] == "include")
	testing.expect_value(t, policy.defines["FEAT"], "1")
	testing.expect_value(t, policy.foreign_link_prefix, "lib_")
	testing.expect_value(t, policy.struct_fields["Bone.name"].tag, `fmt:"s,0"`)
	testing.expect_value(t, policy.struct_align["Mesh"], 16)
	testing.expect_value(t, policy.proc_params["foo.x"].type, "i32")
	testing.expect_value(t, policy.proc_params["foo.x"].default, "0")
	testing.expect_value(t, policy.proc_results["foo"].type, "c.int")
	testing.expect(t, !policy.procedures_at_end)
	testing.expect(t, policy.footer_per_header)
	testing.expect_value(t, policy.output_layout, Output_Layout.Merged)
	testing.expect(t, !policy.emit_comments)
}

@(test)
test_policy_load_foreign_targets :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"foreign-targets",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h" }
config.foreign.targets = {
  windows = { libraries = { "lib/foo.lib" }, system = { "user32.lib" } },
  linux_amd64 = { libraries = { "lib/libfoo.a" }, system = { "m", "pthread" } },
  fallback = { libraries = { "system:foo" } },
}
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, len(policy.foreign_targets), 3)
	// Sorted: windows, linux_amd64, fallback
	testing.expect_value(t, policy.foreign_targets[0].key, Foreign_Target_Key.Windows)
	testing.expect_value(t, len(policy.foreign_targets[0].paths), 2)
	testing.expect_value(t, policy.foreign_targets[0].paths[0], "lib/foo.lib")
	testing.expect_value(t, policy.foreign_targets[0].paths[1], "system:user32.lib")
	testing.expect_value(t, policy.foreign_targets[1].key, Foreign_Target_Key.Linux_Amd64)
	testing.expect_value(t, policy.foreign_targets[1].paths[2], "system:pthread")
	testing.expect_value(t, policy.foreign_targets[2].key, Foreign_Target_Key.Fallback)
	testing.expect_value(t, policy.foreign_targets[2].paths[0], "system:foo")
}

@(test)
test_policy_load_rejects_import_lib_with_targets :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"foreign-both",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h" }
config.foreign.import_lib = "foo"
config.foreign.targets = { fallback = { libraries = { "system:foo" } } }
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_rejects_unknown_foreign_target_key :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"foreign-bad-key",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h" }
config.foreign.targets = { beos = { libraries = { "system:foo" } } }
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_rejects_imports_file :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"imports-file-removed",
		`local h2o = require "h2odin"
local config = h2o.config()
config.output.imports_file = "imports.odin"
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, !ok)
}

@(test)
test_policy_load_output_layout_per_header :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"layout-per-header",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h" }
config.output.layout = "per_header"
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, policy.output_layout, Output_Layout.Per_Header)
}

@(test)
test_policy_load_rejects_unknown_output_layout :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"layout-bad",
		`local h2o = require "h2odin"
local config = h2o.config()
config.output.layout = "by_category"
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, !ok)
}

@(test)
test_policy_load_comments_default_true :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(t, "comments-default", `local h2o = require "h2odin"
local config = h2o.config()
return config
`)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect(t, policy.emit_comments)
}

@(test)
test_policy_load_rejects_non_bool_comments :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(t, "comments-bad", `local h2o = require "h2odin"
local config = h2o.config()
config.comments = "no"
return config
`)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_diagnostics_severity :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"diag-severity",
		`local h2o = require "h2odin"
local config = h2o.config()
config.diagnostics = {
	pointer_lowering_guess = "error",
	naming_ambiguity = "warn",
}
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, policy.diag_severity[.Pointer_Lowering_Guess], Diag_Severity.Error)
	testing.expect_value(t, policy.diag_severity[.Naming_Ambiguity], Diag_Severity.Warn)
	// Unmentioned categories keep the default warn posture.
	testing.expect_value(t, policy.diag_severity[.Opaque_Layout_Fallback], Diag_Severity.Warn)
}

@(test)
test_policy_load_rejects_unknown_diag_category :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"diag-unknown",
		`local h2o = require "h2odin"
local config = h2o.config()
config.diagnostics = { not_a_real_category = "warn" }
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_bit_set_local_diag_override :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"diag-local",
		`local h2o = require "h2odin"
local config = h2o.config()
config.diagnostics = { bit_set_non_power_of_two = "error" }
config.enums.bit_sets = {
	h2o.enum.bit_set {
		enum = "Flag",
		name = "Flags",
		mode = "log2",
		diagnostics = { bit_set_non_power_of_two = "warn" },
	},
}
return config
`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, policy.diag_severity[.Bit_Set_Non_Power_Of_Two], Diag_Severity.Error)
	testing.expect(t, len(policy.enum_bit_sets) == 1)
	sev, has := policy.enum_bit_sets[0].diag_overrides.set[.Bit_Set_Non_Power_Of_Two].?
	testing.expect(t, has)
	testing.expect_value(t, sev, Diag_Severity.Warn)
}

@(test)
test_policy_load_rejects_bad_declarative_shapes :: proc(t: ^testing.T) {
	bad_strip, bad_strip_ok := write_test_config(
		t,
		"bad-strip",
		`local h2o = require "h2odin"
local config = h2o.config()
config.naming.strip_prefixes = "bad"
return config
`,
	)
	if !bad_strip_ok {
		return
	}
	policy, ok := policy_load(bad_strip)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)

	bad_map, bad_map_ok := write_test_config(
		t,
		"bad-map",
		`local h2o = require "h2odin"
local config = h2o.config()
config.types.overrides = { Foo = 42 }
return config
`,
	)
	if !bad_map_ok {
		return
	}
	// Second load: destroy the first policy before reusing names.
	policy_destroy(&policy)
	delete_policy_test_data(&policy)
	policy, ok = policy_load(bad_map)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_rejects_wrong_string_field_types :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(t, "bad-package-type", `local h2o = require "h2odin"
local config = h2o.config()
config.package = 42
return config
`)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_rejects_non_function_callbacks :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"bad-rename-type",
		`local h2o = require "h2odin"
local config = h2o.config()
config.naming.override = "nope"
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_load_rejects_unknown_and_legacy_keys :: proc(t: ^testing.T) {
	unknown, unknown_ok := write_test_config(
		t,
		"unknown-key",
		`local h2o = require "h2odin"
local config = h2o.config()
config.typo_mode = "abi"
return config
`,
	)
	if !unknown_ok {
		return
	}
	policy, ok := policy_load(unknown)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)

	legacy, legacy_ok := write_test_config(t, "legacy-keep", `return { keep = function() return true end }`)
	if !legacy_ok {
		return
	}
	policy_destroy(&policy)
	delete_policy_test_data(&policy)
	policy, ok = policy_load(legacy)
	testing.expect(t, !ok)

	unsupported, unsupported_ok := write_test_config(
		t,
		"unsupported-key",
		`local h2o = require "h2odin"
local config = h2o.config()
config.wrappers = true
return config
`,
	)
	if !unsupported_ok {
		return
	}
	policy_destroy(&policy)
	delete_policy_test_data(&policy)
	policy, ok = policy_load(unsupported)
	testing.expect(t, !ok)
}

@(test)
test_policy_sandbox_and_h2o_require :: proc(t: ^testing.T) {
	// Sandbox: io/os/debug and raw loaders stay gone; package exists only for
	// the restricted require of h2odin + sibling .lua files.
	path, path_ok := write_test_config(
		t,
		"sandbox",
		`assert(io == nil, "io must be withheld")
assert(os == nil, "os must be withheld")
assert(debug == nil, "debug must be withheld")
assert(dofile == nil, "dofile must be withheld")
assert(loadfile == nil, "loadfile must be withheld")
assert(load == nil, "load must be withheld")
assert(type(package) == "table", "package required for require")
assert(package.loadlib == nil, "loadlib must be withheld")
assert(type(string.find) == "function")
assert(type(table.insert) == "function")
assert(type(math.abs) == "function")
assert(math.random == nil, "math.random must be withheld for determinism")
assert(math.randomseed == nil, "math.randomseed must be withheld for determinism")

local h2o = require "h2odin"
assert(type(h2o.config) == "function")
assert(h2o.str.has_prefix("sqlite3_open", "sqlite3_"))
assert(h2o.str.strip_prefix("sqlite3_open", "sqlite3_") == "open")
assert(h2o.str.has_suffix("BoneInfo", "Info"))

local config = h2o.config()
config.package = "sandboxed"
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, ok)
	testing.expect_value(t, policy.package_name, "sandboxed")
}

@(test)
test_policy_load_rejects_unknown_strip_prefix_keys :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"bad-strip-key",
		`local h2o = require "h2odin"
local config = h2o.config()
config.naming.strip_prefixes = { functions = "gl_" }
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_remove_where_polarity :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"remove-where",
		`local h2o = require "h2odin"
local config = h2o.config()
config.symbols.remove.where = function(sym)
  return h2o.str.has_prefix(sym.name, "internal_")
end
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, ok)
	testing.expect(t, policy.has_remove_where)
	testing.expect(t, policy_remove_where(&policy, Symbol_Context{name = "internal_x", default_name = "internal_x", kind = .Func}))
	testing.expect(t, !policy_remove_where(&policy, Symbol_Context{name = "public", default_name = "public", kind = .Func}))
}

@(test)
test_policy_rejects_hybrid_string_list :: proc(t: ^testing.T) {
	// { "a.h", typo = "b.h" } used to pass silently (L_len == 1, string keys
	// ignored). Pure-list validation must fail closed.
	path, path_ok := write_test_config(
		t,
		"hybrid-list",
		`local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "a.h", typo = "b.h" }
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)
}

@(test)
test_policy_remove_deprecated_and_sym_view :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"remove-deprecated",
		`local h2o = require "h2odin"
local config = h2o.config()
config.symbols.remove.deprecated = true
config.symbols.remove.where = function(sym)
  return sym.deprecated and sym.kind == "const"
end
return config
`,
	)
	if !path_ok {
		return
	}
	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, ok)
	testing.expect(t, policy.remove_deprecated)
	testing.expect(t, policy.has_remove_where)
	// where reads sym.deprecated from the view.
	testing.expect(t, policy_remove_where(&policy, Symbol_Context{name = "OLD", default_name = "OLD", kind = .Const, deprecated = true}))
	testing.expect(t, !policy_remove_where(&policy, Symbol_Context{name = "old_fn", default_name = "old_fn", kind = .Func, deprecated = true}))
	testing.expect(t, !policy_remove_where(&policy, Symbol_Context{name = "OLD", default_name = "OLD", kind = .Const, deprecated = false}))
}

@(test)
test_policy_require_sibling_module :: proc(t: ^testing.T) {
	dir := "/tmp/h2odin-policy-test-sibling-dir"
	_ = os.make_directory(dir)
	helper := fmt.tprintf("%s/helper.lua", dir)
	main_cfg := fmt.tprintf("%s/main.lua", dir)
	testing.expect(t, os.write_entire_file(helper, `return { tag = "from_helper" }`) == nil)
	testing.expect(
		t,
		os.write_entire_file(
			main_cfg,
			`local h2o = require "h2odin"
local helper = require "helper"
local config = h2o.config()
config.package = helper.tag
return config
`,
		) ==
		nil,
	)

	policy, ok := policy_load(main_cfg)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, ok)
	testing.expect_value(t, policy.package_name, "from_helper")
}
