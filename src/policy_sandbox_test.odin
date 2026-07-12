package h2odin

import "core:testing"

@(test)
test_path_is_under_separator_boundary :: proc(t: ^testing.T) {
	testing.expect(t, path_is_under("/tmp/cfg", "/tmp/cfg"))
	testing.expect(t, path_is_under("/tmp/cfg/mod.lua", "/tmp/cfg"))
	testing.expect(t, path_is_under("/tmp/cfg/nested/x.lua", "/tmp/cfg"))
	testing.expect(t, !path_is_under("/tmp/cfg_evil/x.lua", "/tmp/cfg"))
	testing.expect(t, !path_is_under("/tmp/cf", "/tmp/cfg"))
	testing.expect(t, !path_is_under("/tmp", "/tmp/cfg"))
}

@(test)
test_path_is_under_trailing_separator_and_root :: proc(t: ^testing.T) {
	// Filesystem root must accept absolute descendants.
	testing.expect(t, path_is_under("/", "/"))
	testing.expect(t, path_is_under("/tmp", "/"))
	testing.expect(t, path_is_under("/tmp/cfg/mod.lua", "/"))
	testing.expect(t, !path_is_under("relative", "/"))

	// Root already ends with a separator: treat as directory prefix.
	testing.expect(t, path_is_under("/tmp/cfg/mod.lua", "/tmp/cfg/"))
	testing.expect(t, !path_is_under("/tmp/cfg", "/tmp/cfg/"))
	testing.expect(t, !path_is_under("/tmp/cfg_evil/x", "/tmp/cfg/"))

	// Windows-style separators (lexical only; case folding is out of scope).
	testing.expect(t, path_is_under(`C:\cfg\mod.lua`, `C:\cfg`))
	testing.expect(t, path_is_under(`C:\cfg\mod.lua`, `C:\cfg\`))
	testing.expect(t, !path_is_under(`C:\cfg_evil\x`, `C:\cfg`))
}
