package clang

foreign import lib "system:clang"

VERSION_MAJOR :: 0
VERSION_MINOR :: 64
Index :: rawptr

Target_Info :: rawptr

Translation_Unit :: rawptr

Client_Data :: rawptr

Unsaved_File :: struct {
	filename: cstring,
	contents: cstring,
	length: u64,
}

Availability_Kind :: enum u32 {
	Available = 0,
	Deprecated = 1,
	Not_Available = 2,
	Not_Accessible = 3,
}

Version :: struct {
	major: i32,
	minor: i32,
	subminor: i32,
}

Cursor_Exception_Specification_Kind :: enum u32 {
	None = 0,
	Dynamic_None = 1,
	Dynamic = 2,
	Ms_Any = 3,
	Basic_Noexcept = 4,
	Computed_Noexcept = 5,
	Unevaluated = 6,
	Uninstantiated = 7,
	Unparsed = 8,
	No_Throw = 9,
}

Choice :: enum u32 {
	Default = 0,
	Enabled = 1,
	Disabled = 2,
}

Global_Opt_Flags :: enum u32 {
	None = 0,
	Thread_Background_Priority_For_Indexing = 1,
	Thread_Background_Priority_For_Editing = 2,
	Thread_Background_Priority_For_All = 3,
}

Index_Options :: struct {
	size: u32,
	thread_background_priority_for_indexing: u8,
	thread_background_priority_for_editing: u8,
	using _: bit_field u16 {
		exclude_declarations_from_pch: u16 | 1,
		display_diagnostics: u16 | 1,
		store_preambles_in_memory: u16 | 1,
		_: u16 | 13,
	},
	preamble_storage_path: cstring,
	invocation_emission_path: cstring,
}

Translation_Unit_Flags :: enum u32 {
	None = 0,
	Detailed_Preprocessing_Record = 1,
	Incomplete = 2,
	Precompiled_Preamble = 4,
	Cache_Completion_Results = 8,
	For_Serialization = 16,
	Cxx_Chained_Pch = 32,
	Skip_Function_Bodies = 64,
	Include_Brief_Comments_In_Code_Completion = 128,
	Create_Preamble_On_First_Parse = 256,
	Keep_Going = 512,
	Single_File_Parse = 1024,
	Limit_Skip_Function_Bodies_To_Preamble = 2048,
	Include_Attributed_Types = 4096,
	Visit_Implicit_Attributes = 8192,
	Ignore_Non_Errors_From_Included_Files = 16384,
	Retain_Excluded_Conditional_Blocks = 32768,
}

Save_Translation_Unit_Flags :: enum u32 {
	None = 0,
}

Save_Error :: enum u32 {
	None = 0,
	Unknown = 1,
	Translation_Errors = 2,
	Invalid_Tu = 3,
}

Reparse_Flags :: enum u32 {
	None = 0,
}

Tu_Resource_Usage_Kind :: enum u32 {
	Ast = 1,
	Identifiers = 2,
	Selectors = 3,
	Global_Completion_Results = 4,
	Source_Manager_Content_Cache = 5,
	Ast_Side_Tables = 6,
	Source_Manager_Membuffer_Malloc = 7,
	Source_Manager_Membuffer_M_Map = 8,
	External_Ast_Source_Membuffer_Malloc = 9,
	External_Ast_Source_Membuffer_M_Map = 10,
	Preprocessor = 11,
	Preprocessing_Record = 12,
	Source_Manager_Data_Structures = 13,
	Preprocessor_Header_Search = 14,
	Memory_In_Bytes_Begin = 1,
	Memory_In_Bytes_End = 14,
	First = 1,
	Last = 14,
}

Tu_Resource_Usage_Entry :: struct {
	kind: Tu_Resource_Usage_Kind,
	amount: u64,
}

Tu_Resource_Usage :: struct {
	data: rawptr,
	num_entries: u32,
	entries: ^Tu_Resource_Usage_Entry,
}

Cursor_Kind :: enum u32 {
	Unexposed_Decl = 1,
	Struct_Decl = 2,
	Union_Decl = 3,
	Class_Decl = 4,
	Enum_Decl = 5,
	Field_Decl = 6,
	Enum_Constant_Decl = 7,
	Function_Decl = 8,
	Var_Decl = 9,
	Parm_Decl = 10,
	Obj_C_Interface_Decl = 11,
	Obj_C_Category_Decl = 12,
	Obj_C_Protocol_Decl = 13,
	Obj_C_Property_Decl = 14,
	Obj_C_Ivar_Decl = 15,
	Obj_C_Instance_Method_Decl = 16,
	Obj_C_Class_Method_Decl = 17,
	Obj_C_Implementation_Decl = 18,
	Obj_C_Category_Impl_Decl = 19,
	Typedef_Decl = 20,
	Cxx_Method = 21,
	Namespace = 22,
	Linkage_Spec = 23,
	Constructor = 24,
	Destructor = 25,
	Conversion_Function = 26,
	Template_Type_Parameter = 27,
	Non_Type_Template_Parameter = 28,
	Template_Template_Parameter = 29,
	Function_Template = 30,
	Class_Template = 31,
	Class_Template_Partial_Specialization = 32,
	Namespace_Alias = 33,
	Using_Directive = 34,
	Using_Declaration = 35,
	Type_Alias_Decl = 36,
	Obj_C_Synthesize_Decl = 37,
	Obj_C_Dynamic_Decl = 38,
	Cxx_Access_Specifier = 39,
	First_Decl = 1,
	Last_Decl = 39,
	First_Ref = 40,
	Obj_C_Super_Class_Ref = 40,
	Obj_C_Protocol_Ref = 41,
	Obj_C_Class_Ref = 42,
	Type_Ref = 43,
	Cxx_Base_Specifier = 44,
	Template_Ref = 45,
	Namespace_Ref = 46,
	Member_Ref = 47,
	Label_Ref = 48,
	Overloaded_Decl_Ref = 49,
	Variable_Ref = 50,
	Last_Ref = 50,
	First_Invalid = 70,
	Invalid_File = 70,
	No_Decl_Found = 71,
	Not_Implemented = 72,
	Invalid_Code = 73,
	Last_Invalid = 73,
	First_Expr = 100,
	Unexposed_Expr = 100,
	Decl_Ref_Expr = 101,
	Member_Ref_Expr = 102,
	Call_Expr = 103,
	Obj_C_Message_Expr = 104,
	Block_Expr = 105,
	Integer_Literal = 106,
	Floating_Literal = 107,
	Imaginary_Literal = 108,
	String_Literal = 109,
	Character_Literal = 110,
	Paren_Expr = 111,
	Unary_Operator = 112,
	Array_Subscript_Expr = 113,
	Binary_Operator = 114,
	Compound_Assign_Operator = 115,
	Conditional_Operator = 116,
	C_Style_Cast_Expr = 117,
	Compound_Literal_Expr = 118,
	Init_List_Expr = 119,
	Addr_Label_Expr = 120,
	Stmt_Expr = 121,
	Generic_Selection_Expr = 122,
	Gnu_Null_Expr = 123,
	Cxx_Static_Cast_Expr = 124,
	Cxx_Dynamic_Cast_Expr = 125,
	Cxx_Reinterpret_Cast_Expr = 126,
	Cxx_Const_Cast_Expr = 127,
	Cxx_Functional_Cast_Expr = 128,
	Cxx_Typeid_Expr = 129,
	Cxx_Bool_Literal_Expr = 130,
	Cxx_Null_Ptr_Literal_Expr = 131,
	Cxx_This_Expr = 132,
	Cxx_Throw_Expr = 133,
	Cxx_New_Expr = 134,
	Cxx_Delete_Expr = 135,
	Unary_Expr = 136,
	Obj_C_String_Literal = 137,
	Obj_C_Encode_Expr = 138,
	Obj_C_Selector_Expr = 139,
	Obj_C_Protocol_Expr = 140,
	Obj_C_Bridged_Cast_Expr = 141,
	Pack_Expansion_Expr = 142,
	Size_Of_Pack_Expr = 143,
	Lambda_Expr = 144,
	Obj_C_Bool_Literal_Expr = 145,
	Obj_C_Self_Expr = 146,
	Array_Section_Expr = 147,
	Obj_C_Availability_Check_Expr = 148,
	Fixed_Point_Literal = 149,
	Omp_Array_Shaping_Expr = 150,
	Omp_Iterator_Expr = 151,
	Cxx_Addrspace_Cast_Expr = 152,
	Concept_Specialization_Expr = 153,
	Requires_Expr = 154,
	Cxx_Paren_List_Init_Expr = 155,
	Pack_Indexing_Expr = 156,
	Last_Expr = 156,
	First_Stmt = 200,
	Unexposed_Stmt = 200,
	Label_Stmt = 201,
	Compound_Stmt = 202,
	Case_Stmt = 203,
	Default_Stmt = 204,
	If_Stmt = 205,
	Switch_Stmt = 206,
	While_Stmt = 207,
	Do_Stmt = 208,
	For_Stmt = 209,
	Goto_Stmt = 210,
	Indirect_Goto_Stmt = 211,
	Continue_Stmt = 212,
	Break_Stmt = 213,
	Return_Stmt = 214,
	Gcc_Asm_Stmt = 215,
	Asm_Stmt = 215,
	Obj_C_At_Try_Stmt = 216,
	Obj_C_At_Catch_Stmt = 217,
	Obj_C_At_Finally_Stmt = 218,
	Obj_C_At_Throw_Stmt = 219,
	Obj_C_At_Synchronized_Stmt = 220,
	Obj_C_Autorelease_Pool_Stmt = 221,
	Obj_C_For_Collection_Stmt = 222,
	Cxx_Catch_Stmt = 223,
	Cxx_Try_Stmt = 224,
	Cxx_For_Range_Stmt = 225,
	Seh_Try_Stmt = 226,
	Seh_Except_Stmt = 227,
	Seh_Finally_Stmt = 228,
	Ms_Asm_Stmt = 229,
	Null_Stmt = 230,
	Decl_Stmt = 231,
	Omp_Parallel_Directive = 232,
	Omp_Simd_Directive = 233,
	Omp_For_Directive = 234,
	Omp_Sections_Directive = 235,
	Omp_Section_Directive = 236,
	Omp_Single_Directive = 237,
	Omp_Parallel_For_Directive = 238,
	Omp_Parallel_Sections_Directive = 239,
	Omp_Task_Directive = 240,
	Omp_Master_Directive = 241,
	Omp_Critical_Directive = 242,
	Omp_Taskyield_Directive = 243,
	Omp_Barrier_Directive = 244,
	Omp_Taskwait_Directive = 245,
	Omp_Flush_Directive = 246,
	Seh_Leave_Stmt = 247,
	Omp_Ordered_Directive = 248,
	Omp_Atomic_Directive = 249,
	Omp_For_Simd_Directive = 250,
	Omp_Parallel_For_Simd_Directive = 251,
	Omp_Target_Directive = 252,
	Omp_Teams_Directive = 253,
	Omp_Taskgroup_Directive = 254,
	Omp_Cancellation_Point_Directive = 255,
	Omp_Cancel_Directive = 256,
	Omp_Target_Data_Directive = 257,
	Omp_Task_Loop_Directive = 258,
	Omp_Task_Loop_Simd_Directive = 259,
	Omp_Distribute_Directive = 260,
	Omp_Target_Enter_Data_Directive = 261,
	Omp_Target_Exit_Data_Directive = 262,
	Omp_Target_Parallel_Directive = 263,
	Omp_Target_Parallel_For_Directive = 264,
	Omp_Target_Update_Directive = 265,
	Omp_Distribute_Parallel_For_Directive = 266,
	Omp_Distribute_Parallel_For_Simd_Directive = 267,
	Omp_Distribute_Simd_Directive = 268,
	Omp_Target_Parallel_For_Simd_Directive = 269,
	Omp_Target_Simd_Directive = 270,
	Omp_Teams_Distribute_Directive = 271,
	Omp_Teams_Distribute_Simd_Directive = 272,
	Omp_Teams_Distribute_Parallel_For_Simd_Directive = 273,
	Omp_Teams_Distribute_Parallel_For_Directive = 274,
	Omp_Target_Teams_Directive = 275,
	Omp_Target_Teams_Distribute_Directive = 276,
	Omp_Target_Teams_Distribute_Parallel_For_Directive = 277,
	Omp_Target_Teams_Distribute_Parallel_For_Simd_Directive = 278,
	Omp_Target_Teams_Distribute_Simd_Directive = 279,
	Builtin_Bit_Cast_Expr = 280,
	Omp_Master_Task_Loop_Directive = 281,
	Omp_Parallel_Master_Task_Loop_Directive = 282,
	Omp_Master_Task_Loop_Simd_Directive = 283,
	Omp_Parallel_Master_Task_Loop_Simd_Directive = 284,
	Omp_Parallel_Master_Directive = 285,
	Omp_Depobj_Directive = 286,
	Omp_Scan_Directive = 287,
	Omp_Tile_Directive = 288,
	Omp_Canonical_Loop = 289,
	Omp_Interop_Directive = 290,
	Omp_Dispatch_Directive = 291,
	Omp_Masked_Directive = 292,
	Omp_Unroll_Directive = 293,
	Omp_Meta_Directive = 294,
	Omp_Generic_Loop_Directive = 295,
	Omp_Teams_Generic_Loop_Directive = 296,
	Omp_Target_Teams_Generic_Loop_Directive = 297,
	Omp_Parallel_Generic_Loop_Directive = 298,
	Omp_Target_Parallel_Generic_Loop_Directive = 299,
	Omp_Parallel_Masked_Directive = 300,
	Omp_Masked_Task_Loop_Directive = 301,
	Omp_Masked_Task_Loop_Simd_Directive = 302,
	Omp_Parallel_Masked_Task_Loop_Directive = 303,
	Omp_Parallel_Masked_Task_Loop_Simd_Directive = 304,
	Omp_Error_Directive = 305,
	Omp_Scope_Directive = 306,
	Omp_Reverse_Directive = 307,
	Omp_Interchange_Directive = 308,
	Omp_Assume_Directive = 309,
	Omp_Stripe_Directive = 310,
	Omp_Fuse_Directive = 311,
	Open_Acc_Compute_Construct = 320,
	Open_Acc_Loop_Construct = 321,
	Open_Acc_Combined_Construct = 322,
	Open_Acc_Data_Construct = 323,
	Open_Acc_Enter_Data_Construct = 324,
	Open_Acc_Exit_Data_Construct = 325,
	Open_Acc_Host_Data_Construct = 326,
	Open_Acc_Wait_Construct = 327,
	Open_Acc_Init_Construct = 328,
	Open_Acc_Shutdown_Construct = 329,
	Open_Acc_Set_Construct = 330,
	Open_Acc_Update_Construct = 331,
	Open_Acc_Atomic_Construct = 332,
	Open_Acc_Cache_Construct = 333,
	Last_Stmt = 333,
	Translation_Unit = 350,
	First_Attr = 400,
	Unexposed_Attr = 400,
	Ib_Action_Attr = 401,
	Ib_Outlet_Attr = 402,
	Ib_Outlet_Collection_Attr = 403,
	Cxx_Final_Attr = 404,
	Cxx_Override_Attr = 405,
	Annotate_Attr = 406,
	Asm_Label_Attr = 407,
	Packed_Attr = 408,
	Pure_Attr = 409,
	Const_Attr = 410,
	No_Duplicate_Attr = 411,
	Cuda_Constant_Attr = 412,
	Cuda_Device_Attr = 413,
	Cuda_Global_Attr = 414,
	Cuda_Host_Attr = 415,
	Cuda_Shared_Attr = 416,
	Visibility_Attr = 417,
	Dll_Export = 418,
	Dll_Import = 419,
	Ns_Returns_Retained = 420,
	Ns_Returns_Not_Retained = 421,
	Ns_Returns_Autoreleased = 422,
	Ns_Consumes_Self = 423,
	Ns_Consumed = 424,
	Obj_C_Exception = 425,
	Obj_Cns_Object = 426,
	Obj_C_Independent_Class = 427,
	Obj_C_Precise_Lifetime = 428,
	Obj_C_Returns_Inner_Pointer = 429,
	Obj_C_Requires_Super = 430,
	Obj_C_Root_Class = 431,
	Obj_C_Subclassing_Restricted = 432,
	Obj_C_Explicit_Protocol_Impl = 433,
	Obj_C_Designated_Initializer = 434,
	Obj_C_Runtime_Visible = 435,
	Obj_C_Boxable = 436,
	Flag_Enum = 437,
	Convergent_Attr = 438,
	Warn_Unused_Attr = 439,
	Warn_Unused_Result_Attr = 440,
	Aligned_Attr = 441,
	Last_Attr = 441,
	Preprocessing_Directive = 500,
	Macro_Definition = 501,
	Macro_Expansion = 502,
	Macro_Instantiation = 502,
	Inclusion_Directive = 503,
	First_Preprocessing = 500,
	Last_Preprocessing = 503,
	Module_Import_Decl = 600,
	Type_Alias_Template_Decl = 601,
	Static_Assert = 602,
	Friend_Decl = 603,
	Concept_Decl = 604,
	First_Extra_Decl = 600,
	Last_Extra_Decl = 604,
	Overload_Candidate = 700,
}

Cursor :: struct {
	kind: Cursor_Kind,
	xdata: i32,
	data: [3]rawptr,
}

Linkage_Kind :: enum u32 {
	Invalid = 0,
	No_Linkage = 1,
	Internal = 2,
	Unique_External = 3,
	External = 4,
}

Visibility_Kind :: enum u32 {
	Invalid = 0,
	Hidden = 1,
	Protected = 2,
	Default = 3,
}

Platform_Availability :: struct {
	platform: String,
	introduced: Version,
	deprecated: Version,
	obsoleted: Version,
	unavailable: i32,
	message: String,
}

Language_Kind :: enum u32 {
	Invalid = 0,
	C = 1,
	Obj_C = 2,
	C_Plus_Plus = 3,
}

Tls_Kind :: enum u32 {
	None = 0,
	Dynamic = 1,
	Static = 2,
}

Cursor_Set :: rawptr

Type_Kind :: enum u32 {
	Invalid = 0,
	Unexposed = 1,
	Void = 2,
	Bool = 3,
	Char_U = 4,
	U_Char = 5,
	Char16 = 6,
	Char32 = 7,
	U_Short = 8,
	U_Int = 9,
	U_Long = 10,
	U_Long_Long = 11,
	U_Int128 = 12,
	Char_S = 13,
	S_Char = 14,
	W_Char = 15,
	Short = 16,
	Int = 17,
	Long = 18,
	Long_Long = 19,
	Int128 = 20,
	Float = 21,
	Double = 22,
	Long_Double = 23,
	Null_Ptr = 24,
	Overload = 25,
	Dependent = 26,
	Obj_C_Id = 27,
	Obj_C_Class = 28,
	Obj_C_Sel = 29,
	Float128 = 30,
	Half = 31,
	Float16 = 32,
	Short_Accum = 33,
	Accum = 34,
	Long_Accum = 35,
	U_Short_Accum = 36,
	U_Accum = 37,
	U_Long_Accum = 38,
	B_Float16 = 39,
	Ibm128 = 40,
	First_Builtin = 2,
	Last_Builtin = 40,
	Complex = 100,
	Pointer = 101,
	Block_Pointer = 102,
	L_Value_Reference = 103,
	R_Value_Reference = 104,
	Record = 105,
	Enum = 106,
	Typedef = 107,
	Obj_C_Interface = 108,
	Obj_C_Object_Pointer = 109,
	Function_No_Proto = 110,
	Function_Proto = 111,
	Constant_Array = 112,
	Vector = 113,
	Incomplete_Array = 114,
	Variable_Array = 115,
	Dependent_Sized_Array = 116,
	Member_Pointer = 117,
	Auto = 118,
	Elaborated = 119,
	Pipe = 120,
	Ocl_Image1d_Ro = 121,
	Ocl_Image1d_Array_Ro = 122,
	Ocl_Image1d_Buffer_Ro = 123,
	Ocl_Image2d_Ro = 124,
	Ocl_Image2d_Array_Ro = 125,
	Ocl_Image2d_Depth_Ro = 126,
	Ocl_Image2d_Array_Depth_Ro = 127,
	Ocl_Image2d_Msaaro = 128,
	Ocl_Image2d_Array_Msaaro = 129,
	Ocl_Image2d_Msaa_Depth_Ro = 130,
	Ocl_Image2d_Array_Msaa_Depth_Ro = 131,
	Ocl_Image3d_Ro = 132,
	Ocl_Image1d_Wo = 133,
	Ocl_Image1d_Array_Wo = 134,
	Ocl_Image1d_Buffer_Wo = 135,
	Ocl_Image2d_Wo = 136,
	Ocl_Image2d_Array_Wo = 137,
	Ocl_Image2d_Depth_Wo = 138,
	Ocl_Image2d_Array_Depth_Wo = 139,
	Ocl_Image2d_Msaawo = 140,
	Ocl_Image2d_Array_Msaawo = 141,
	Ocl_Image2d_Msaa_Depth_Wo = 142,
	Ocl_Image2d_Array_Msaa_Depth_Wo = 143,
	Ocl_Image3d_Wo = 144,
	Ocl_Image1d_Rw = 145,
	Ocl_Image1d_Array_Rw = 146,
	Ocl_Image1d_Buffer_Rw = 147,
	Ocl_Image2d_Rw = 148,
	Ocl_Image2d_Array_Rw = 149,
	Ocl_Image2d_Depth_Rw = 150,
	Ocl_Image2d_Array_Depth_Rw = 151,
	Ocl_Image2d_Msaarw = 152,
	Ocl_Image2d_Array_Msaarw = 153,
	Ocl_Image2d_Msaa_Depth_Rw = 154,
	Ocl_Image2d_Array_Msaa_Depth_Rw = 155,
	Ocl_Image3d_Rw = 156,
	Ocl_Sampler = 157,
	Ocl_Event = 158,
	Ocl_Queue = 159,
	Ocl_Reserve_Id = 160,
	Obj_C_Object = 161,
	Obj_C_Type_Param = 162,
	Attributed = 163,
	Ocl_Intel_Subgroup_Avc_Mce_Payload = 164,
	Ocl_Intel_Subgroup_Avc_Ime_Payload = 165,
	Ocl_Intel_Subgroup_Avc_Ref_Payload = 166,
	Ocl_Intel_Subgroup_Avc_Sic_Payload = 167,
	Ocl_Intel_Subgroup_Avc_Mce_Result = 168,
	Ocl_Intel_Subgroup_Avc_Ime_Result = 169,
	Ocl_Intel_Subgroup_Avc_Ref_Result = 170,
	Ocl_Intel_Subgroup_Avc_Sic_Result = 171,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Single_Reference_Streamout = 172,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Dual_Reference_Streamout = 173,
	Ocl_Intel_Subgroup_Avc_Ime_Single_Reference_Streamin = 174,
	Ocl_Intel_Subgroup_Avc_Ime_Dual_Reference_Streamin = 175,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Single_Ref_Streamout = 172,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Dual_Ref_Streamout = 173,
	Ocl_Intel_Subgroup_Avc_Ime_Single_Ref_Streamin = 174,
	Ocl_Intel_Subgroup_Avc_Ime_Dual_Ref_Streamin = 175,
	Ext_Vector = 176,
	Atomic = 177,
	Btf_Tag_Attributed = 178,
	Hlsl_Resource = 179,
	Hlsl_Attributed_Resource = 180,
	Hlsl_Inline_Spirv = 181,
}

Calling_Conv :: enum u32 {
	Default = 0,
	C = 1,
	X86_Std_Call = 2,
	X86_Fast_Call = 3,
	X86_This_Call = 4,
	X86_Pascal = 5,
	Aapcs = 6,
	Aapcs_Vfp = 7,
	X86_Reg_Call = 8,
	Intel_Ocl_Bicc = 9,
	Win64 = 10,
	X86_64_Win64 = 10,
	X86_64_Sys_V = 11,
	X86_Vector_Call = 12,
	Swift = 13,
	Preserve_Most = 14,
	Preserve_All = 15,
	A_Arch64_Vector_Call = 16,
	Swift_Async = 17,
	A_Arch64_Svepcs = 18,
	M68k_Rtd = 19,
	Preserve_None = 20,
	Riscv_Vector_Call = 21,
	Riscvvls_Call_32 = 22,
	Riscvvls_Call_64 = 23,
	Riscvvls_Call_128 = 24,
	Riscvvls_Call_256 = 25,
	Riscvvls_Call_512 = 26,
	Riscvvls_Call_1024 = 27,
	Riscvvls_Call_2048 = 28,
	Riscvvls_Call_4096 = 29,
	Riscvvls_Call_8192 = 30,
	Riscvvls_Call_16384 = 31,
	Riscvvls_Call_32768 = 32,
	Riscvvls_Call_65536 = 33,
	Invalid = 100,
	Unexposed = 200,
}

Type :: struct {
	kind: Type_Kind,
	data: [2]rawptr,
}

Template_Argument_Kind :: enum u32 {
	Null = 0,
	Type = 1,
	Declaration = 2,
	Null_Ptr = 3,
	Integral = 4,
	Template = 5,
	Template_Expansion = 6,
	Expression = 7,
	Pack = 8,
	Invalid = 9,
}

Type_Nullability_Kind :: enum u32 {
	Non_Null = 0,
	Nullable = 1,
	Unspecified = 2,
	Invalid = 3,
	Nullable_Result = 4,
}

Type_Layout_Error :: enum i32 {
	Invalid = -1,
	Incomplete = -2,
	Dependent = -3,
	Not_Constant_Size = -4,
	Invalid_Field_Name = -5,
	Undeduced = -6,
}

Ref_Qualifier_Kind :: enum u32 {
	None = 0,
	L_Value = 1,
	R_Value = 2,
}

Cxx_Access_Specifier :: enum u32 {
	Cxx_Invalid_Access_Specifier = 0,
	Cxx_Public = 1,
	Cxx_Protected = 2,
	Cxx_Private = 3,
}

Storage_Class :: enum u32 {
	Invalid = 0,
	None = 1,
	Extern = 2,
	Static = 3,
	Private_Extern = 4,
	Open_Cl_Work_Group_Local = 5,
	Auto = 6,
	Register = 7,
}

Legacy_Binary_Operator_Kind :: enum u32 {
	Invalid = 0,
	Ptr_Mem_D = 1,
	Ptr_Mem_I = 2,
	Mul = 3,
	Div = 4,
	Rem = 5,
	Add = 6,
	Sub = 7,
	Shl = 8,
	Shr = 9,
	Cmp = 10,
	Lt = 11,
	Gt = 12,
	Le = 13,
	Ge = 14,
	Eq = 15,
	Ne = 16,
	And = 17,
	Xor = 18,
	Or = 19,
	L_And = 20,
	L_Or = 21,
	Assign = 22,
	Mul_Assign = 23,
	Div_Assign = 24,
	Rem_Assign = 25,
	Add_Assign = 26,
	Sub_Assign = 27,
	Shl_Assign = 28,
	Shr_Assign = 29,
	And_Assign = 30,
	Xor_Assign = 31,
	Or_Assign = 32,
	Comma = 33,
	Last = 33,
}

Child_Visit_Result :: enum u32 {
	Break = 0,
	Continue = 1,
	Recurse = 2,
}

Cursor_Visitor :: proc "c" (_: Cursor, _: Cursor, _: Client_Data) -> Child_Visit_Result

Cx_Child_Visit_Result :: struct {}

Cursor_Visitor_Block :: ^Cx_Child_Visit_Result

Printing_Policy :: rawptr

Printing_Policy_Property :: enum u32 {
	Indentation = 0,
	Suppress_Specifiers = 1,
	Suppress_Tag_Keyword = 2,
	Include_Tag_Definition = 3,
	Suppress_Scope = 4,
	Suppress_Unwritten_Scope = 5,
	Suppress_Initializers = 6,
	Constant_Array_Size_As_Written = 7,
	Anonymous_Tag_Locations = 8,
	Suppress_Strong_Lifetime = 9,
	Suppress_Lifetime_Qualifiers = 10,
	Suppress_Template_Args_In_Cxx_Constructors = 11,
	Bool = 12,
	Restrict = 13,
	Alignof = 14,
	Underscore_Alignof = 15,
	Use_Void_For_Zero_Params = 16,
	Terse_Output = 17,
	Polish_For_Declaration = 18,
	Half = 19,
	Msw_Char = 20,
	Include_Newlines = 21,
	Msvc_Formatting = 22,
	Constants_As_Written = 23,
	Suppress_Implicit_Base = 24,
	Fully_Qualified_Name = 25,
	Last_Property = 25,
}

Obj_C_Property_Attr_Kind :: enum u32 {
	Noattr = 0,
	Readonly = 1,
	Getter = 2,
	Assign = 4,
	Readwrite = 8,
	Retain = 16,
	Copy = 32,
	Nonatomic = 64,
	Setter = 128,
	Atomic = 256,
	Weak = 512,
	Strong = 1024,
	Unsafe_Unretained = 2048,
	Class = 4096,
}

Obj_C_Decl_Qualifier_Kind :: enum u32 {
	None = 0,
	In = 1,
	Inout = 2,
	Out = 4,
	Bycopy = 8,
	Byref = 16,
	Oneway = 32,
}

Module :: rawptr

Name_Ref_Flags :: enum u32 {
	Want_Qualifier = 1,
	Want_Template_Args = 2,
	Want_Single_Piece = 4,
}

Token_Kind :: enum u32 {
	Punctuation = 0,
	Keyword = 1,
	Identifier = 2,
	Literal = 3,
	Comment = 4,
}

Token :: struct {
	int_data: [4]u32,
	ptr_data: rawptr,
}

Completion_String :: rawptr

Completion_Result :: struct {
	cursor_kind: Cursor_Kind,
	completion_string: Completion_String,
}

Completion_Chunk_Kind :: enum u32 {
	Optional = 0,
	Typed_Text = 1,
	Text = 2,
	Placeholder = 3,
	Informative = 4,
	Current_Parameter = 5,
	Left_Paren = 6,
	Right_Paren = 7,
	Left_Bracket = 8,
	Right_Bracket = 9,
	Left_Brace = 10,
	Right_Brace = 11,
	Left_Angle = 12,
	Right_Angle = 13,
	Comma = 14,
	Result_Type = 15,
	Colon = 16,
	Semi_Colon = 17,
	Equal = 18,
	Horizontal_Space = 19,
	Vertical_Space = 20,
}

Code_Complete_Results :: struct {
	results: ^Completion_Result,
	num_results: u32,
}

Code_Complete_Flags :: enum u32 {
	Include_Macros = 1,
	Include_Code_Patterns = 2,
	Include_Brief_Comments = 4,
	Skip_Preamble = 8,
	Include_Completions_With_Fix_Its = 16,
}

Completion_Context :: enum u32 {
	Unexposed = 0,
	Any_Type = 1,
	Any_Value = 2,
	Obj_C_Object_Value = 4,
	Obj_C_Selector_Value = 8,
	Cxx_Class_Type_Value = 16,
	Dot_Member_Access = 32,
	Arrow_Member_Access = 64,
	Obj_C_Property_Access = 128,
	Enum_Tag = 256,
	Union_Tag = 512,
	Struct_Tag = 1024,
	Class_Tag = 2048,
	Namespace = 4096,
	Nested_Name_Specifier = 8192,
	Obj_C_Interface = 16384,
	Obj_C_Protocol = 32768,
	Obj_C_Category = 65536,
	Obj_C_Instance_Message = 131072,
	Obj_C_Class_Message = 262144,
	Obj_C_Selector_Name = 524288,
	Macro_Name = 1048576,
	Natural_Language = 2097152,
	Included_File = 4194304,
	Unknown = 8388607,
}

Inclusion_Visitor :: proc "c" (_: File, _: ^Source_Location, _: u32, _: Client_Data)

Eval_Result_Kind :: enum u32 {
	Int = 1,
	Float = 2,
	Obj_C_Str_Literal = 3,
	Str_Literal = 4,
	Cf_Str = 5,
	Other = 6,
	Un_Exposed = 0,
}

Eval_Result :: rawptr

Visitor_Result :: enum u32 {
	Break = 0,
	Continue = 1,
}

Cursor_And_Range_Visitor :: struct {
	context_: rawptr,
	visit: proc "c" (_: rawptr, _: Cursor, _: Source_Range) -> Visitor_Result,
}

Result :: enum u32 {
	Success = 0,
	Invalid = 1,
	Visit_Break = 2,
}

Cx_Cursor_And_Range_Visitor_Block :: struct {}

Cursor_And_Range_Visitor_Block :: ^Cx_Cursor_And_Range_Visitor_Block

Idx_Client_File :: rawptr

Idx_Client_Entity :: rawptr

Idx_Client_Container :: rawptr

Idx_Client_Ast_File :: rawptr

Idx_Loc :: struct {
	ptr_data: [2]rawptr,
	int_data: u32,
}

Idx_Included_File_Info :: struct {
	hash_loc: Idx_Loc,
	filename: cstring,
	file: File,
	is_import: i32,
	is_angled: i32,
	is_module_import: i32,
}

Idx_Imported_Ast_File_Info :: struct {
	file: File,
	module: Module,
	loc: Idx_Loc,
	is_implicit: i32,
}

Idx_Entity_Kind :: enum u32 {
	Unexposed = 0,
	Typedef = 1,
	Function = 2,
	Variable = 3,
	Field = 4,
	Enum_Constant = 5,
	Obj_C_Class = 6,
	Obj_C_Protocol = 7,
	Obj_C_Category = 8,
	Obj_C_Instance_Method = 9,
	Obj_C_Class_Method = 10,
	Obj_C_Property = 11,
	Obj_C_Ivar = 12,
	Enum = 13,
	Struct = 14,
	Union = 15,
	Cxx_Class = 16,
	Cxx_Namespace = 17,
	Cxx_Namespace_Alias = 18,
	Cxx_Static_Variable = 19,
	Cxx_Static_Method = 20,
	Cxx_Instance_Method = 21,
	Cxx_Constructor = 22,
	Cxx_Destructor = 23,
	Cxx_Conversion_Function = 24,
	Cxx_Type_Alias = 25,
	Cxx_Interface = 26,
	Cxx_Concept = 27,
}

Idx_Entity_Language :: enum u32 {
	None = 0,
	C = 1,
	Obj_C = 2,
	Cxx = 3,
	Swift = 4,
}

Idx_Entity_Cxx_Template_Kind :: enum u32 {
	Non_Template = 0,
	Template = 1,
	Template_Partial_Specialization = 2,
	Template_Specialization = 3,
}

Idx_Attr_Kind :: enum u32 {
	Unexposed = 0,
	Ib_Action = 1,
	Ib_Outlet = 2,
	Ib_Outlet_Collection = 3,
}

Idx_Attr_Info :: struct {
	kind: Idx_Attr_Kind,
	cursor: Cursor,
	loc: Idx_Loc,
}

Idx_Entity_Info :: struct {
	kind: Idx_Entity_Kind,
	template_kind: Idx_Entity_Cxx_Template_Kind,
	lang: Idx_Entity_Language,
	name: cstring,
	usr: cstring,
	cursor: Cursor,
	attributes: ^^Idx_Attr_Info,
	num_attributes: u32,
}

Idx_Container_Info :: struct {
	cursor: Cursor,
}

Idx_Ib_Outlet_Collection_Attr_Info :: struct {
	attr_info: ^Idx_Attr_Info,
	objc_class: ^Idx_Entity_Info,
	class_cursor: Cursor,
	class_loc: Idx_Loc,
}

Idx_Decl_Info_Flags :: enum u32 {
	Skipped = 1,
}

Idx_Decl_Info :: struct {
	entity_info: ^Idx_Entity_Info,
	cursor: Cursor,
	loc: Idx_Loc,
	semantic_container: ^Idx_Container_Info,
	lexical_container: ^Idx_Container_Info,
	is_redeclaration: i32,
	is_definition: i32,
	is_container: i32,
	decl_as_container: ^Idx_Container_Info,
	is_implicit: i32,
	attributes: ^^Idx_Attr_Info,
	num_attributes: u32,
	flags: u32,
}

Idx_Obj_C_Container_Kind :: enum u32 {
	Forward_Ref = 0,
	Interface = 1,
	Implementation = 2,
}

Idx_Obj_C_Container_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	kind: Idx_Obj_C_Container_Kind,
}

Idx_Base_Class_Info :: struct {
	base: ^Idx_Entity_Info,
	cursor: Cursor,
	loc: Idx_Loc,
}

Idx_Obj_C_Protocol_Ref_Info :: struct {
	protocol: ^Idx_Entity_Info,
	cursor: Cursor,
	loc: Idx_Loc,
}

Idx_Obj_C_Protocol_Ref_List_Info :: struct {
	protocols: ^^Idx_Obj_C_Protocol_Ref_Info,
	num_protocols: u32,
}

Idx_Obj_C_Interface_Decl_Info :: struct {
	container_info: ^Idx_Obj_C_Container_Decl_Info,
	super_info: ^Idx_Base_Class_Info,
	protocols: ^Idx_Obj_C_Protocol_Ref_List_Info,
}

Idx_Obj_C_Category_Decl_Info :: struct {
	container_info: ^Idx_Obj_C_Container_Decl_Info,
	objc_class: ^Idx_Entity_Info,
	class_cursor: Cursor,
	class_loc: Idx_Loc,
	protocols: ^Idx_Obj_C_Protocol_Ref_List_Info,
}

Idx_Obj_C_Property_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	getter: ^Idx_Entity_Info,
	setter: ^Idx_Entity_Info,
}

Idx_Cxx_Class_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	bases: ^^Idx_Base_Class_Info,
	num_bases: u32,
}

Idx_Entity_Ref_Kind :: enum u32 {
	Direct = 1,
	Implicit = 2,
}

Symbol_Role :: enum u32 {
	None = 0,
	Declaration = 1,
	Definition = 2,
	Reference = 4,
	Read = 8,
	Write = 16,
	Call = 32,
	Dynamic = 64,
	Address_Of = 128,
	Implicit = 256,
}

Idx_Entity_Ref_Info :: struct {
	kind: Idx_Entity_Ref_Kind,
	cursor: Cursor,
	loc: Idx_Loc,
	referenced_entity: ^Idx_Entity_Info,
	parent_entity: ^Idx_Entity_Info,
	container: ^Idx_Container_Info,
	role: Symbol_Role,
}

Indexer_Callbacks :: struct {
	abort_query: proc "c" (_: Client_Data, _: rawptr) -> i32,
	diagnostic: proc "c" (_: Client_Data, _: Diagnostic_Set, _: rawptr),
	entered_main_file: proc "c" (_: Client_Data, _: File, _: rawptr) -> Idx_Client_File,
	pp_included_file: proc "c" (_: Client_Data, _: ^Idx_Included_File_Info) -> Idx_Client_File,
	imported_ast_file: proc "c" (_: Client_Data, _: ^Idx_Imported_Ast_File_Info) -> Idx_Client_Ast_File,
	started_translation_unit: proc "c" (_: Client_Data, _: rawptr) -> Idx_Client_Container,
	index_declaration: proc "c" (_: Client_Data, _: ^Idx_Decl_Info),
	index_entity_reference: proc "c" (_: Client_Data, _: ^Idx_Entity_Ref_Info),
}

Index_Action :: rawptr

Index_Opt_Flags :: enum u32 {
	None = 0,
	Suppress_Redundant_Refs = 1,
	Index_Function_Local_Symbols = 2,
	Index_Implicit_Template_Instantiations = 4,
	Suppress_Warnings = 8,
	Skip_Parsed_Bodies_In_Session = 16,
}

Field_Visitor :: proc "c" (_: Cursor, _: Client_Data) -> Visitor_Result

Binary_Operator_Kind :: enum u32 {
	Invalid = 0,
	Ptr_Mem_D = 1,
	Ptr_Mem_I = 2,
	Mul = 3,
	Div = 4,
	Rem = 5,
	Add = 6,
	Sub = 7,
	Shl = 8,
	Shr = 9,
	Cmp = 10,
	Lt = 11,
	Gt = 12,
	Le = 13,
	Ge = 14,
	Eq = 15,
	Ne = 16,
	And = 17,
	Xor = 18,
	Or = 19,
	L_And = 20,
	L_Or = 21,
	Assign = 22,
	Mul_Assign = 23,
	Div_Assign = 24,
	Rem_Assign = 25,
	Add_Assign = 26,
	Sub_Assign = 27,
	Shl_Assign = 28,
	Shr_Assign = 29,
	And_Assign = 30,
	Xor_Assign = 31,
	Or_Assign = 32,
	Comma = 33,
	Last = 33,
}

Unary_Operator_Kind :: enum u32 {
	Invalid = 0,
	Post_Inc = 1,
	Post_Dec = 2,
	Pre_Inc = 3,
	Pre_Dec = 4,
	Addr_Of = 5,
	Deref = 6,
	Plus = 7,
	Minus = 8,
	Not = 9,
	L_Not = 10,
	Real = 11,
	Imag = 12,
	Extension = 13,
	Coawait = 14,
}

Remapping :: rawptr

foreign lib {
	@(link_name = "clang_createIndex")
	create_index :: proc(exclude_declarations_from_pch: i32, display_diagnostics: i32) -> Index ---
	@(link_name = "clang_disposeIndex")
	dispose_index :: proc(index: Index) ---
	@(link_name = "clang_createIndexWithOptions")
	create_index_with_options :: proc(options: ^Index_Options) -> Index ---
	@(link_name = "clang_CXIndex_setGlobalOptions")
	cx_index_set_global_options :: proc(_: Index, options: u32) ---
	@(link_name = "clang_CXIndex_getGlobalOptions")
	cx_index_get_global_options :: proc(_: Index) -> u32 ---
	@(link_name = "clang_CXIndex_setInvocationEmissionPathOption")
	cx_index_set_invocation_emission_path_option :: proc(_: Index, path: cstring) ---
	@(link_name = "clang_isFileMultipleIncludeGuarded")
	is_file_multiple_include_guarded :: proc(tu: Translation_Unit, file: File) -> u32 ---
	@(link_name = "clang_getFile")
	get_file :: proc(tu: Translation_Unit, file_name: cstring) -> File ---
	@(link_name = "clang_getFileContents")
	get_file_contents :: proc(tu: Translation_Unit, file: File, size: ^uint) -> cstring ---
	@(link_name = "clang_getLocation")
	get_location :: proc(tu: Translation_Unit, file: File, line: u32, column: u32) -> Source_Location ---
	@(link_name = "clang_getLocationForOffset")
	get_location_for_offset :: proc(tu: Translation_Unit, file: File, offset: u32) -> Source_Location ---
	@(link_name = "clang_getSkippedRanges")
	get_skipped_ranges :: proc(tu: Translation_Unit, file: File) -> ^Source_Range_List ---
	@(link_name = "clang_getAllSkippedRanges")
	get_all_skipped_ranges :: proc(tu: Translation_Unit) -> ^Source_Range_List ---
	@(link_name = "clang_getNumDiagnostics")
	get_num_diagnostics :: proc(unit: Translation_Unit) -> u32 ---
	@(link_name = "clang_getDiagnostic")
	get_diagnostic :: proc(unit: Translation_Unit, index: u32) -> Diagnostic ---
	@(link_name = "clang_getDiagnosticSetFromTU")
	get_diagnostic_set_from_tu :: proc(unit: Translation_Unit) -> Diagnostic_Set ---
	@(link_name = "clang_getTranslationUnitSpelling")
	get_translation_unit_spelling :: proc(ct_unit: Translation_Unit) -> String ---
	@(link_name = "clang_createTranslationUnitFromSourceFile")
	create_translation_unit_from_source_file :: proc(c_idx: Index, source_filename: cstring, num_clang_command_line_args: i32, command_line_args: ^cstring, num_unsaved_files: u32, unsaved_files: ^Unsaved_File) -> Translation_Unit ---
	@(link_name = "clang_createTranslationUnit")
	create_translation_unit :: proc(c_idx: Index, ast_filename: cstring) -> Translation_Unit ---
	@(link_name = "clang_createTranslationUnit2")
	create_translation_unit2 :: proc(c_idx: Index, ast_filename: cstring, out_tu: ^Translation_Unit) -> Error_Code ---
	@(link_name = "clang_defaultEditingTranslationUnitOptions")
	default_editing_translation_unit_options :: proc() -> u32 ---
	@(link_name = "clang_parseTranslationUnit")
	parse_translation_unit :: proc(c_idx: Index, source_filename: cstring, command_line_args: ^cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, options: u32) -> Translation_Unit ---
	@(link_name = "clang_parseTranslationUnit2")
	parse_translation_unit2 :: proc(c_idx: Index, source_filename: cstring, command_line_args: ^cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, options: u32, out_tu: ^Translation_Unit) -> Error_Code ---
	@(link_name = "clang_parseTranslationUnit2FullArgv")
	parse_translation_unit2_full_argv :: proc(c_idx: Index, source_filename: cstring, command_line_args: ^cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, options: u32, out_tu: ^Translation_Unit) -> Error_Code ---
	@(link_name = "clang_defaultSaveOptions")
	default_save_options :: proc(tu: Translation_Unit) -> u32 ---
	@(link_name = "clang_saveTranslationUnit")
	save_translation_unit :: proc(tu: Translation_Unit, file_name: cstring, options: u32) -> i32 ---
	@(link_name = "clang_suspendTranslationUnit")
	suspend_translation_unit :: proc(_: Translation_Unit) -> u32 ---
	@(link_name = "clang_disposeTranslationUnit")
	dispose_translation_unit :: proc(_: Translation_Unit) ---
	@(link_name = "clang_defaultReparseOptions")
	default_reparse_options :: proc(tu: Translation_Unit) -> u32 ---
	@(link_name = "clang_reparseTranslationUnit")
	reparse_translation_unit :: proc(tu: Translation_Unit, num_unsaved_files: u32, unsaved_files: ^Unsaved_File, options: u32) -> i32 ---
	@(link_name = "clang_getTUResourceUsageName")
	get_tu_resource_usage_name :: proc(kind: Tu_Resource_Usage_Kind) -> cstring ---
	@(link_name = "clang_getCXTUResourceUsage")
	get_cxtu_resource_usage :: proc(tu: Translation_Unit) -> Tu_Resource_Usage ---
	@(link_name = "clang_disposeCXTUResourceUsage")
	dispose_cxtu_resource_usage :: proc(usage: Tu_Resource_Usage) ---
	@(link_name = "clang_getTranslationUnitTargetInfo")
	get_translation_unit_target_info :: proc(ct_unit: Translation_Unit) -> Target_Info ---
	@(link_name = "clang_TargetInfo_dispose")
	target_info_dispose :: proc(info: Target_Info) ---
	@(link_name = "clang_TargetInfo_getTriple")
	target_info_get_triple :: proc(info: Target_Info) -> String ---
	@(link_name = "clang_TargetInfo_getPointerWidth")
	target_info_get_pointer_width :: proc(info: Target_Info) -> i32 ---
	@(link_name = "clang_getNullCursor")
	get_null_cursor :: proc() -> Cursor ---
	@(link_name = "clang_getTranslationUnitCursor")
	get_translation_unit_cursor :: proc(_: Translation_Unit) -> Cursor ---
	@(link_name = "clang_equalCursors")
	equal_cursors :: proc(_: Cursor, _: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isNull")
	cursor_is_null :: proc(cursor: Cursor) -> i32 ---
	@(link_name = "clang_hashCursor")
	hash_cursor :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_getCursorKind")
	get_cursor_kind :: proc(_: Cursor) -> Cursor_Kind ---
	@(link_name = "clang_isDeclaration")
	is_declaration :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isInvalidDeclaration")
	is_invalid_declaration :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_isReference")
	is_reference :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isExpression")
	is_expression :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isStatement")
	is_statement :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isAttribute")
	is_attribute :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_Cursor_hasAttrs")
	cursor_has_attrs :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_isInvalid")
	is_invalid :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isTranslationUnit")
	is_translation_unit :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isPreprocessing")
	is_preprocessing :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_isUnexposed")
	is_unexposed :: proc(_: Cursor_Kind) -> u32 ---
	@(link_name = "clang_getCursorLinkage")
	get_cursor_linkage :: proc(cursor: Cursor) -> Linkage_Kind ---
	@(link_name = "clang_getCursorVisibility")
	get_cursor_visibility :: proc(cursor: Cursor) -> Visibility_Kind ---
	@(link_name = "clang_getCursorAvailability")
	get_cursor_availability :: proc(cursor: Cursor) -> Availability_Kind ---
	@(link_name = "clang_getCursorPlatformAvailability")
	get_cursor_platform_availability :: proc(cursor: Cursor, always_deprecated: ^i32, deprecated_message: ^String, always_unavailable: ^i32, unavailable_message: ^String, availability: ^Platform_Availability, availability_size: i32) -> i32 ---
	@(link_name = "clang_disposeCXPlatformAvailability")
	dispose_cx_platform_availability :: proc(availability: ^Platform_Availability) ---
	@(link_name = "clang_Cursor_getVarDeclInitializer")
	cursor_get_var_decl_initializer :: proc(cursor: Cursor) -> Cursor ---
	@(link_name = "clang_Cursor_hasVarDeclGlobalStorage")
	cursor_has_var_decl_global_storage :: proc(cursor: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_hasVarDeclExternalStorage")
	cursor_has_var_decl_external_storage :: proc(cursor: Cursor) -> i32 ---
	@(link_name = "clang_getCursorLanguage")
	get_cursor_language :: proc(cursor: Cursor) -> Language_Kind ---
	@(link_name = "clang_getCursorTLSKind")
	get_cursor_tls_kind :: proc(cursor: Cursor) -> Tls_Kind ---
	@(link_name = "clang_Cursor_getTranslationUnit")
	cursor_get_translation_unit :: proc(_: Cursor) -> Translation_Unit ---
	@(link_name = "clang_createCXCursorSet")
	create_cx_cursor_set :: proc() -> Cursor_Set ---
	@(link_name = "clang_disposeCXCursorSet")
	dispose_cx_cursor_set :: proc(cset: Cursor_Set) ---
	@(link_name = "clang_CXCursorSet_contains")
	cx_cursor_set_contains :: proc(cset: Cursor_Set, cursor: Cursor) -> u32 ---
	@(link_name = "clang_CXCursorSet_insert")
	cx_cursor_set_insert :: proc(cset: Cursor_Set, cursor: Cursor) -> u32 ---
	@(link_name = "clang_getCursorSemanticParent")
	get_cursor_semantic_parent :: proc(cursor: Cursor) -> Cursor ---
	@(link_name = "clang_getCursorLexicalParent")
	get_cursor_lexical_parent :: proc(cursor: Cursor) -> Cursor ---
	@(link_name = "clang_getOverriddenCursors")
	get_overridden_cursors :: proc(cursor: Cursor, overridden: ^^Cursor, num_overridden: ^u32) ---
	@(link_name = "clang_disposeOverriddenCursors")
	dispose_overridden_cursors :: proc(overridden: ^Cursor) ---
	@(link_name = "clang_getIncludedFile")
	get_included_file :: proc(cursor: Cursor) -> File ---
	@(link_name = "clang_getCursor")
	get_cursor :: proc(_: Translation_Unit, _: Source_Location) -> Cursor ---
	@(link_name = "clang_getCursorLocation")
	get_cursor_location :: proc(_: Cursor) -> Source_Location ---
	@(link_name = "clang_getCursorExtent")
	get_cursor_extent :: proc(_: Cursor) -> Source_Range ---
	@(link_name = "clang_getCursorType")
	get_cursor_type :: proc(c: Cursor) -> Type ---
	@(link_name = "clang_getTypeSpelling")
	get_type_spelling :: proc(ct: Type) -> String ---
	@(link_name = "clang_getTypedefDeclUnderlyingType")
	get_typedef_decl_underlying_type :: proc(c: Cursor) -> Type ---
	@(link_name = "clang_getEnumDeclIntegerType")
	get_enum_decl_integer_type :: proc(c: Cursor) -> Type ---
	@(link_name = "clang_getEnumConstantDeclValue")
	get_enum_constant_decl_value :: proc(c: Cursor) -> i64 ---
	@(link_name = "clang_getEnumConstantDeclUnsignedValue")
	get_enum_constant_decl_unsigned_value :: proc(c: Cursor) -> u64 ---
	@(link_name = "clang_Cursor_isBitField")
	cursor_is_bit_field :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_getFieldDeclBitWidth")
	get_field_decl_bit_width :: proc(c: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_getNumArguments")
	cursor_get_num_arguments :: proc(c: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_getArgument")
	cursor_get_argument :: proc(c: Cursor, i: u32) -> Cursor ---
	@(link_name = "clang_Cursor_getNumTemplateArguments")
	cursor_get_num_template_arguments :: proc(c: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_getTemplateArgumentKind")
	cursor_get_template_argument_kind :: proc(c: Cursor, i: u32) -> Template_Argument_Kind ---
	@(link_name = "clang_Cursor_getTemplateArgumentType")
	cursor_get_template_argument_type :: proc(c: Cursor, i: u32) -> Type ---
	@(link_name = "clang_Cursor_getTemplateArgumentValue")
	cursor_get_template_argument_value :: proc(c: Cursor, i: u32) -> i64 ---
	@(link_name = "clang_Cursor_getTemplateArgumentUnsignedValue")
	cursor_get_template_argument_unsigned_value :: proc(c: Cursor, i: u32) -> u64 ---
	@(link_name = "clang_equalTypes")
	equal_types :: proc(a: Type, b: Type) -> u32 ---
	@(link_name = "clang_getCanonicalType")
	get_canonical_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_isConstQualifiedType")
	is_const_qualified_type :: proc(t: Type) -> u32 ---
	@(link_name = "clang_Cursor_isMacroFunctionLike")
	cursor_is_macro_function_like :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isMacroBuiltin")
	cursor_is_macro_builtin :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isFunctionInlined")
	cursor_is_function_inlined :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_isVolatileQualifiedType")
	is_volatile_qualified_type :: proc(t: Type) -> u32 ---
	@(link_name = "clang_isRestrictQualifiedType")
	is_restrict_qualified_type :: proc(t: Type) -> u32 ---
	@(link_name = "clang_getAddressSpace")
	get_address_space :: proc(t: Type) -> u32 ---
	@(link_name = "clang_getTypedefName")
	get_typedef_name :: proc(ct: Type) -> String ---
	@(link_name = "clang_getPointeeType")
	get_pointee_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_getUnqualifiedType")
	get_unqualified_type :: proc(ct: Type) -> Type ---
	@(link_name = "clang_getNonReferenceType")
	get_non_reference_type :: proc(ct: Type) -> Type ---
	@(link_name = "clang_getTypeDeclaration")
	get_type_declaration :: proc(t: Type) -> Cursor ---
	@(link_name = "clang_getDeclObjCTypeEncoding")
	get_decl_obj_c_type_encoding :: proc(c: Cursor) -> String ---
	@(link_name = "clang_Type_getObjCEncoding")
	type_get_obj_c_encoding :: proc(type: Type) -> String ---
	@(link_name = "clang_getTypeKindSpelling")
	get_type_kind_spelling :: proc(k: Type_Kind) -> String ---
	@(link_name = "clang_getFunctionTypeCallingConv")
	get_function_type_calling_conv :: proc(t: Type) -> Calling_Conv ---
	@(link_name = "clang_getResultType")
	get_result_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_getExceptionSpecificationType")
	get_exception_specification_type :: proc(t: Type) -> i32 ---
	@(link_name = "clang_getNumArgTypes")
	get_num_arg_types :: proc(t: Type) -> i32 ---
	@(link_name = "clang_getArgType")
	get_arg_type :: proc(t: Type, i: u32) -> Type ---
	@(link_name = "clang_Type_getObjCObjectBaseType")
	type_get_obj_c_object_base_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_Type_getNumObjCProtocolRefs")
	type_get_num_obj_c_protocol_refs :: proc(t: Type) -> u32 ---
	@(link_name = "clang_Type_getObjCProtocolDecl")
	type_get_obj_c_protocol_decl :: proc(t: Type, i: u32) -> Cursor ---
	@(link_name = "clang_Type_getNumObjCTypeArgs")
	type_get_num_obj_c_type_args :: proc(t: Type) -> u32 ---
	@(link_name = "clang_Type_getObjCTypeArg")
	type_get_obj_c_type_arg :: proc(t: Type, i: u32) -> Type ---
	@(link_name = "clang_isFunctionTypeVariadic")
	is_function_type_variadic :: proc(t: Type) -> u32 ---
	@(link_name = "clang_getCursorResultType")
	get_cursor_result_type :: proc(c: Cursor) -> Type ---
	@(link_name = "clang_getCursorExceptionSpecificationType")
	get_cursor_exception_specification_type :: proc(c: Cursor) -> i32 ---
	@(link_name = "clang_isPODType")
	is_pod_type :: proc(t: Type) -> u32 ---
	@(link_name = "clang_getElementType")
	get_element_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_getNumElements")
	get_num_elements :: proc(t: Type) -> i64 ---
	@(link_name = "clang_getArrayElementType")
	get_array_element_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_getArraySize")
	get_array_size :: proc(t: Type) -> i64 ---
	@(link_name = "clang_Type_getNamedType")
	type_get_named_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_Type_isTransparentTagTypedef")
	type_is_transparent_tag_typedef :: proc(t: Type) -> u32 ---
	@(link_name = "clang_Type_getNullability")
	type_get_nullability :: proc(t: Type) -> Type_Nullability_Kind ---
	@(link_name = "clang_Type_getAlignOf")
	type_get_align_of :: proc(t: Type) -> i64 ---
	@(link_name = "clang_Type_getClassType")
	type_get_class_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_Type_getSizeOf")
	type_get_size_of :: proc(t: Type) -> i64 ---
	@(link_name = "clang_Type_getOffsetOf")
	type_get_offset_of :: proc(t: Type, s: cstring) -> i64 ---
	@(link_name = "clang_Type_getModifiedType")
	type_get_modified_type :: proc(t: Type) -> Type ---
	@(link_name = "clang_Type_getValueType")
	type_get_value_type :: proc(ct: Type) -> Type ---
	@(link_name = "clang_Cursor_getOffsetOfField")
	cursor_get_offset_of_field :: proc(c: Cursor) -> i64 ---
	@(link_name = "clang_Cursor_isAnonymous")
	cursor_is_anonymous :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isAnonymousRecordDecl")
	cursor_is_anonymous_record_decl :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isInlineNamespace")
	cursor_is_inline_namespace :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Type_getNumTemplateArguments")
	type_get_num_template_arguments :: proc(t: Type) -> i32 ---
	@(link_name = "clang_Type_getTemplateArgumentAsType")
	type_get_template_argument_as_type :: proc(t: Type, i: u32) -> Type ---
	@(link_name = "clang_Type_getCXXRefQualifier")
	type_get_cxx_ref_qualifier :: proc(t: Type) -> Ref_Qualifier_Kind ---
	@(link_name = "clang_isVirtualBase")
	is_virtual_base :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_getOffsetOfBase")
	get_offset_of_base :: proc(parent: Cursor, base: Cursor) -> i64 ---
	@(link_name = "clang_getCXXAccessSpecifier")
	get_cxx_access_specifier :: proc(_: Cursor) -> Cxx_Access_Specifier ---
	@(link_name = "clang_Cursor_getBinaryOpcode")
	cursor_get_binary_opcode :: proc(c: Cursor) -> Legacy_Binary_Operator_Kind ---
	@(link_name = "clang_Cursor_getBinaryOpcodeStr")
	cursor_get_binary_opcode_str :: proc(op: Legacy_Binary_Operator_Kind) -> String ---
	@(link_name = "clang_Cursor_getStorageClass")
	cursor_get_storage_class :: proc(_: Cursor) -> Storage_Class ---
	@(link_name = "clang_getNumOverloadedDecls")
	get_num_overloaded_decls :: proc(cursor: Cursor) -> u32 ---
	@(link_name = "clang_getOverloadedDecl")
	get_overloaded_decl :: proc(cursor: Cursor, index: u32) -> Cursor ---
	@(link_name = "clang_getIBOutletCollectionType")
	get_ib_outlet_collection_type :: proc(_: Cursor) -> Type ---
	@(link_name = "clang_visitChildren")
	visit_children :: proc(parent: Cursor, visitor: Cursor_Visitor, client_data: Client_Data) -> u32 ---
	@(link_name = "clang_visitChildrenWithBlock")
	visit_children_with_block :: proc(parent: Cursor, block: Cursor_Visitor_Block) -> u32 ---
	@(link_name = "clang_getCursorUSR")
	get_cursor_usr :: proc(_: Cursor) -> String ---
	@(link_name = "clang_constructUSR_ObjCClass")
	construct_usr_obj_c_class :: proc(class_name: cstring) -> String ---
	@(link_name = "clang_constructUSR_ObjCCategory")
	construct_usr_obj_c_category :: proc(class_name: cstring, category_name: cstring) -> String ---
	@(link_name = "clang_constructUSR_ObjCProtocol")
	construct_usr_obj_c_protocol :: proc(protocol_name: cstring) -> String ---
	@(link_name = "clang_constructUSR_ObjCIvar")
	construct_usr_obj_c_ivar :: proc(name: cstring, class_usr: String) -> String ---
	@(link_name = "clang_constructUSR_ObjCMethod")
	construct_usr_obj_c_method :: proc(name: cstring, is_instance_method: u32, class_usr: String) -> String ---
	@(link_name = "clang_constructUSR_ObjCProperty")
	construct_usr_obj_c_property :: proc(property: cstring, class_usr: String) -> String ---
	@(link_name = "clang_getCursorSpelling")
	get_cursor_spelling :: proc(_: Cursor) -> String ---
	@(link_name = "clang_Cursor_getSpellingNameRange")
	cursor_get_spelling_name_range :: proc(_: Cursor, piece_index: u32, options: u32) -> Source_Range ---
	@(link_name = "clang_PrintingPolicy_getProperty")
	printing_policy_get_property :: proc(policy: Printing_Policy, property: Printing_Policy_Property) -> u32 ---
	@(link_name = "clang_PrintingPolicy_setProperty")
	printing_policy_set_property :: proc(policy: Printing_Policy, property: Printing_Policy_Property, value: u32) ---
	@(link_name = "clang_getCursorPrintingPolicy")
	get_cursor_printing_policy :: proc(_: Cursor) -> Printing_Policy ---
	@(link_name = "clang_PrintingPolicy_dispose")
	printing_policy_dispose :: proc(policy: Printing_Policy) ---
	@(link_name = "clang_getCursorPrettyPrinted")
	get_cursor_pretty_printed :: proc(cursor: Cursor, policy: Printing_Policy) -> String ---
	@(link_name = "clang_getTypePrettyPrinted")
	get_type_pretty_printed :: proc(ct: Type, cx_policy: Printing_Policy) -> String ---
	@(link_name = "clang_getFullyQualifiedName")
	get_fully_qualified_name :: proc(ct: Type, policy: Printing_Policy, with_global_ns_prefix: u32) -> String ---
	@(link_name = "clang_getCursorDisplayName")
	get_cursor_display_name :: proc(_: Cursor) -> String ---
	@(link_name = "clang_getCursorReferenced")
	get_cursor_referenced :: proc(_: Cursor) -> Cursor ---
	@(link_name = "clang_getCursorDefinition")
	get_cursor_definition :: proc(_: Cursor) -> Cursor ---
	@(link_name = "clang_isCursorDefinition")
	is_cursor_definition :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_getCanonicalCursor")
	get_canonical_cursor :: proc(_: Cursor) -> Cursor ---
	@(link_name = "clang_Cursor_getObjCSelectorIndex")
	cursor_get_obj_c_selector_index :: proc(_: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_isDynamicCall")
	cursor_is_dynamic_call :: proc(c: Cursor) -> i32 ---
	@(link_name = "clang_Cursor_getReceiverType")
	cursor_get_receiver_type :: proc(c: Cursor) -> Type ---
	@(link_name = "clang_Cursor_getObjCPropertyAttributes")
	cursor_get_obj_c_property_attributes :: proc(c: Cursor, reserved: u32) -> u32 ---
	@(link_name = "clang_Cursor_getObjCPropertyGetterName")
	cursor_get_obj_c_property_getter_name :: proc(c: Cursor) -> String ---
	@(link_name = "clang_Cursor_getObjCPropertySetterName")
	cursor_get_obj_c_property_setter_name :: proc(c: Cursor) -> String ---
	@(link_name = "clang_Cursor_getObjCDeclQualifiers")
	cursor_get_obj_c_decl_qualifiers :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isObjCOptional")
	cursor_is_obj_c_optional :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isVariadic")
	cursor_is_variadic :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_isExternalSymbol")
	cursor_is_external_symbol :: proc(c: Cursor, language: ^String, defined_in: ^String, is_generated: ^u32) -> u32 ---
	@(link_name = "clang_Cursor_getCommentRange")
	cursor_get_comment_range :: proc(c: Cursor) -> Source_Range ---
	@(link_name = "clang_Cursor_getRawCommentText")
	cursor_get_raw_comment_text :: proc(c: Cursor) -> String ---
	@(link_name = "clang_Cursor_getBriefCommentText")
	cursor_get_brief_comment_text :: proc(c: Cursor) -> String ---
	@(link_name = "clang_Cursor_getMangling")
	cursor_get_mangling :: proc(_: Cursor) -> String ---
	@(link_name = "clang_Cursor_getCXXManglings")
	cursor_get_cxx_manglings :: proc(_: Cursor) -> ^String_Set ---
	@(link_name = "clang_Cursor_getObjCManglings")
	cursor_get_obj_c_manglings :: proc(_: Cursor) -> ^String_Set ---
	@(link_name = "clang_Cursor_getGCCAssemblyTemplate")
	cursor_get_gcc_assembly_template :: proc(_: Cursor) -> String ---
	@(link_name = "clang_Cursor_isGCCAssemblyHasGoto")
	cursor_is_gcc_assembly_has_goto :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyNumOutputs")
	cursor_get_gcc_assembly_num_outputs :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyNumInputs")
	cursor_get_gcc_assembly_num_inputs :: proc(_: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyInput")
	cursor_get_gcc_assembly_input :: proc(cursor: Cursor, index: u32, constraint: ^String, expr: ^Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyOutput")
	cursor_get_gcc_assembly_output :: proc(cursor: Cursor, index: u32, constraint: ^String, expr: ^Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyNumClobbers")
	cursor_get_gcc_assembly_num_clobbers :: proc(cursor: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getGCCAssemblyClobber")
	cursor_get_gcc_assembly_clobber :: proc(cursor: Cursor, index: u32) -> String ---
	@(link_name = "clang_Cursor_isGCCAssemblyVolatile")
	cursor_is_gcc_assembly_volatile :: proc(cursor: Cursor) -> u32 ---
	@(link_name = "clang_Cursor_getModule")
	cursor_get_module :: proc(c: Cursor) -> Module ---
	@(link_name = "clang_getModuleForFile")
	get_module_for_file :: proc(_: Translation_Unit, _: File) -> Module ---
	@(link_name = "clang_Module_getASTFile")
	module_get_ast_file :: proc(module: Module) -> File ---
	@(link_name = "clang_Module_getParent")
	module_get_parent :: proc(module: Module) -> Module ---
	@(link_name = "clang_Module_getName")
	module_get_name :: proc(module: Module) -> String ---
	@(link_name = "clang_Module_getFullName")
	module_get_full_name :: proc(module: Module) -> String ---
	@(link_name = "clang_Module_isSystem")
	module_is_system :: proc(module: Module) -> i32 ---
	@(link_name = "clang_Module_getNumTopLevelHeaders")
	module_get_num_top_level_headers :: proc(_: Translation_Unit, module: Module) -> u32 ---
	@(link_name = "clang_Module_getTopLevelHeader")
	module_get_top_level_header :: proc(_: Translation_Unit, module: Module, index: u32) -> File ---
	@(link_name = "clang_CXXConstructor_isConvertingConstructor")
	cxx_constructor_is_converting_constructor :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXConstructor_isCopyConstructor")
	cxx_constructor_is_copy_constructor :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXConstructor_isDefaultConstructor")
	cxx_constructor_is_default_constructor :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXConstructor_isMoveConstructor")
	cxx_constructor_is_move_constructor :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXField_isMutable")
	cxx_field_is_mutable :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isDefaulted")
	cxx_method_is_defaulted :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isDeleted")
	cxx_method_is_deleted :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isPureVirtual")
	cxx_method_is_pure_virtual :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isStatic")
	cxx_method_is_static :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isVirtual")
	cxx_method_is_virtual :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isCopyAssignmentOperator")
	cxx_method_is_copy_assignment_operator :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isMoveAssignmentOperator")
	cxx_method_is_move_assignment_operator :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isExplicit")
	cxx_method_is_explicit :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXRecord_isAbstract")
	cxx_record_is_abstract :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_EnumDecl_isScoped")
	enum_decl_is_scoped :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_CXXMethod_isConst")
	cxx_method_is_const :: proc(c: Cursor) -> u32 ---
	@(link_name = "clang_getTemplateCursorKind")
	get_template_cursor_kind :: proc(c: Cursor) -> Cursor_Kind ---
	@(link_name = "clang_getSpecializedCursorTemplate")
	get_specialized_cursor_template :: proc(c: Cursor) -> Cursor ---
	@(link_name = "clang_getCursorReferenceNameRange")
	get_cursor_reference_name_range :: proc(c: Cursor, name_flags: u32, piece_index: u32) -> Source_Range ---
	@(link_name = "clang_getToken")
	get_token :: proc(tu: Translation_Unit, location: Source_Location) -> ^Token ---
	@(link_name = "clang_getTokenKind")
	get_token_kind :: proc(_: Token) -> Token_Kind ---
	@(link_name = "clang_getTokenSpelling")
	get_token_spelling :: proc(_: Translation_Unit, _: Token) -> String ---
	@(link_name = "clang_getTokenLocation")
	get_token_location :: proc(_: Translation_Unit, _: Token) -> Source_Location ---
	@(link_name = "clang_getTokenExtent")
	get_token_extent :: proc(_: Translation_Unit, _: Token) -> Source_Range ---
	@(link_name = "clang_tokenize")
	tokenize :: proc(tu: Translation_Unit, range: Source_Range, tokens: ^^Token, num_tokens: ^u32) ---
	@(link_name = "clang_annotateTokens")
	annotate_tokens :: proc(tu: Translation_Unit, tokens: ^Token, num_tokens: u32, cursors: ^Cursor) ---
	@(link_name = "clang_disposeTokens")
	dispose_tokens :: proc(tu: Translation_Unit, tokens: ^Token, num_tokens: u32) ---
	@(link_name = "clang_getCursorKindSpelling")
	get_cursor_kind_spelling :: proc(kind: Cursor_Kind) -> String ---
	@(link_name = "clang_getDefinitionSpellingAndExtent")
	get_definition_spelling_and_extent :: proc(_: Cursor, start_buf: ^cstring, end_buf: ^cstring, start_line: ^u32, start_column: ^u32, end_line: ^u32, end_column: ^u32) ---
	@(link_name = "clang_enableStackTraces")
	enable_stack_traces :: proc() ---
	@(link_name = "clang_executeOnThread")
	execute_on_thread :: proc(fn: proc "c" (_: rawptr), user_data: rawptr, stack_size: u32) ---
	@(link_name = "clang_getCompletionChunkKind")
	get_completion_chunk_kind :: proc(completion_string: Completion_String, chunk_number: u32) -> Completion_Chunk_Kind ---
	@(link_name = "clang_getCompletionChunkText")
	get_completion_chunk_text :: proc(completion_string: Completion_String, chunk_number: u32) -> String ---
	@(link_name = "clang_getCompletionChunkCompletionString")
	get_completion_chunk_completion_string :: proc(completion_string: Completion_String, chunk_number: u32) -> Completion_String ---
	@(link_name = "clang_getNumCompletionChunks")
	get_num_completion_chunks :: proc(completion_string: Completion_String) -> u32 ---
	@(link_name = "clang_getCompletionPriority")
	get_completion_priority :: proc(completion_string: Completion_String) -> u32 ---
	@(link_name = "clang_getCompletionAvailability")
	get_completion_availability :: proc(completion_string: Completion_String) -> Availability_Kind ---
	@(link_name = "clang_getCompletionNumAnnotations")
	get_completion_num_annotations :: proc(completion_string: Completion_String) -> u32 ---
	@(link_name = "clang_getCompletionAnnotation")
	get_completion_annotation :: proc(completion_string: Completion_String, annotation_number: u32) -> String ---
	@(link_name = "clang_getCompletionParent")
	get_completion_parent :: proc(completion_string: Completion_String, kind: ^Cursor_Kind) -> String ---
	@(link_name = "clang_getCompletionBriefComment")
	get_completion_brief_comment :: proc(completion_string: Completion_String) -> String ---
	@(link_name = "clang_getCursorCompletionString")
	get_cursor_completion_string :: proc(cursor: Cursor) -> Completion_String ---
	@(link_name = "clang_getCompletionNumFixIts")
	get_completion_num_fix_its :: proc(results: ^Code_Complete_Results, completion_index: u32) -> u32 ---
	@(link_name = "clang_getCompletionFixIt")
	get_completion_fix_it :: proc(results: ^Code_Complete_Results, completion_index: u32, fixit_index: u32, replacement_range: ^Source_Range) -> String ---
	@(link_name = "clang_defaultCodeCompleteOptions")
	default_code_complete_options :: proc() -> u32 ---
	@(link_name = "clang_codeCompleteAt")
	code_complete_at :: proc(tu: Translation_Unit, complete_filename: cstring, complete_line: u32, complete_column: u32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, options: u32) -> ^Code_Complete_Results ---
	@(link_name = "clang_sortCodeCompletionResults")
	sort_code_completion_results :: proc(results: ^Completion_Result, num_results: u32) ---
	@(link_name = "clang_disposeCodeCompleteResults")
	dispose_code_complete_results :: proc(results: ^Code_Complete_Results) ---
	@(link_name = "clang_codeCompleteGetNumDiagnostics")
	code_complete_get_num_diagnostics :: proc(results: ^Code_Complete_Results) -> u32 ---
	@(link_name = "clang_codeCompleteGetDiagnostic")
	code_complete_get_diagnostic :: proc(results: ^Code_Complete_Results, index: u32) -> Diagnostic ---
	@(link_name = "clang_codeCompleteGetContexts")
	code_complete_get_contexts :: proc(results: ^Code_Complete_Results) -> u64 ---
	@(link_name = "clang_codeCompleteGetContainerKind")
	code_complete_get_container_kind :: proc(results: ^Code_Complete_Results, is_incomplete: ^u32) -> Cursor_Kind ---
	@(link_name = "clang_codeCompleteGetContainerUSR")
	code_complete_get_container_usr :: proc(results: ^Code_Complete_Results) -> String ---
	@(link_name = "clang_codeCompleteGetObjCSelector")
	code_complete_get_obj_c_selector :: proc(results: ^Code_Complete_Results) -> String ---
	@(link_name = "clang_getClangVersion")
	get_clang_version :: proc() -> String ---
	@(link_name = "clang_toggleCrashRecovery")
	toggle_crash_recovery :: proc(is_enabled: u32) ---
	@(link_name = "clang_getInclusions")
	get_inclusions :: proc(tu: Translation_Unit, visitor: Inclusion_Visitor, client_data: Client_Data) ---
	@(link_name = "clang_Cursor_Evaluate")
	cursor_evaluate :: proc(c: Cursor) -> Eval_Result ---
	@(link_name = "clang_EvalResult_getKind")
	eval_result_get_kind :: proc(e: Eval_Result) -> Eval_Result_Kind ---
	@(link_name = "clang_EvalResult_getAsInt")
	eval_result_get_as_int :: proc(e: Eval_Result) -> i32 ---
	@(link_name = "clang_EvalResult_getAsLongLong")
	eval_result_get_as_long_long :: proc(e: Eval_Result) -> i64 ---
	@(link_name = "clang_EvalResult_isUnsignedInt")
	eval_result_is_unsigned_int :: proc(e: Eval_Result) -> u32 ---
	@(link_name = "clang_EvalResult_getAsUnsigned")
	eval_result_get_as_unsigned :: proc(e: Eval_Result) -> u64 ---
	@(link_name = "clang_EvalResult_getAsDouble")
	eval_result_get_as_double :: proc(e: Eval_Result) -> f64 ---
	@(link_name = "clang_EvalResult_getAsStr")
	eval_result_get_as_str :: proc(e: Eval_Result) -> cstring ---
	@(link_name = "clang_EvalResult_dispose")
	eval_result_dispose :: proc(e: Eval_Result) ---
	@(link_name = "clang_findReferencesInFile")
	find_references_in_file :: proc(cursor: Cursor, file: File, visitor: Cursor_And_Range_Visitor) -> Result ---
	@(link_name = "clang_findIncludesInFile")
	find_includes_in_file :: proc(tu: Translation_Unit, file: File, visitor: Cursor_And_Range_Visitor) -> Result ---
	@(link_name = "clang_findReferencesInFileWithBlock")
	find_references_in_file_with_block :: proc(_: Cursor, _: File, _: Cursor_And_Range_Visitor_Block) -> Result ---
	@(link_name = "clang_findIncludesInFileWithBlock")
	find_includes_in_file_with_block :: proc(_: Translation_Unit, _: File, _: Cursor_And_Range_Visitor_Block) -> Result ---
	@(link_name = "clang_index_isEntityObjCContainerKind")
	index_is_entity_obj_c_container_kind :: proc(_: Idx_Entity_Kind) -> i32 ---
	@(link_name = "clang_index_getObjCContainerDeclInfo")
	index_get_obj_c_container_decl_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Obj_C_Container_Decl_Info ---
	@(link_name = "clang_index_getObjCInterfaceDeclInfo")
	index_get_obj_c_interface_decl_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Obj_C_Interface_Decl_Info ---
	@(link_name = "clang_index_getObjCCategoryDeclInfo")
	index_get_obj_c_category_decl_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Obj_C_Category_Decl_Info ---
	@(link_name = "clang_index_getObjCProtocolRefListInfo")
	index_get_obj_c_protocol_ref_list_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Obj_C_Protocol_Ref_List_Info ---
	@(link_name = "clang_index_getObjCPropertyDeclInfo")
	index_get_obj_c_property_decl_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Obj_C_Property_Decl_Info ---
	@(link_name = "clang_index_getIBOutletCollectionAttrInfo")
	index_get_ib_outlet_collection_attr_info :: proc(_: ^Idx_Attr_Info) -> ^Idx_Ib_Outlet_Collection_Attr_Info ---
	@(link_name = "clang_index_getCXXClassDeclInfo")
	index_get_cxx_class_decl_info :: proc(_: ^Idx_Decl_Info) -> ^Idx_Cxx_Class_Decl_Info ---
	@(link_name = "clang_index_getClientContainer")
	index_get_client_container :: proc(_: ^Idx_Container_Info) -> Idx_Client_Container ---
	@(link_name = "clang_index_setClientContainer")
	index_set_client_container :: proc(_: ^Idx_Container_Info, _: Idx_Client_Container) ---
	@(link_name = "clang_index_getClientEntity")
	index_get_client_entity :: proc(_: ^Idx_Entity_Info) -> Idx_Client_Entity ---
	@(link_name = "clang_index_setClientEntity")
	index_set_client_entity :: proc(_: ^Idx_Entity_Info, _: Idx_Client_Entity) ---
	@(link_name = "clang_IndexAction_create")
	index_action_create :: proc(c_idx: Index) -> Index_Action ---
	@(link_name = "clang_IndexAction_dispose")
	index_action_dispose :: proc(_: Index_Action) ---
	@(link_name = "clang_indexSourceFile")
	index_source_file :: proc(_: Index_Action, client_data: Client_Data, index_callbacks: ^Indexer_Callbacks, index_callbacks_size: u32, index_options: u32, source_filename: cstring, command_line_args: ^cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, out_tu: ^Translation_Unit, tu_options: u32) -> i32 ---
	@(link_name = "clang_indexSourceFileFullArgv")
	index_source_file_full_argv :: proc(_: Index_Action, client_data: Client_Data, index_callbacks: ^Indexer_Callbacks, index_callbacks_size: u32, index_options: u32, source_filename: cstring, command_line_args: ^cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, out_tu: ^Translation_Unit, tu_options: u32) -> i32 ---
	@(link_name = "clang_indexTranslationUnit")
	index_translation_unit :: proc(_: Index_Action, client_data: Client_Data, index_callbacks: ^Indexer_Callbacks, index_callbacks_size: u32, index_options: u32, _: Translation_Unit) -> i32 ---
	@(link_name = "clang_indexLoc_getFileLocation")
	index_loc_get_file_location :: proc(loc: Idx_Loc, index_file: ^Idx_Client_File, file: ^File, line: ^u32, column: ^u32, offset: ^u32) ---
	@(link_name = "clang_indexLoc_getCXSourceLocation")
	index_loc_get_cx_source_location :: proc(loc: Idx_Loc) -> Source_Location ---
	@(link_name = "clang_Type_visitFields")
	type_visit_fields :: proc(t: Type, visitor: Field_Visitor, client_data: Client_Data) -> u32 ---
	@(link_name = "clang_visitCXXBaseClasses")
	visit_cxx_base_classes :: proc(t: Type, visitor: Field_Visitor, client_data: Client_Data) -> u32 ---
	@(link_name = "clang_visitCXXMethods")
	visit_cxx_methods :: proc(t: Type, visitor: Field_Visitor, client_data: Client_Data) -> u32 ---
	@(link_name = "clang_getBinaryOperatorKindSpelling")
	get_binary_operator_kind_spelling :: proc(kind: Binary_Operator_Kind) -> String ---
	@(link_name = "clang_getCursorBinaryOperatorKind")
	get_cursor_binary_operator_kind :: proc(cursor: Cursor) -> Binary_Operator_Kind ---
	@(link_name = "clang_getUnaryOperatorKindSpelling")
	get_unary_operator_kind_spelling :: proc(kind: Unary_Operator_Kind) -> String ---
	@(link_name = "clang_getCursorUnaryOperatorKind")
	get_cursor_unary_operator_kind :: proc(cursor: Cursor) -> Unary_Operator_Kind ---
	@(link_name = "clang_getRemappings")
	get_remappings :: proc(_: cstring) -> Remapping ---
	@(link_name = "clang_getRemappingsFromFileList")
	get_remappings_from_file_list :: proc(_: ^cstring, _: u32) -> Remapping ---
	@(link_name = "clang_remap_getNumFiles")
	remap_get_num_files :: proc(_: Remapping) -> u32 ---
	@(link_name = "clang_remap_getFilenames")
	remap_get_filenames :: proc(_: Remapping, _: u32, _: ^String, _: ^String) ---
	@(link_name = "clang_remap_dispose")
	remap_dispose :: proc(_: Remapping) ---
}
