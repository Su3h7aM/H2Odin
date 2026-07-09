package h2odin

import "core:strings"
import "core:testing"

@(test)
test_naming_snake_and_ada_basic :: proc(t: ^testing.T) {
	snake, amb := naming_snake_case("sqlite3_open_v2")
	testing.expect(t, !amb)
	testing.expect_value(t, snake, "sqlite3_open_v2")
	delete(snake)

	snake2, amb2 := naming_snake_case("draw_texture")
	testing.expect(t, !amb2)
	testing.expect_value(t, snake2, "draw_texture")
	delete(snake2)

	ada, amb3 := naming_ada_case("draw_texture")
	testing.expect(t, !amb3)
	testing.expect_value(t, ada, "Draw_Texture")
	delete(ada)

	ada2, _ := naming_ada_case("HTTPSConnection")
	testing.expect_value(t, ada2, "Https_Connection")
	delete(ada2)
}

@(test)
test_naming_known_tokens_resolve_vocabulary :: proc(t: ^testing.T) {
	known := make(map[string]string)
	defer {
		for k, v in known {
			delete(k)
			delete(v)
		}
		delete(known)
	}
	known[strings.clone("SQLite3")] = strings.clone("sqlite3")
	known[strings.clone("UTF8")] = strings.clone("utf8")
	known[strings.clone("NOMEM")] = strings.clone("no_mem")

	snake, amb := naming_snake_case("SQLite3_open", known)
	testing.expect(t, !amb)
	testing.expect_value(t, snake, "sqlite3_open")
	delete(snake)

	ada, amb2 := naming_ada_case("SQLite3_UTF8", known)
	testing.expect(t, !amb2)
	testing.expect_value(t, ada, "Sqlite3_Utf8")
	delete(ada)

	ada3, amb3 := naming_ada_case("NOMEM", known)
	testing.expect(t, !amb3)
	testing.expect_value(t, ada3, "No_Mem")
	delete(ada3)
}

@(test)
test_naming_camel_splits :: proc(t: ^testing.T) {
	ada, amb := naming_ada_case("XMLHttpRequest")
	testing.expect(t, !amb)
	testing.expect_value(t, ada, "Xml_Http_Request")
	delete(ada)

	snake, _ := naming_snake_case("getHTTPResponse")
	testing.expect_value(t, snake, "get_http_response")
	delete(snake)
}

@(test)
test_naming_apply_case_by_kind :: proc(t: ^testing.T) {
	proc_name, _ := naming_apply_case("DrawTexture", .Func)
	testing.expect_value(t, proc_name, "draw_texture")
	delete(proc_name)

	type_name, _ := naming_apply_case("draw_texture", .Type)
	testing.expect_value(t, type_name, "Draw_Texture")
	delete(type_name)

	member, _ := naming_apply_case("KEY_NULL", .Enum_Member)
	testing.expect_value(t, member, "Key_Null")
	delete(member)
}
