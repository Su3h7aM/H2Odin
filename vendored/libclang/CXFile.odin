package clang

foreign import lib "system:clang"

File :: rawptr

File_Unique_Id :: struct {
	data: [3]u64,
}

foreign lib {
	@(link_name = "clang_getFileName")
	get_file_name :: proc(s_file: File) -> String ---
	@(link_name = "clang_getFileTime")
	get_file_time :: proc(s_file: File) -> i64 ---
	@(link_name = "clang_getFileUniqueID")
	get_file_unique_id :: proc(file: File, out_id: ^File_Unique_Id) -> i32 ---
	@(link_name = "clang_File_isEqual")
	file_is_equal :: proc(file1: File, file2: File) -> i32 ---
	@(link_name = "clang_File_tryGetRealPathName")
	file_try_get_real_path_name :: proc(file: File) -> String ---
}
