package h2odin

import "core:path/filepath"
import "core:strings"

// Absolute + cleaned form used for source-file identity. Falls back to a
// cleaned relative path when abs is unavailable.
normalize_source_path :: proc(path: string, allocator := context.allocator) -> string {
	if path == "" {
		return ""
	}
	if absolute_path, path_error := filepath.abs(path, allocator); path_error == nil {
		if cleaned_path, clean_error := filepath.clean(absolute_path, allocator); clean_error == nil {
			return cleaned_path
		}
		return absolute_path
	}
	if cleaned_path, clean_error := filepath.clean(path, allocator); clean_error == nil {
		return cleaned_path
	}
	return path
}

// True when path is root or a descendant. Uses a separator boundary so
// "/tmp/cfg" does not match "/tmp/cfg_evil/x". No allocation.
//
// Roots that already end with a separator (including filesystem root "/")
// are treated as directory prefixes: every path that continues after that
// prefix is under the root.
path_is_under :: proc(path, root: string) -> bool {
	if path == root {
		return true
	}
	if len(root) == 0 || len(path) <= len(root) {
		return false
	}
	last := root[len(root) - 1]
	if last == '/' || last == '\\' {
		return strings.has_prefix(path, root)
	}
	if !strings.has_prefix(path, root) {
		return false
	}
	sep := path[len(root)]
	return sep == '/' || sep == '\\'
}
