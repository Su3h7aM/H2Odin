package h2odin

import "core:testing"

@(test)
test_str_has_prefix_and_suffix :: proc(t: ^testing.T) {
	testing.expect(t, str_has_prefix("sqlite3_open", "sqlite3_"))
	testing.expect(t, !str_has_prefix("sqlite3_open", "SQLITE_"))
	testing.expect(t, str_has_prefix("x", ""))
	testing.expect(t, str_has_suffix("BoneInfo", "Info"))
	testing.expect(t, !str_has_suffix("BoneInfo", "info"))
}

@(test)
test_str_strip_prefix :: proc(t: ^testing.T) {
	testing.expect_value(t, str_strip_prefix("sqlite3_open", "sqlite3_"), "open")
	testing.expect_value(t, str_strip_prefix("open", "sqlite3_"), "open")
	// Whole-string strip is refused so a name never becomes empty.
	testing.expect_value(t, str_strip_prefix("sqlite3_", "sqlite3_"), "sqlite3_")
	testing.expect_value(t, str_strip_prefix("x", ""), "x")
}
