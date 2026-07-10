package clang

foreign import lib "system:clang"

Compilation_Database :: rawptr

Compile_Commands :: rawptr

Compile_Command :: rawptr

Compilation_Database_Error :: enum u32 {
	Cx_Compilation_Database_No_Error,
	Cx_Compilation_Database_Can_Not_Load_Database,
}

foreign lib {
	@(link_name = "clang_CompilationDatabase_fromDirectory")
	compilation_database_from_directory :: proc(build_dir: cstring, error_code: ^Compilation_Database_Error) -> Compilation_Database ---
	@(link_name = "clang_CompilationDatabase_dispose")
	compilation_database_dispose :: proc(_: Compilation_Database) ---
	@(link_name = "clang_CompilationDatabase_getCompileCommands")
	compilation_database_get_compile_commands :: proc(_: Compilation_Database, complete_file_name: cstring) -> Compile_Commands ---
	@(link_name = "clang_CompilationDatabase_getAllCompileCommands")
	compilation_database_get_all_compile_commands :: proc(_: Compilation_Database) -> Compile_Commands ---
	@(link_name = "clang_CompileCommands_dispose")
	compile_commands_dispose :: proc(_: Compile_Commands) ---
	@(link_name = "clang_CompileCommands_getSize")
	compile_commands_get_size :: proc(_: Compile_Commands) -> u32 ---
	@(link_name = "clang_CompileCommands_getCommand")
	compile_commands_get_command :: proc(_: Compile_Commands, i: u32) -> Compile_Command ---
	@(link_name = "clang_CompileCommand_getDirectory")
	compile_command_get_directory :: proc(_: Compile_Command) -> String ---
	@(link_name = "clang_CompileCommand_getFilename")
	compile_command_get_filename :: proc(_: Compile_Command) -> String ---
	@(link_name = "clang_CompileCommand_getNumArgs")
	compile_command_get_num_args :: proc(_: Compile_Command) -> u32 ---
	@(link_name = "clang_CompileCommand_getArg")
	compile_command_get_arg :: proc(_: Compile_Command, i: u32) -> String ---
	@(link_name = "clang_CompileCommand_getNumMappedSources")
	compile_command_get_num_mapped_sources :: proc(_: Compile_Command) -> u32 ---
	@(link_name = "clang_CompileCommand_getMappedSourcePath")
	compile_command_get_mapped_source_path :: proc(_: Compile_Command, i: u32) -> String ---
	@(link_name = "clang_CompileCommand_getMappedSourceContent")
	compile_command_get_mapped_source_content :: proc(_: Compile_Command, i: u32) -> String ---
}
