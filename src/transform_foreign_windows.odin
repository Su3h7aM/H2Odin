#+build windows
package h2odin

import "core:c/libc"
import "core:strings"

// core:sys/posix is undefined on Windows targets: only the libc rows of the
// built-in map may be used. Compounds (sockaddr, …) fall back to the stub /
// diagnostic path, which is honest, rather than naming a type that does not
// exist.
platform_spelling_supported :: proc(spelling: string) -> bool {
	return strings.has_prefix(spelling, "libc.")
}

// Windows counterpart of the Unix width source. core:sys/posix is undefined
// on Windows targets, so the posix.* rows of the built-in map do not apply
// here — returning -1 makes them diagnose and keep the C spelling rather than
// emit a name that does not exist (spec 0010, decision 8). core:c/libc is
// portable, so the libc rows still map. Windows platform types (win32.*) are
// config's job until a Windows validation target exists.
platform_type_size :: proc(spelling: string) -> int {
	switch spelling {
	case "libc.time_t":
		return size_of(libc.time_t)
	case "libc.clock_t":
		return size_of(libc.clock_t)
	}
	return -1
}
