#+build !windows
package h2odin

import "core:c/libc"
import "core:sys/posix"

// Odin-side width of a built-in map spelling on the generation target, or -1
// when the target does not define it. size_of on the
// real Odin type is the only honest source: core:sys/posix encodes the
// per-OS widths itself (pid_t is c.int32_t on Darwin/BSD, c.int on Linux),
// and restating them here would be the duplication the spec rejects.
//
// The posix package is Unix-only, so this file is; see the windows build for
// the portable libc subset plus win32 compounds. Host == generation target
// until cross-target generation exists.
platform_spelling_supported :: proc(spelling: string) -> bool {
	return true // both core:sys/posix and core:c/libc exist on Unix targets
}

// Unix hosts use the map entry spelling as-is (posix.* / libc.*).
platform_foreign_spelling :: proc(entry: Foreign_Type_Entry) -> string {
	return entry.spelling
}

platform_type_size :: proc(spelling: string) -> int {
	switch spelling {
	case "posix.dev_t":
		return size_of(posix.dev_t)
	case "posix.blkcnt_t":
		return size_of(posix.blkcnt_t)
	case "posix.blksize_t":
		return size_of(posix.blksize_t)
	case "posix.fsblkcnt_t":
		return size_of(posix.fsblkcnt_t)
	case "posix.off_t":
		return size_of(posix.off_t)
	case "posix.gid_t":
		return size_of(posix.gid_t)
	case "posix.pid_t":
		return size_of(posix.pid_t)
	case "posix.clockid_t":
		return size_of(posix.clockid_t)
	case "posix.socklen_t":
		return size_of(posix.socklen_t)
	case "libc.time_t":
		return size_of(libc.time_t)
	case "libc.clock_t":
		return size_of(libc.clock_t)
	}
	return -1
}
