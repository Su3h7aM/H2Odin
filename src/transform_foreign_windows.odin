#+build windows
package h2odin

import "core:c/libc"
import "core:strings"
import win32 "core:sys/windows"

// core:sys/posix is undefined on Windows. libc.* rows stay portable; socket
// compounds that core:sys/windows exports become win32.* (vendor:curl style).
// Pure-POSIX names without a win32 counterpart fall through to the
// stub/diagnostic path or types.map.
platform_spelling_supported :: proc(spelling: string) -> bool {
	return strings.has_prefix(spelling, "libc.") || strings.has_prefix(spelling, "win32.")
}

// Resolve the map entry to a spelling that exists on this Windows host.
// Compounds with a win32 export use that package; remaining posix.* names
// return "" so platform_spelling can diagnose rather than emit a dead name.
platform_foreign_spelling :: proc(entry: Foreign_Type_Entry) -> string {
	if s, ok := windows_compound_spelling(entry.c_name); ok {
		return s
	}
	if strings.has_prefix(entry.spelling, "posix.") {
		return ""
	}
	return entry.spelling
}

// Width source for scalar map entries on Windows. Compounds are not
// width-guarded. win32.socklen_t is available if added as a scalar later.
platform_type_size :: proc(spelling: string) -> int {
	switch spelling {
	case "libc.time_t":
		return size_of(libc.time_t)
	case "libc.clock_t":
		return size_of(libc.clock_t)
	case "win32.socklen_t":
		return size_of(win32.socklen_t)
	}
	return -1
}
