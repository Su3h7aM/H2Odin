package clang

foreign import lib "system:clang"

String :: struct {
	data:          rawptr,
	private_flags: u32,
}

String_Set :: struct {
	strings: ^String,
	count:   u32,
}

foreign lib {
	@(link_name = "clang_getCString")
	get_c_string :: proc(string: String) -> cstring ---
	@(link_name = "clang_disposeString")
	dispose_string :: proc(string: String) ---
	@(link_name = "clang_disposeStringSet")
	dispose_string_set :: proc(set: ^String_Set) ---
}
