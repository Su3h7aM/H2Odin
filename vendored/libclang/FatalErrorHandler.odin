package clang

foreign import lib "system:clang"

foreign lib {
	@(link_name = "clang_install_aborting_llvm_fatal_error_handler")
	install_aborting_llvm_fatal_error_handler :: proc() ---
	@(link_name = "clang_uninstall_llvm_fatal_error_handler")
	uninstall_llvm_fatal_error_handler :: proc() ---
}
