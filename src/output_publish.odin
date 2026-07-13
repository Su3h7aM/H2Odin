package h2odin

import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

write_emit_result :: proc(result: Emit_Result, policy: ^Policy, destination: Output_Destination) -> bool {
	switch destination {
	case .Stdout:
		return write_emit_to_stdout(result, policy)
	case .Config:
		return write_emit_to_config_folder(result, policy)
	}
	return false
}

write_emit_to_stdout :: proc(result: Emit_Result, policy: ^Policy) -> bool {
	// Stdout only makes sense for a single merged unit.
	if len(result.files) != 1 {
		user_error("h2odin: -destination:stdout requires a single output unit (use output.layout = \"merged\")")
		return false
	}
	text := result.files[0].content
	if policy.footer_per_header {
		footer := load_footer(policy, result.files[0].stem)
		if footer != "" {
			text = strings.concatenate({text, footer}, context.temp_allocator)
		}
	}
	fmt.print(text)
	return true
}

// Manifest of basenames last published into output_folder. Used only for
// stale cleanup of *generator-owned* files; hand-written siblings are never
// listed and therefore never deleted.
GENERATED_MANIFEST_NAME :: ".h2odin-generated"
STAGE_DIR_NAME :: ".h2odin-stage"

write_emit_to_config_folder :: proc(result: Emit_Result, policy: ^Policy) -> bool {
	// Relative output_folder resolves against the config directory (same as inputs).
	output_folder := resolve_path(policy.output_folder, policy.config_dir) or_return

	if output_folder == "" {
		user_error("h2odin: no config.output_folder set; set it in the Lua config or use -destination:stdout")
		return false
	}

	if err := os.make_directory_all(output_folder); err != nil {
		if !os.is_dir(output_folder) {
			user_errorf("h2odin: cannot create output_folder %q: %v", output_folder, err)
			return false
		}
	}

	// Stage under output_folder so renames stay on one filesystem. Leftover
	// stage from a crashed run is discarded before we begin.
	// Ephemeral join paths use temp_allocator (not the generation arena) so
	// unit tests without an arena stay leak-clean.
	stage_dir, stage_path_error := filepath.join({output_folder, STAGE_DIR_NAME}, context.temp_allocator)
	if stage_path_error != nil {
		user_errorf("h2odin: cannot join stage path under %q: %v", output_folder, stage_path_error)
		return false
	}
	_ = os.remove_all(stage_dir)
	if err := os.make_directory_all(stage_dir); err != nil {
		user_errorf("h2odin: cannot create stage directory %q: %v", stage_dir, err)
		return false
	}
	completed := false
	defer if !completed {
		_ = os.remove_all(stage_dir)
	}

	// Render fully into the stage first — never touch published paths until
	// every unit and the new manifest are ready.
	new_filenames, staged_manifest := stage_emit_result(result, policy, stage_dir) or_return

	// Snapshot prior generator-owned basenames before we replace them.
	old_filenames := read_generated_manifest(output_folder, context.temp_allocator)
	publish_staged_generation(stage_dir, output_folder, staged_manifest, new_filenames) or_return

	// Stale cleanup: only basenames the previous manifest listed.
	remove_stale_generated_files(output_folder, old_filenames, new_filenames)

	_ = os.remove_all(stage_dir)
	completed = true
	return true
}

// Render every generated unit and its ownership manifest before publication
// starts. This keeps failures during rendering from disturbing prior output.
stage_emit_result :: proc(result: Emit_Result, policy: ^Policy, stage_dir: string) -> (filenames: []string, manifest_path: string, ok: bool) {
	filenames = make([]string, len(result.files), context.temp_allocator)
	for file, i in result.files {
		text := file.content
		if policy.footer_per_header {
			footer := load_footer(policy, file.stem)
			if footer != "" {
				text = strings.concatenate({text, footer}, context.temp_allocator)
			}
		}
		stage_path, path_error := filepath.join({stage_dir, file.filename}, context.temp_allocator)
		if path_error != nil {
			user_errorf("h2odin: cannot join stage file path: %v", path_error)
			return nil, "", false
		}
		if write_error := os.write_entire_file(stage_path, text); write_error != nil {
			user_errorf("h2odin: failed to stage %q: %v", stage_path, write_error)
			return nil, "", false
		}
		filenames[i] = file.filename
	}

	manifest_text := format_generated_manifest(filenames)
	staged_manifest_path, path_error := filepath.join({stage_dir, GENERATED_MANIFEST_NAME}, context.temp_allocator)
	if path_error != nil {
		user_errorf("h2odin: cannot join stage manifest path: %v", path_error)
		return nil, "", false
	}
	if write_error := os.write_entire_file(staged_manifest_path, manifest_text); write_error != nil {
		user_errorf("h2odin: failed to stage manifest: %v", write_error)
		return nil, "", false
	}
	return filenames, staged_manifest_path, true
}

// Publish the staged generation. The manifest moves last so it never claims a
// generation whose files were not all published.
publish_staged_generation :: proc(stage_dir, output_folder, staged_manifest: string, filenames: []string) -> bool {
	for filename in filenames {
		source_path, source_path_error := filepath.join({stage_dir, filename}, context.temp_allocator)
		destination_path, destination_path_error := filepath.join({output_folder, filename}, context.temp_allocator)
		if source_path_error != nil || destination_path_error != nil {
			user_error("h2odin: cannot join publish paths")
			return false
		}
		publish_file(source_path, destination_path) or_return
	}
	destination_manifest, path_error := filepath.join({output_folder, GENERATED_MANIFEST_NAME}, context.temp_allocator)
	if path_error != nil {
		user_errorf("h2odin: cannot join manifest path: %v", path_error)
		return false
	}
	return publish_file(staged_manifest, destination_manifest)
}

// Move source_path onto destination_path. Remove an existing destination first
// so rename is portable across hosts that refuse to overwrite.
publish_file :: proc(source_path, destination_path: string) -> bool {
	if os.exists(destination_path) {
		if error := os.remove(destination_path); error != nil {
			user_errorf("h2odin: cannot replace %q: %v", destination_path, error)
			return false
		}
	}
	if error := os.rename(source_path, destination_path); error != nil {
		user_errorf("h2odin: cannot publish %q → %q: %v", source_path, destination_path, error)
		return false
	}
	return true
}

format_generated_manifest :: proc(filenames: []string, allocator := context.temp_allocator) -> string {
	builder: strings.Builder
	strings.builder_init(&builder, allocator)
	strings.write_string(&builder, "# Generated by h2odin. Lists basenames owned by the last successful run.\n")
	strings.write_string(&builder, "# Hand-written files next to these are never listed and never deleted.\n")
	for filename in filenames {
		strings.write_string(&builder, filename)
		strings.write_string(&builder, "\n")
	}
	return strings.to_string(builder)
}

// Read prior generator-owned basenames. Missing or unreadable → empty (no
// stale cleanup). Comment lines and blanks are ignored.
read_generated_manifest :: proc(output_folder: string, allocator := context.allocator) -> []string {
	manifest_path, path_error := filepath.join({output_folder, GENERATED_MANIFEST_NAME}, context.temp_allocator)
	if path_error != nil {
		return nil
	}
	manifest_data, read_error := os.read_entire_file(manifest_path, context.temp_allocator)
	if read_error != nil {
		return nil
	}
	lines: [dynamic]string
	lines.allocator = allocator
	for line in strings.split_lines(string(manifest_data), context.temp_allocator) {
		filename := strings.trim_space(line)
		if filename == "" || strings.has_prefix(filename, "#") {
			continue
		}
		// Reject path separators so a corrupt manifest cannot delete outside
		// the output folder.
		if strings.contains(filename, "/") || strings.contains(filename, "\\") {
			continue
		}
		append(&lines, strings.clone(filename, allocator))
	}
	return lines[:]
}

// Delete files that the previous run listed but this run no longer produces.
// Never deletes the new set or anything outside the prior manifest.
remove_stale_generated_files :: proc(output_folder: string, old_filenames, new_filenames: []string) {
	keep := make(map[string]bool, context.temp_allocator)
	for filename in new_filenames {
		keep[filename] = true
	}
	for filename in old_filenames {
		if keep[filename] {
			continue
		}
		path, path_error := filepath.join({output_folder, filename}, context.temp_allocator)
		if path_error != nil {
			continue
		}
		if !os.exists(path) {
			continue
		}
		if error := os.remove(path); error != nil {
			// Non-fatal: the new generation is already published.
			user_errorf("h2odin: warning: could not remove stale generated file %q: %v", path, error)
		}
	}
}

// footer_per_header: look for {stem}_footer.odin next to the output (or next
// to the config / CWD when writing to stdout) and append its contents unchanged.
load_footer :: proc(policy: ^Policy, stem: string) -> string {
	footer_name := fmt.tprintf("%s_footer.odin", stem)
	read_footer :: proc(path: string) -> string {
		data, read_error := os.read_entire_file(path, context.temp_allocator)
		if read_error != nil {
			return ""
		}
		return string(data)
	}
	if output_folder, folder_ok := resolve_path(policy.output_folder, policy.config_dir, context.temp_allocator); folder_ok && output_folder != "" {
		if footer_path, path_error := filepath.join({output_folder, footer_name}, context.temp_allocator); path_error == nil {
			if footer := read_footer(footer_path); footer != "" {
				return footer
			}
		}
	}
	if policy.config_dir != "" {
		if footer_path, path_error := filepath.join({policy.config_dir, footer_name}, context.temp_allocator); path_error == nil {
			if footer := read_footer(footer_path); footer != "" {
				return footer
			}
		}
	}
	return read_footer(footer_name)
}
