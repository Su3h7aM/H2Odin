package h2odin

import "core:strings"
import "core:testing"

@(test)
test_windows_compound_spelling_corpus_names :: proc(t: ^testing.T) {
	// Names core:sys/windows exports — used on Windows hosts for the
	// built-in foreign map. Pure function so Unix CI can still lock the list.
	cases := [?]struct {
		c_name:   string,
		spelling: string,
	} {
		{"sockaddr", "win32.sockaddr"},
		{"sockaddr_in", "win32.sockaddr_in"},
		{"sockaddr_in6", "win32.sockaddr_in6"},
		{"in_addr", "win32.in_addr"},
		{"in6_addr", "win32.in6_addr"},
		{"fd_set", "win32.fd_set"},
		{"timeval", "win32.timeval"},
		{"socklen_t", "win32.socklen_t"},
	}
	for c in cases {
		s, ok := windows_compound_spelling(c.c_name)
		testing.expectf(t, ok, "expected win32 spelling for %q", c.c_name)
		testing.expect_value(t, s, c.spelling)
	}
	_, absent := windows_compound_spelling("sockaddr_storage")
	testing.expect(t, !absent)
	_, pure_posix := windows_compound_spelling("pid_t")
	testing.expect(t, !pure_posix)
}

@(test)
test_note_import_for_spelling_tracks_win32 :: proc(t: ^testing.T) {
	imports: Emit_Imports
	note_import_for_spelling(&imports, "win32.sockaddr")
	testing.expect(t, imports.win32)
	testing.expect(t, !imports.posix)

	b: strings.Builder
	defer strings.builder_destroy(&b)
	emit_write_prelude(&b, Emit_Options{package_name = "pkg"}, imports, false)
	text := strings.to_string(b)
	testing.expect(t, strings.contains(text, `import win32 "core:sys/windows"`))
	testing.expect(t, !strings.contains(text, "core:sys/posix"))
}

@(test)
test_platform_foreign_spelling_unix_keeps_map_entry :: proc(t: ^testing.T) {
	// On this host (build-tagged), platform_foreign_spelling should return a
	// non-empty spelling for map entries that the host defines.
	entry, ok := foreign_type_entry("sockaddr")
	testing.expect(t, ok)
	s := platform_foreign_spelling(entry)
	testing.expect(t, s != "")
	// Unix CI: posix.sockaddr; Windows CI: win32.sockaddr.
	when ODIN_OS == .Windows {
		testing.expect_value(t, s, "win32.sockaddr")
	} else {
		testing.expect_value(t, s, "posix.sockaddr")
	}
}
