package clang

foreign import lib "system:clang"

Source_Location :: struct {
	ptr_data: [2]rawptr,
	int_data: u32,
}

Source_Range :: struct {
	ptr_data: [2]rawptr,
	begin_int_data: u32,
	end_int_data: u32,
}

Source_Range_List :: struct {
	count: u32,
	ranges: ^Source_Range,
}

foreign lib {
	@(link_name = "clang_getNullLocation")
	get_null_location :: proc() -> Source_Location ---
	@(link_name = "clang_equalLocations")
	equal_locations :: proc(loc1: Source_Location, loc2: Source_Location) -> u32 ---
	@(link_name = "clang_isBeforeInTranslationUnit")
	is_before_in_translation_unit :: proc(loc1: Source_Location, loc2: Source_Location) -> u32 ---
	@(link_name = "clang_Location_isInSystemHeader")
	location_is_in_system_header :: proc(location: Source_Location) -> i32 ---
	@(link_name = "clang_Location_isFromMainFile")
	location_is_from_main_file :: proc(location: Source_Location) -> i32 ---
	@(link_name = "clang_getNullRange")
	get_null_range :: proc() -> Source_Range ---
	@(link_name = "clang_getRange")
	get_range :: proc(begin: Source_Location, end: Source_Location) -> Source_Range ---
	@(link_name = "clang_equalRanges")
	equal_ranges :: proc(range1: Source_Range, range2: Source_Range) -> u32 ---
	@(link_name = "clang_Range_isNull")
	range_is_null :: proc(range: Source_Range) -> i32 ---
	@(link_name = "clang_getExpansionLocation")
	get_expansion_location :: proc(location: Source_Location, file: ^File, line: ^u32, column: ^u32, offset: ^u32) ---
	@(link_name = "clang_getPresumedLocation")
	get_presumed_location :: proc(location: Source_Location, filename: ^String, line: ^u32, column: ^u32) ---
	@(link_name = "clang_getInstantiationLocation")
	get_instantiation_location :: proc(location: Source_Location, file: ^File, line: ^u32, column: ^u32, offset: ^u32) ---
	@(link_name = "clang_getSpellingLocation")
	get_spelling_location :: proc(location: Source_Location, file: ^File, line: ^u32, column: ^u32, offset: ^u32) ---
	@(link_name = "clang_getFileLocation")
	get_file_location :: proc(location: Source_Location, file: ^File, line: ^u32, column: ^u32, offset: ^u32) ---
	@(link_name = "clang_getRangeStart")
	get_range_start :: proc(range: Source_Range) -> Source_Location ---
	@(link_name = "clang_getRangeEnd")
	get_range_end :: proc(range: Source_Range) -> Source_Location ---
	@(link_name = "clang_disposeSourceRangeList")
	dispose_source_range_list :: proc(ranges: ^Source_Range_List) ---
}
