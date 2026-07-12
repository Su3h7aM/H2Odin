package h2odin

import "core:strings"
import "core:testing"

@(test)
test_foreign_target_key_roundtrip :: proc(t: ^testing.T) {
	for key in Foreign_Target_Key {
		name := foreign_target_key_name(key)
		back, ok := foreign_target_key_from_name(name)
		testing.expectf(t, ok, "key %v name %q should round-trip", key, name)
		testing.expect_value(t, back, key)
	}
	_, bad := foreign_target_key_from_name("solaris_sparc")
	testing.expect(t, !bad)
}

@(test)
test_sort_foreign_targets_deterministic_order :: proc(t: ^testing.T) {
	// Insert out of order; emit order is most-specific first, fallback last.
	raw := []Foreign_Target {
		{key = .Fallback, paths = {"system:foo"}},
		{key = .Linux_Amd64, paths = {"lib/libfoo.a"}},
		{key = .Windows, paths = {"lib/foo.lib"}},
	}
	sorted := sort_foreign_targets(raw)
	defer delete(sorted)
	testing.expect_value(t, len(sorted), 3)
	testing.expect_value(t, sorted[0].key, Foreign_Target_Key.Windows)
	testing.expect_value(t, sorted[1].key, Foreign_Target_Key.Linux_Amd64)
	testing.expect_value(t, sorted[2].key, Foreign_Target_Key.Fallback)
}

@(test)
test_normalize_system_lib_path :: proc(t: ^testing.T) {
	a := normalize_system_lib_path("m")
	defer delete(a)
	testing.expect_value(t, a, "system:m")

	b := normalize_system_lib_path("system:pthread")
	defer delete(b)
	testing.expect_value(t, b, "system:pthread")
}

@(test)
test_emit_write_foreign_import_shorthand :: proc(t: ^testing.T) {
	b: strings.Builder
	defer strings.builder_destroy(&b)
	emit_write_foreign_import(&b, Emit_Options{foreign_lib = "curl"})
	text := strings.to_string(b)
	testing.expect(t, strings.contains(text, `foreign import lib "system:curl"`))
	testing.expect(t, !strings.contains(text, "when "))
}

@(test)
test_emit_write_foreign_import_targets_when_chain :: proc(t: ^testing.T) {
	targets := sort_foreign_targets(
		[]Foreign_Target {
			{key = .Windows, paths = {"lib/foo.lib", "system:user32.lib"}},
			{key = .Linux_Amd64, paths = {"lib/libfoo.a", "system:m", "system:pthread"}},
			{key = .Fallback, paths = {"system:foo"}},
		},
	)
	defer delete(targets)
	b: strings.Builder
	defer strings.builder_destroy(&b)
	emit_write_foreign_import(&b, Emit_Options{foreign_targets = targets})
	text := strings.to_string(b)

	testing.expect(t, strings.contains(text, "when ODIN_OS == .Windows {"))
	testing.expect(t, strings.contains(text, `foreign import lib {`))
	testing.expect(t, strings.contains(text, `"lib/foo.lib"`))
	testing.expect(t, strings.contains(text, `"system:user32.lib"`))
	testing.expect(t, strings.contains(text, "} else when ODIN_OS == .Linux && ODIN_ARCH == .amd64 {"))
	testing.expect(t, strings.contains(text, `"lib/libfoo.a"`))
	testing.expect(t, strings.contains(text, `"system:pthread"`))
	testing.expect(t, strings.contains(text, "} else {"))
	testing.expect(t, strings.contains(text, `foreign import lib "system:foo"`))
}

@(test)
test_emit_write_foreign_import_sole_fallback :: proc(t: ^testing.T) {
	targets := []Foreign_Target{{key = .Fallback, paths = {"system:box3d"}}}
	b: strings.Builder
	defer strings.builder_destroy(&b)
	emit_write_foreign_import(&b, Emit_Options{foreign_targets = targets})
	text := strings.to_string(b)
	testing.expect(t, strings.contains(text, `foreign import lib "system:box3d"`))
	testing.expect(t, !strings.contains(text, "when "))
}
