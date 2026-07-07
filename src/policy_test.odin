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

delete_policy_test_data :: proc(policy: ^Policy) {
	if policy.package_name != "" {
		delete(policy.package_name)
	}
	if policy.foreign_lib != "" {
		delete(policy.foreign_lib)
	}
	if policy.strip_prefix_func != "" {
		delete(policy.strip_prefix_func)
	}
	if policy.strip_prefix_type != "" {
		delete(policy.strip_prefix_type)
	}
	if policy.strip_prefix_const != "" {
		delete(policy.strip_prefix_const)
	}
	if policy.type_map != nil {
		for key, value in policy.type_map {
			delete(key)
			delete(value)
		}
		delete(policy.type_map)
	}
}

@(test)
test_policy_load_declarative_fields :: proc(t: ^testing.T) {
	path, path_ok := write_test_config(
		t,
		"declarative",
		`return {
  package = "pkg",
  foreign_lib = "native",
  strip_prefixes = { func = "gl_", type = "GL", const = "GL_" },
  type_map = { Vector2 = "[2]f32" },
}`,
	)
	if !path_ok {
		return
	}

	policy, ok := policy_load(path)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)

	testing.expect(t, ok)
	testing.expect_value(t, policy.package_name, "pkg")
	testing.expect_value(t, policy.foreign_lib, "native")
	testing.expect_value(t, policy.strip_prefix_func, "gl_")
	testing.expect_value(t, policy.strip_prefix_type, "GL")
	testing.expect_value(t, policy.strip_prefix_const, "GL_")
	testing.expect_value(t, policy.type_map["Vector2"], "[2]f32")
}

@(test)
test_policy_load_rejects_bad_declarative_shapes :: proc(t: ^testing.T) {
	bad_strip, bad_strip_ok := write_test_config(t, "bad-strip", `return { strip_prefixes = "bad" }`)
	if !bad_strip_ok {
		return
	}
	policy, ok := policy_load(bad_strip)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)

	bad_map, bad_map_ok := write_test_config(t, "bad-map", `return { type_map = { Foo = 42 } }`)
	if !bad_map_ok {
		return
	}
	policy, ok = policy_load(bad_map)
	defer policy_destroy(&policy)
	defer delete_policy_test_data(&policy)
	testing.expect(t, !ok)

}
