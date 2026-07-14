package h2odin

import "core:path/filepath"
import "core:strings"

resolve_input_headers :: proc(policy: ^Policy) -> (headers: []string, ok: bool) {
	if len(policy.inputs) == 0 {
		user_error("h2odin: config.inputs is empty (list at least one header path)")
		return nil, false
	}
	headers = make([]string, len(policy.inputs))
	for path, i in policy.inputs {
		headers[i] = resolve_path(path, policy.config_dir) or_return
	}
	return headers, true
}

resolve_paths :: proc(paths: []string, base_dir: string) -> (resolved_paths: []string, ok: bool) {
	if len(paths) == 0 {
		return nil, true
	}
	resolved_paths = make([]string, len(paths))
	for path, i in paths {
		resolved_paths[i] = resolve_path(path, base_dir) or_return
	}
	return resolved_paths, true
}

// Resolve all Extraction inputs once, before libclang is created. A command-line
// resource directory overrides the config value.
resolve_extract_preprocess :: proc(policy: ^Policy, resource_dir_override: string) -> (preprocess: Extract_Preprocess, ok: bool) {
	include_paths := resolve_paths(policy.include_paths, policy.config_dir) or_return

	resource_dir := resource_dir_override
	if resource_dir == "" {
		resource_dir = policy.resource_dir
	}
	if resource_dir != "" {
		resource_dir = resolve_path(resource_dir, policy.config_dir) or_return
	}

	return Extract_Preprocess {
			include_paths = include_paths,
			defines = policy.defines,
			resource_dir = resource_dir,
			clang_executable = policy.clang_executable,
		},
		true
}

// Build Emission's complete option set. Package and shorthand library defaults
// come from the first configured input header.
resolve_emit_options :: proc(policy: ^Policy, first_header_path: string) -> (options: Emit_Options, ok: bool) {
	header_stem := filepath.stem(filepath.base(first_header_path))
	package_name, foreign_lib := resolve_emit_names(policy, header_stem) or_return
	return Emit_Options {
			package_name = package_name,
			foreign_lib = foreign_lib,
			foreign_targets = policy.foreign_targets,
			link_prefix = policy.foreign_link_prefix,
			procedures_at_end = policy.procedures_at_end,
			emit_comments = policy.emit_comments,
		},
		true
}

// Resolve package and foreign-lib names for emission. Explicit config values
// fail closed when invalid; stem defaults are sanitized into legal forms.
// When foreign.targets is set, foreign_lib is unused (left empty).
resolve_emit_names :: proc(policy: ^Policy, header_stem: string) -> (package_name, foreign_lib: string, ok: bool) {
	if policy.package_name != "" {
		if !is_odin_identifier(policy.package_name) {
			user_errorf(
				"h2odin: config.package %q is not a valid Odin package identifier (letter/underscore then alphanumerics/underscores, not a keyword)",
				policy.package_name,
			)
			return "", "", false
		}
		package_name = policy.package_name
	} else {
		package_name = sanitize_package_stem(header_stem)
		if package_name == "" {
			package_name = "bindings"
		}
	}

	if len(policy.foreign_targets) > 0 {
		// Structured targets supply every foreign import path; no shorthand.
		return package_name, "", true
	}

	if policy.foreign_lib != "" {
		if !is_safe_foreign_path(policy.foreign_lib) {
			user_errorf("h2odin: config.foreign.import_lib %q is empty or contains a quote, backslash, or control character", policy.foreign_lib)
			return "", "", false
		}
		foreign_lib = policy.foreign_lib
	} else {
		// system: path is a string, not an identifier — keep the stem as-is
		// when non-empty (hyphens are fine); fall back to a generic name.
		foreign_lib = header_stem if is_safe_foreign_path(header_stem) else "lib"
	}
	return package_name, foreign_lib, true
}

// Legal non-keyword Odin identifier: [A-Za-z_][A-Za-z0-9_]*.
is_odin_identifier :: proc(name: string) -> bool {
	if name == "" || is_odin_keyword(name) {
		return false
	}
	if !is_ascii_alpha(name[0]) && name[0] != '_' {
		return false
	}
	for character_index in 1 ..< len(name) {
		character := name[character_index]
		if !is_ascii_alpha(character) && !is_ascii_digit(character) && character != '_' {
			return false
		}
	}
	return true
}

// Default package name from a header stem (e.g. "my-library.h" → "my_library").
// Hyphens and other non-identifier characters become underscores; leading
// digits get a leading underscore; empty collapses later to "bindings";
// keyword collisions get a trailing underscore.
sanitize_package_stem :: proc(stem: string) -> string {
	if stem == "" {
		return ""
	}
	name_bytes := make([dynamic]u8, 0, len(stem) + 1, context.temp_allocator)
	for character_index in 0 ..< len(stem) {
		character := stem[character_index]
		if is_ascii_alpha(character) || is_ascii_digit(character) || character == '_' {
			append(&name_bytes, character)
		} else if len(name_bytes) == 0 || name_bytes[len(name_bytes) - 1] != '_' {
			append(&name_bytes, '_')
		}
	}
	// Trim separators produced by trailing non-identifier characters.
	for len(name_bytes) > 0 && name_bytes[len(name_bytes) - 1] == '_' {
		pop(&name_bytes)
	}
	if len(name_bytes) == 0 {
		return ""
	}
	if is_ascii_digit(name_bytes[0]) {
		inject_at(&name_bytes, 0, '_')
	}
	name := string(name_bytes[:])
	if is_odin_keyword(name) {
		return strings.concatenate({name, "_"}, context.temp_allocator)
	}
	return name
}

// Absolute paths stay as-is; relative paths join base_dir when non-empty.
// Join failure is fatal — a silent cwd-relative fallback can pick the wrong
// header or output directory.
resolve_path :: proc(path: string, base_dir: string, allocator := context.allocator) -> (resolved: string, ok: bool) {
	if path == "" || filepath.is_abs(path) || base_dir == "" {
		return path, true
	}
	joined_path, join_error := filepath.join({base_dir, path}, allocator)
	if join_error != nil {
		user_errorf("h2odin: cannot join path %q with base %q: %v", path, base_dir, join_error)
		return "", false
	}
	return joined_path, true
}
