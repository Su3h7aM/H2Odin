package clang

foreign import lib "system:clang"

Virtual_File_Overlay :: distinct rawptr

Module_Map_Descriptor :: distinct rawptr

foreign lib {
	@(link_name = "clang_getBuildSessionTimestamp")
	get_build_session_timestamp :: proc() -> u64 ---
	@(link_name = "clang_VirtualFileOverlay_create")
	virtual_file_overlay_create :: proc(options: u32) -> Virtual_File_Overlay ---
	@(link_name = "clang_VirtualFileOverlay_addFileMapping")
	virtual_file_overlay_add_file_mapping :: proc(_: Virtual_File_Overlay, virtual_path: cstring, real_path: cstring) -> Error_Code ---
	@(link_name = "clang_VirtualFileOverlay_setCaseSensitivity")
	virtual_file_overlay_set_case_sensitivity :: proc(_: Virtual_File_Overlay, case_sensitive: i32) -> Error_Code ---
	@(link_name = "clang_VirtualFileOverlay_writeToBuffer")
	virtual_file_overlay_write_to_buffer :: proc(_: Virtual_File_Overlay, options: u32, out_buffer_ptr: ^^u8, out_buffer_size: ^u32) -> Error_Code ---
	@(link_name = "clang_free")
	free :: proc(buffer: rawptr) ---
	@(link_name = "clang_VirtualFileOverlay_dispose")
	virtual_file_overlay_dispose :: proc(_: Virtual_File_Overlay) ---
	@(link_name = "clang_ModuleMapDescriptor_create")
	module_map_descriptor_create :: proc(options: u32) -> Module_Map_Descriptor ---
	@(link_name = "clang_ModuleMapDescriptor_setFrameworkModuleName")
	module_map_descriptor_set_framework_module_name :: proc(_: Module_Map_Descriptor, name: cstring) -> Error_Code ---
	@(link_name = "clang_ModuleMapDescriptor_setUmbrellaHeader")
	module_map_descriptor_set_umbrella_header :: proc(_: Module_Map_Descriptor, name: cstring) -> Error_Code ---
	@(link_name = "clang_ModuleMapDescriptor_writeToBuffer")
	module_map_descriptor_write_to_buffer :: proc(_: Module_Map_Descriptor, options: u32, out_buffer_ptr: ^^u8, out_buffer_size: ^u32) -> Error_Code ---
	@(link_name = "clang_ModuleMapDescriptor_dispose")
	module_map_descriptor_dispose :: proc(_: Module_Map_Descriptor) ---
}
