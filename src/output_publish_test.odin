package h2odin

import "core:os"
import "core:strings"
import "core:testing"

@(test)
test_format_and_read_generated_manifest :: proc(t: ^testing.T) {
	dir := "/tmp/h2odin-manifest-roundtrip"
	_ = os.remove_all(dir)
	testing.expect_value(t, os.make_directory_all(dir), nil)
	defer _ = os.remove_all(dir)

	text := format_generated_manifest({"a.odin", "b.odin"})
	path := strings.concatenate({dir, "/", GENERATED_MANIFEST_NAME})
	defer delete(path)
	testing.expect_value(t, os.write_entire_file(path, text), nil)

	names := read_generated_manifest(dir)
	defer {
		for n in names {
			delete(n)
		}
		delete(names)
	}
	testing.expect_value(t, len(names), 2)
	testing.expect_value(t, names[0], "a.odin")
	testing.expect_value(t, names[1], "b.odin")
}

@(test)
test_write_emit_to_config_folder_stages_and_removes_stale :: proc(t: ^testing.T) {
	dir := "/tmp/h2odin-transactional-out"
	_ = os.remove_all(dir)
	testing.expect_value(t, os.make_directory_all(dir), nil)
	defer _ = os.remove_all(dir)

	keep_path := strings.concatenate({dir, "/keep.odin"})
	defer delete(keep_path)
	stale_path := strings.concatenate({dir, "/stale.odin"})
	defer delete(stale_path)
	hand_path := strings.concatenate({dir, "/hand.odin"})
	defer delete(hand_path)
	manifest_path := strings.concatenate({dir, "/", GENERATED_MANIFEST_NAME})
	defer delete(manifest_path)
	stage_path := strings.concatenate({dir, "/", STAGE_DIR_NAME})
	defer delete(stage_path)
	new_path := strings.concatenate({dir, "/new.odin"})
	defer delete(new_path)

	// Seed a prior generation: two generator files + one hand-written file.
	testing.expect_value(t, os.write_entire_file(keep_path, "package old_keep\n"), nil)
	testing.expect_value(t, os.write_entire_file(stale_path, "package old_stale\n"), nil)
	testing.expect_value(t, os.write_entire_file(hand_path, "package hand\n"), nil)
	testing.expect_value(t, os.write_entire_file(manifest_path, format_generated_manifest({"keep.odin", "stale.odin"})), nil)

	policy := Policy {
		output_folder = dir,
	}
	result := Emit_Result {
		files = {{filename = "keep.odin", stem = "keep", content = "package keep\n"}, {filename = "new.odin", stem = "new", content = "package new\n"}},
	}
	testing.expect(t, write_emit_to_config_folder(result, &policy))

	// New set published.
	keep_data, keep_err := os.read_entire_file(keep_path, context.allocator)
	defer delete(keep_data)
	testing.expect(t, keep_err == nil)
	testing.expect(t, strings.contains(string(keep_data), "package keep"))

	new_data, new_err := os.read_entire_file(new_path, context.allocator)
	defer delete(new_data)
	testing.expect(t, new_err == nil)
	testing.expect(t, strings.contains(string(new_data), "package new"))

	// Stale generator file removed; hand-written sibling preserved.
	testing.expect(t, !os.exists(stale_path))
	testing.expect(t, os.exists(hand_path))

	// Stage directory cleaned up.
	testing.expect(t, !os.exists(stage_path))

	// Manifest lists only the new generation.
	names := read_generated_manifest(dir)
	defer {
		for n in names {
			delete(n)
		}
		delete(names)
	}
	testing.expect_value(t, len(names), 2)
	testing.expect_value(t, names[0], "keep.odin")
	testing.expect_value(t, names[1], "new.odin")
}
