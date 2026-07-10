package clang

foreign import lib "system:clang"

Comment :: struct {
	ast_node: rawptr,
	translation_unit: Translation_Unit,
}

Comment_Kind :: enum u32 {
	Cx_Comment_Null = 0,
	Cx_Comment_Text = 1,
	Cx_Comment_Inline_Command = 2,
	Cx_Comment_Html_Start_Tag = 3,
	Cx_Comment_Html_End_Tag = 4,
	Cx_Comment_Paragraph = 5,
	Cx_Comment_Block_Command = 6,
	Cx_Comment_Param_Command = 7,
	Cx_Comment_T_Param_Command = 8,
	Cx_Comment_Verbatim_Block_Command = 9,
	Cx_Comment_Verbatim_Block_Line = 10,
	Cx_Comment_Verbatim_Line = 11,
	Cx_Comment_Full_Comment = 12,
}

Comment_Inline_Command_Render_Kind :: enum u32 {
	Cx_Comment_Inline_Command_Render_Kind_Normal = 0,
	Cx_Comment_Inline_Command_Render_Kind_Bold = 1,
	Cx_Comment_Inline_Command_Render_Kind_Monospaced = 2,
	Cx_Comment_Inline_Command_Render_Kind_Emphasized = 3,
	Cx_Comment_Inline_Command_Render_Kind_Anchor = 4,
}

Comment_Param_Pass_Direction :: enum u32 {
	Cx_Comment_Param_Pass_Direction_In = 0,
	Cx_Comment_Param_Pass_Direction_Out = 1,
	Cx_Comment_Param_Pass_Direction_In_Out = 2,
}

Api_Set :: distinct rawptr

foreign lib {
	@(link_name = "clang_Cursor_getParsedComment")
	cursor_get_parsed_comment :: proc(c: Cursor) -> Comment ---
	@(link_name = "clang_Comment_getKind")
	comment_get_kind :: proc(comment: Comment) -> Comment_Kind ---
	@(link_name = "clang_Comment_getNumChildren")
	comment_get_num_children :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_Comment_getChild")
	comment_get_child :: proc(comment: Comment, child_idx: u32) -> Comment ---
	@(link_name = "clang_Comment_isWhitespace")
	comment_is_whitespace :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_InlineContentComment_hasTrailingNewline")
	inline_content_comment_has_trailing_newline :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_TextComment_getText")
	text_comment_get_text :: proc(comment: Comment) -> String ---
	@(link_name = "clang_InlineCommandComment_getCommandName")
	inline_command_comment_get_command_name :: proc(comment: Comment) -> String ---
	@(link_name = "clang_InlineCommandComment_getRenderKind")
	inline_command_comment_get_render_kind :: proc(comment: Comment) -> Comment_Inline_Command_Render_Kind ---
	@(link_name = "clang_InlineCommandComment_getNumArgs")
	inline_command_comment_get_num_args :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_InlineCommandComment_getArgText")
	inline_command_comment_get_arg_text :: proc(comment: Comment, arg_idx: u32) -> String ---
	@(link_name = "clang_HTMLTagComment_getTagName")
	html_tag_comment_get_tag_name :: proc(comment: Comment) -> String ---
	@(link_name = "clang_HTMLStartTagComment_isSelfClosing")
	html_start_tag_comment_is_self_closing :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_HTMLStartTag_getNumAttrs")
	html_start_tag_get_num_attrs :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_HTMLStartTag_getAttrName")
	html_start_tag_get_attr_name :: proc(comment: Comment, attr_idx: u32) -> String ---
	@(link_name = "clang_HTMLStartTag_getAttrValue")
	html_start_tag_get_attr_value :: proc(comment: Comment, attr_idx: u32) -> String ---
	@(link_name = "clang_BlockCommandComment_getCommandName")
	block_command_comment_get_command_name :: proc(comment: Comment) -> String ---
	@(link_name = "clang_BlockCommandComment_getNumArgs")
	block_command_comment_get_num_args :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_BlockCommandComment_getArgText")
	block_command_comment_get_arg_text :: proc(comment: Comment, arg_idx: u32) -> String ---
	@(link_name = "clang_BlockCommandComment_getParagraph")
	block_command_comment_get_paragraph :: proc(comment: Comment) -> Comment ---
	@(link_name = "clang_ParamCommandComment_getParamName")
	param_command_comment_get_param_name :: proc(comment: Comment) -> String ---
	@(link_name = "clang_ParamCommandComment_isParamIndexValid")
	param_command_comment_is_param_index_valid :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_ParamCommandComment_getParamIndex")
	param_command_comment_get_param_index :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_ParamCommandComment_isDirectionExplicit")
	param_command_comment_is_direction_explicit :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_ParamCommandComment_getDirection")
	param_command_comment_get_direction :: proc(comment: Comment) -> Comment_Param_Pass_Direction ---
	@(link_name = "clang_TParamCommandComment_getParamName")
	t_param_command_comment_get_param_name :: proc(comment: Comment) -> String ---
	@(link_name = "clang_TParamCommandComment_isParamPositionValid")
	t_param_command_comment_is_param_position_valid :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_TParamCommandComment_getDepth")
	t_param_command_comment_get_depth :: proc(comment: Comment) -> u32 ---
	@(link_name = "clang_TParamCommandComment_getIndex")
	t_param_command_comment_get_index :: proc(comment: Comment, depth: u32) -> u32 ---
	@(link_name = "clang_VerbatimBlockLineComment_getText")
	verbatim_block_line_comment_get_text :: proc(comment: Comment) -> String ---
	@(link_name = "clang_VerbatimLineComment_getText")
	verbatim_line_comment_get_text :: proc(comment: Comment) -> String ---
	@(link_name = "clang_HTMLTagComment_getAsString")
	html_tag_comment_get_as_string :: proc(comment: Comment) -> String ---
	@(link_name = "clang_FullComment_getAsHTML")
	full_comment_get_as_html :: proc(comment: Comment) -> String ---
	@(link_name = "clang_FullComment_getAsXML")
	full_comment_get_as_xml :: proc(comment: Comment) -> String ---
	@(link_name = "clang_createAPISet")
	create_api_set :: proc(tu: Translation_Unit, out_api: ^Api_Set) -> Error_Code ---
	@(link_name = "clang_disposeAPISet")
	dispose_api_set :: proc(api: Api_Set) ---
	@(link_name = "clang_getSymbolGraphForUSR")
	get_symbol_graph_for_usr :: proc(usr: cstring, api: Api_Set) -> String ---
	@(link_name = "clang_getSymbolGraphForCursor")
	get_symbol_graph_for_cursor :: proc(cursor: Cursor) -> String ---
}
