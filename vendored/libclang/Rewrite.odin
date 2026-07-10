package clang

foreign import lib "system:clang"

Rewriter :: rawptr

foreign lib {
	@(link_name = "clang_CXRewriter_create")
	cx_rewriter_create :: proc(tu: Translation_Unit) -> Rewriter ---
	@(link_name = "clang_CXRewriter_insertTextBefore")
	cx_rewriter_insert_text_before :: proc(rew: Rewriter, loc: Source_Location, insert: cstring) ---
	@(link_name = "clang_CXRewriter_replaceText")
	cx_rewriter_replace_text :: proc(rew: Rewriter, to_be_replaced: Source_Range, replacement: cstring) ---
	@(link_name = "clang_CXRewriter_removeText")
	cx_rewriter_remove_text :: proc(rew: Rewriter, to_be_removed: Source_Range) ---
	@(link_name = "clang_CXRewriter_overwriteChangedFiles")
	cx_rewriter_overwrite_changed_files :: proc(rew: Rewriter) -> i32 ---
	@(link_name = "clang_CXRewriter_writeMainFileToStdOut")
	cx_rewriter_write_main_file_to_std_out :: proc(rew: Rewriter) ---
	@(link_name = "clang_CXRewriter_dispose")
	cx_rewriter_dispose :: proc(rew: Rewriter) ---
}
