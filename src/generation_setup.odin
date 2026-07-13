package h2odin

import "core:fmt"
import "core:path/filepath"

resolve_input_headers :: proc(policy: ^Policy) -> (headers: []string, ok: bool) {
	if len(policy.inputs) == 0 {
		fmt.eprintln("h2odin: config.inputs is empty (list at least one header path)")
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
resolve_emit_options :: proc(policy: ^Policy, first_header: string) -> (options: Emit_Options, ok: bool) {
	header_stem := filepath.stem(filepath.base(first_header))
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
resolve_emit_names :: proc(policy: ^Policy, stem: string) -> (package_name, foreign_lib: string, ok: bool) {
	if policy.package_name != "" {
		if !is_odin_identifier(policy.package_name) {
			fmt.eprintfln(
				"h2odin: config.package %q is not a valid Odin package identifier (letter/underscore then alphanumerics/underscores, not a keyword)",
				policy.package_name,
			)
			return "", "", false
		}
		package_name = policy.package_name
	} else {
		package_name = sanitize_package_stem(stem)
		if package_name == "" {
			package_name = "bindings"
		}
	}

	if len(policy.foreign_targets) > 0 {
		// Structured targets supply every foreign import path; no shorthand.
		return package_name, "", true
	}

	if policy.foreign_lib != "" {
		if !is_safe_foreign_lib(policy.foreign_lib) {
			fmt.eprintfln("h2odin: config.foreign.import_lib %q is empty or contains a quote, backslash, or control character", policy.foreign_lib)
			return "", "", false
		}
		foreign_lib = policy.foreign_lib
	} else {
		// system: path is a string, not an identifier — keep the stem as-is
		// when non-empty (hyphens are fine); fall back to a generic name.
		foreign_lib = stem if is_safe_foreign_lib(stem) else "lib"
	}
	return package_name, foreign_lib, true
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
		fmt.eprintfln("h2odin: cannot join path %q with base %q: %v", path, base_dir, join_error)
		return "", false
	}
	return joined_path, true
}
