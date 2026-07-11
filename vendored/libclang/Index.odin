package clang

foreign import lib "system:clang"

VERSION_MAJOR :: 0
VERSION_MINOR :: 64
Index :: distinct rawptr

Target_Info :: distinct rawptr

Translation_Unit :: distinct rawptr

Client_Data :: distinct rawptr

Unsaved_File :: struct {
	filename: cstring,
	contents: cstring,
	length:   u64,
}

Availability_Kind :: enum u32 {
	Available,
	Deprecated,
	Not_Available,
	Not_Accessible,
}

Version :: struct {
	major:    i32,
	minor:    i32,
	subminor: i32,
}

Cursor_Exception_Specification_Kind :: enum u32 {
	None,
	Dynamic_None,
	Dynamic,
	Ms_Any,
	Basic_Noexcept,
	Computed_Noexcept,
	Unevaluated,
	Uninstantiated,
	Unparsed,
	No_Throw,
}

Choice :: enum u32 {
	Default,
	Enabled,
	Disabled,
}

Global_Opt_Flags :: enum u32 {
	None,
	Thread_Background_Priority_For_Indexing,
	Thread_Background_Priority_For_Editing,
	Thread_Background_Priority_For_All,
}

Index_Options :: struct {
	size:                                    u32,
	thread_background_priority_for_indexing: u8,
	thread_background_priority_for_editing:  u8,
	using _:                                 bit_field u16 {
		exclude_declarations_from_pch: u16 | 1,
		display_diagnostics:           u16 | 1,
		store_preambles_in_memory:     u16 | 1,
		_:                             u16 | 13,
	},
	preamble_storage_path:                   cstring,
	invocation_emission_path:                cstring,
}

Translation_Unit_Flag :: enum u32 {
	Detailed_Preprocessing_Record,
	Incomplete,
	Precompiled_Preamble,
	Cache_Completion_Results,
	For_Serialization,
	Cxx_Chained_Pch,
	Skip_Function_Bodies,
	Include_Brief_Comments_In_Code_Completion,
	Create_Preamble_On_First_Parse,
	Keep_Going,
	Single_File_Parse,
	Limit_Skip_Function_Bodies_To_Preamble,
	Include_Attributed_Types,
	Visit_Implicit_Attributes,
	Ignore_Non_Errors_From_Included_Files,
	Retain_Excluded_Conditional_Blocks,
}

Save_Translation_Unit_Flags :: enum u32 {
	None,
}

Save_Error :: enum u32 {
	None,
	Unknown,
	Translation_Errors,
	Invalid_Tu,
}

Reparse_Flags :: enum u32 {
	None,
}

Tu_Resource_Usage_Kind :: enum u32 {
	Ast = 1,
	Identifiers,
	Selectors,
	Global_Completion_Results,
	Source_Manager_Content_Cache,
	Ast_Side_Tables,
	Source_Manager_Membuffer_Malloc,
	Source_Manager_Membuffer_M_Map,
	External_Ast_Source_Membuffer_Malloc,
	External_Ast_Source_Membuffer_M_Map,
	Preprocessor,
	Preprocessing_Record,
	Source_Manager_Data_Structures,
	Preprocessor_Header_Search,
	Memory_In_Bytes_Begin = 1,
	Memory_In_Bytes_End = 14,
	First = 1,
	Last = 14,
}

Tu_Resource_Usage_Entry :: struct {
	kind:   Tu_Resource_Usage_Kind,
	amount: u64,
}

Tu_Resource_Usage :: struct {
	data:        rawptr,
	num_entries: u32,
	entries:     ^Tu_Resource_Usage_Entry,
}

Cursor_Kind :: enum u32 {
	Unexposed_Decl = 1,
	Struct_Decl,
	Union_Decl,
	Class_Decl,
	Enum_Decl,
	Field_Decl,
	Enum_Constant_Decl,
	Function_Decl,
	Var_Decl,
	Parm_Decl,
	Obj_C_Interface_Decl,
	Obj_C_Category_Decl,
	Obj_C_Protocol_Decl,
	Obj_C_Property_Decl,
	Obj_C_Ivar_Decl,
	Obj_C_Instance_Method_Decl,
	Obj_C_Class_Method_Decl,
	Obj_C_Implementation_Decl,
	Obj_C_Category_Impl_Decl,
	Typedef_Decl,
	Cxx_Method,
	Namespace,
	Linkage_Spec,
	Constructor,
	Destructor,
	Conversion_Function,
	Template_Type_Parameter,
	Non_Type_Template_Parameter,
	Template_Template_Parameter,
	Function_Template,
	Class_Template,
	Class_Template_Partial_Specialization,
	Namespace_Alias,
	Using_Directive,
	Using_Declaration,
	Type_Alias_Decl,
	Obj_C_Synthesize_Decl,
	Obj_C_Dynamic_Decl,
	Cxx_Access_Specifier,
	First_Decl = 1,
	Last_Decl = 39,
	First_Ref,
	Obj_C_Super_Class_Ref = 40,
	Obj_C_Protocol_Ref,
	Obj_C_Class_Ref,
	Type_Ref,
	Cxx_Base_Specifier,
	Template_Ref,
	Namespace_Ref,
	Member_Ref,
	Label_Ref,
	Overloaded_Decl_Ref,
	Variable_Ref,
	Last_Ref = 50,
	First_Invalid = 70,
	Invalid_File = 70,
	No_Decl_Found,
	Not_Implemented,
	Invalid_Code,
	Last_Invalid = 73,
	First_Expr = 100,
	Unexposed_Expr = 100,
	Decl_Ref_Expr,
	Member_Ref_Expr,
	Call_Expr,
	Obj_C_Message_Expr,
	Block_Expr,
	Integer_Literal,
	Floating_Literal,
	Imaginary_Literal,
	String_Literal,
	Character_Literal,
	Paren_Expr,
	Unary_Operator,
	Array_Subscript_Expr,
	Binary_Operator,
	Compound_Assign_Operator,
	Conditional_Operator,
	C_Style_Cast_Expr,
	Compound_Literal_Expr,
	Init_List_Expr,
	Addr_Label_Expr,
	Stmt_Expr,
	Generic_Selection_Expr,
	Gnu_Null_Expr,
	Cxx_Static_Cast_Expr,
	Cxx_Dynamic_Cast_Expr,
	Cxx_Reinterpret_Cast_Expr,
	Cxx_Const_Cast_Expr,
	Cxx_Functional_Cast_Expr,
	Cxx_Typeid_Expr,
	Cxx_Bool_Literal_Expr,
	Cxx_Null_Ptr_Literal_Expr,
	Cxx_This_Expr,
	Cxx_Throw_Expr,
	Cxx_New_Expr,
	Cxx_Delete_Expr,
	Unary_Expr,
	Obj_C_String_Literal,
	Obj_C_Encode_Expr,
	Obj_C_Selector_Expr,
	Obj_C_Protocol_Expr,
	Obj_C_Bridged_Cast_Expr,
	Pack_Expansion_Expr,
	Size_Of_Pack_Expr,
	Lambda_Expr,
	Obj_C_Bool_Literal_Expr,
	Obj_C_Self_Expr,
	Array_Section_Expr,
	Obj_C_Availability_Check_Expr,
	Fixed_Point_Literal,
	Omp_Array_Shaping_Expr,
	Omp_Iterator_Expr,
	Cxx_Addrspace_Cast_Expr,
	Concept_Specialization_Expr,
	Requires_Expr,
	Cxx_Paren_List_Init_Expr,
	Pack_Indexing_Expr,
	Last_Expr = 156,
	First_Stmt = 200,
	Unexposed_Stmt = 200,
	Label_Stmt,
	Compound_Stmt,
	Case_Stmt,
	Default_Stmt,
	If_Stmt,
	Switch_Stmt,
	While_Stmt,
	Do_Stmt,
	For_Stmt,
	Goto_Stmt,
	Indirect_Goto_Stmt,
	Continue_Stmt,
	Break_Stmt,
	Return_Stmt,
	Gcc_Asm_Stmt,
	Asm_Stmt = 215,
	Obj_C_At_Try_Stmt,
	Obj_C_At_Catch_Stmt,
	Obj_C_At_Finally_Stmt,
	Obj_C_At_Throw_Stmt,
	Obj_C_At_Synchronized_Stmt,
	Obj_C_Autorelease_Pool_Stmt,
	Obj_C_For_Collection_Stmt,
	Cxx_Catch_Stmt,
	Cxx_Try_Stmt,
	Cxx_For_Range_Stmt,
	Seh_Try_Stmt,
	Seh_Except_Stmt,
	Seh_Finally_Stmt,
	Ms_Asm_Stmt,
	Null_Stmt,
	Decl_Stmt,
	Omp_Parallel_Directive,
	Omp_Simd_Directive,
	Omp_For_Directive,
	Omp_Sections_Directive,
	Omp_Section_Directive,
	Omp_Single_Directive,
	Omp_Parallel_For_Directive,
	Omp_Parallel_Sections_Directive,
	Omp_Task_Directive,
	Omp_Master_Directive,
	Omp_Critical_Directive,
	Omp_Taskyield_Directive,
	Omp_Barrier_Directive,
	Omp_Taskwait_Directive,
	Omp_Flush_Directive,
	Seh_Leave_Stmt,
	Omp_Ordered_Directive,
	Omp_Atomic_Directive,
	Omp_For_Simd_Directive,
	Omp_Parallel_For_Simd_Directive,
	Omp_Target_Directive,
	Omp_Teams_Directive,
	Omp_Taskgroup_Directive,
	Omp_Cancellation_Point_Directive,
	Omp_Cancel_Directive,
	Omp_Target_Data_Directive,
	Omp_Task_Loop_Directive,
	Omp_Task_Loop_Simd_Directive,
	Omp_Distribute_Directive,
	Omp_Target_Enter_Data_Directive,
	Omp_Target_Exit_Data_Directive,
	Omp_Target_Parallel_Directive,
	Omp_Target_Parallel_For_Directive,
	Omp_Target_Update_Directive,
	Omp_Distribute_Parallel_For_Directive,
	Omp_Distribute_Parallel_For_Simd_Directive,
	Omp_Distribute_Simd_Directive,
	Omp_Target_Parallel_For_Simd_Directive,
	Omp_Target_Simd_Directive,
	Omp_Teams_Distribute_Directive,
	Omp_Teams_Distribute_Simd_Directive,
	Omp_Teams_Distribute_Parallel_For_Simd_Directive,
	Omp_Teams_Distribute_Parallel_For_Directive,
	Omp_Target_Teams_Directive,
	Omp_Target_Teams_Distribute_Directive,
	Omp_Target_Teams_Distribute_Parallel_For_Directive,
	Omp_Target_Teams_Distribute_Parallel_For_Simd_Directive,
	Omp_Target_Teams_Distribute_Simd_Directive,
	Builtin_Bit_Cast_Expr,
	Omp_Master_Task_Loop_Directive,
	Omp_Parallel_Master_Task_Loop_Directive,
	Omp_Master_Task_Loop_Simd_Directive,
	Omp_Parallel_Master_Task_Loop_Simd_Directive,
	Omp_Parallel_Master_Directive,
	Omp_Depobj_Directive,
	Omp_Scan_Directive,
	Omp_Tile_Directive,
	Omp_Canonical_Loop,
	Omp_Interop_Directive,
	Omp_Dispatch_Directive,
	Omp_Masked_Directive,
	Omp_Unroll_Directive,
	Omp_Meta_Directive,
	Omp_Generic_Loop_Directive,
	Omp_Teams_Generic_Loop_Directive,
	Omp_Target_Teams_Generic_Loop_Directive,
	Omp_Parallel_Generic_Loop_Directive,
	Omp_Target_Parallel_Generic_Loop_Directive,
	Omp_Parallel_Masked_Directive,
	Omp_Masked_Task_Loop_Directive,
	Omp_Masked_Task_Loop_Simd_Directive,
	Omp_Parallel_Masked_Task_Loop_Directive,
	Omp_Parallel_Masked_Task_Loop_Simd_Directive,
	Omp_Error_Directive,
	Omp_Scope_Directive,
	Omp_Reverse_Directive,
	Omp_Interchange_Directive,
	Omp_Assume_Directive,
	Omp_Stripe_Directive,
	Omp_Fuse_Directive,
	Open_Acc_Compute_Construct = 320,
	Open_Acc_Loop_Construct,
	Open_Acc_Combined_Construct,
	Open_Acc_Data_Construct,
	Open_Acc_Enter_Data_Construct,
	Open_Acc_Exit_Data_Construct,
	Open_Acc_Host_Data_Construct,
	Open_Acc_Wait_Construct,
	Open_Acc_Init_Construct,
	Open_Acc_Shutdown_Construct,
	Open_Acc_Set_Construct,
	Open_Acc_Update_Construct,
	Open_Acc_Atomic_Construct,
	Open_Acc_Cache_Construct,
	Last_Stmt = 333,
	Translation_Unit = 350,
	First_Attr = 400,
	Unexposed_Attr = 400,
	Ib_Action_Attr,
	Ib_Outlet_Attr,
	Ib_Outlet_Collection_Attr,
	Cxx_Final_Attr,
	Cxx_Override_Attr,
	Annotate_Attr,
	Asm_Label_Attr,
	Packed_Attr,
	Pure_Attr,
	Const_Attr,
	No_Duplicate_Attr,
	Cuda_Constant_Attr,
	Cuda_Device_Attr,
	Cuda_Global_Attr,
	Cuda_Host_Attr,
	Cuda_Shared_Attr,
	Visibility_Attr,
	Dll_Export,
	Dll_Import,
	Ns_Returns_Retained,
	Ns_Returns_Not_Retained,
	Ns_Returns_Autoreleased,
	Ns_Consumes_Self,
	Ns_Consumed,
	Obj_C_Exception,
	Obj_Cns_Object,
	Obj_C_Independent_Class,
	Obj_C_Precise_Lifetime,
	Obj_C_Returns_Inner_Pointer,
	Obj_C_Requires_Super,
	Obj_C_Root_Class,
	Obj_C_Subclassing_Restricted,
	Obj_C_Explicit_Protocol_Impl,
	Obj_C_Designated_Initializer,
	Obj_C_Runtime_Visible,
	Obj_C_Boxable,
	Flag_Enum,
	Convergent_Attr,
	Warn_Unused_Attr,
	Warn_Unused_Result_Attr,
	Aligned_Attr,
	Last_Attr = 441,
	Preprocessing_Directive = 500,
	Macro_Definition,
	Macro_Expansion,
	Macro_Instantiation = 502,
	Inclusion_Directive,
	First_Preprocessing = 500,
	Last_Preprocessing = 503,
	Module_Import_Decl = 600,
	Type_Alias_Template_Decl,
	Static_Assert,
	Friend_Decl,
	Concept_Decl,
	First_Extra_Decl = 600,
	Last_Extra_Decl = 604,
	Overload_Candidate = 700,
}

Cursor :: struct {
	kind:  Cursor_Kind,
	xdata: i32,
	data:  [3]rawptr,
}

Linkage_Kind :: enum u32 {
	Invalid,
	No_Linkage,
	Internal,
	Unique_External,
	External,
}

Visibility_Kind :: enum u32 {
	Invalid,
	Hidden,
	Protected,
	Default,
}

Platform_Availability :: struct {
	platform:    String,
	introduced:  Version,
	deprecated:  Version,
	obsoleted:   Version,
	unavailable: i32,
	message:     String,
}

Language_Kind :: enum u32 {
	Invalid,
	C,
	Obj_C,
	C_Plus_Plus,
}

Tls_Kind :: enum u32 {
	None,
	Dynamic,
	Static,
}

Cursor_Set :: distinct rawptr

Type_Kind :: enum u32 {
	Invalid,
	Unexposed,
	Void,
	Bool,
	Char_U,
	U_Char,
	Char16,
	Char32,
	U_Short,
	U_Int,
	U_Long,
	U_Long_Long,
	U_Int128,
	Char_S,
	S_Char,
	W_Char,
	Short,
	Int,
	Long,
	Long_Long,
	Int128,
	Float,
	Double,
	Long_Double,
	Null_Ptr,
	Overload,
	Dependent,
	Obj_C_Id,
	Obj_C_Class,
	Obj_C_Sel,
	Float128,
	Half,
	Float16,
	Short_Accum,
	Accum,
	Long_Accum,
	U_Short_Accum,
	U_Accum,
	U_Long_Accum,
	B_Float16,
	Ibm128,
	First_Builtin = 2,
	Last_Builtin = 40,
	Complex = 100,
	Pointer,
	Block_Pointer,
	L_Value_Reference,
	R_Value_Reference,
	Record,
	Enum,
	Typedef,
	Obj_C_Interface,
	Obj_C_Object_Pointer,
	Function_No_Proto,
	Function_Proto,
	Constant_Array,
	Vector,
	Incomplete_Array,
	Variable_Array,
	Dependent_Sized_Array,
	Member_Pointer,
	Auto,
	Elaborated,
	Pipe,
	Ocl_Image1d_Ro,
	Ocl_Image1d_Array_Ro,
	Ocl_Image1d_Buffer_Ro,
	Ocl_Image2d_Ro,
	Ocl_Image2d_Array_Ro,
	Ocl_Image2d_Depth_Ro,
	Ocl_Image2d_Array_Depth_Ro,
	Ocl_Image2d_Msaaro,
	Ocl_Image2d_Array_Msaaro,
	Ocl_Image2d_Msaa_Depth_Ro,
	Ocl_Image2d_Array_Msaa_Depth_Ro,
	Ocl_Image3d_Ro,
	Ocl_Image1d_Wo,
	Ocl_Image1d_Array_Wo,
	Ocl_Image1d_Buffer_Wo,
	Ocl_Image2d_Wo,
	Ocl_Image2d_Array_Wo,
	Ocl_Image2d_Depth_Wo,
	Ocl_Image2d_Array_Depth_Wo,
	Ocl_Image2d_Msaawo,
	Ocl_Image2d_Array_Msaawo,
	Ocl_Image2d_Msaa_Depth_Wo,
	Ocl_Image2d_Array_Msaa_Depth_Wo,
	Ocl_Image3d_Wo,
	Ocl_Image1d_Rw,
	Ocl_Image1d_Array_Rw,
	Ocl_Image1d_Buffer_Rw,
	Ocl_Image2d_Rw,
	Ocl_Image2d_Array_Rw,
	Ocl_Image2d_Depth_Rw,
	Ocl_Image2d_Array_Depth_Rw,
	Ocl_Image2d_Msaarw,
	Ocl_Image2d_Array_Msaarw,
	Ocl_Image2d_Msaa_Depth_Rw,
	Ocl_Image2d_Array_Msaa_Depth_Rw,
	Ocl_Image3d_Rw,
	Ocl_Sampler,
	Ocl_Event,
	Ocl_Queue,
	Ocl_Reserve_Id,
	Obj_C_Object,
	Obj_C_Type_Param,
	Attributed,
	Ocl_Intel_Subgroup_Avc_Mce_Payload,
	Ocl_Intel_Subgroup_Avc_Ime_Payload,
	Ocl_Intel_Subgroup_Avc_Ref_Payload,
	Ocl_Intel_Subgroup_Avc_Sic_Payload,
	Ocl_Intel_Subgroup_Avc_Mce_Result,
	Ocl_Intel_Subgroup_Avc_Ime_Result,
	Ocl_Intel_Subgroup_Avc_Ref_Result,
	Ocl_Intel_Subgroup_Avc_Sic_Result,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Single_Reference_Streamout,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Dual_Reference_Streamout,
	Ocl_Intel_Subgroup_Avc_Ime_Single_Reference_Streamin,
	Ocl_Intel_Subgroup_Avc_Ime_Dual_Reference_Streamin,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Single_Ref_Streamout = 172,
	Ocl_Intel_Subgroup_Avc_Ime_Result_Dual_Ref_Streamout,
	Ocl_Intel_Subgroup_Avc_Ime_Single_Ref_Streamin,
	Ocl_Intel_Subgroup_Avc_Ime_Dual_Ref_Streamin,
	Ext_Vector,
	Atomic,
	Btf_Tag_Attributed,
	Hlsl_Resource,
	Hlsl_Attributed_Resource,
	Hlsl_Inline_Spirv,
}

Calling_Conv :: enum u32 {
	Default,
	C,
	X86_Std_Call,
	X86_Fast_Call,
	X86_This_Call,
	X86_Pascal,
	Aapcs,
	Aapcs_Vfp,
	X86_Reg_Call,
	Intel_Ocl_Bicc,
	Win64,
	X86_64_Win64 = 10,
	X86_64_Sys_V,
	X86_Vector_Call,
	Swift,
	Preserve_Most,
	Preserve_All,
	A_Arch64_Vector_Call,
	Swift_Async,
	A_Arch64_Svepcs,
	M68k_Rtd,
	Preserve_None,
	Riscv_Vector_Call,
	Riscvvls_Call_32,
	Riscvvls_Call_64,
	Riscvvls_Call_128,
	Riscvvls_Call_256,
	Riscvvls_Call_512,
	Riscvvls_Call_1024,
	Riscvvls_Call_2048,
	Riscvvls_Call_4096,
	Riscvvls_Call_8192,
	Riscvvls_Call_16384,
	Riscvvls_Call_32768,
	Riscvvls_Call_65536,
	Invalid = 100,
	Unexposed = 200,
}

Type :: struct {
	kind: Type_Kind,
	data: [2]rawptr,
}

Template_Argument_Kind :: enum u32 {
	Null,
	Type,
	Declaration,
	Null_Ptr,
	Integral,
	Template,
	Template_Expansion,
	Expression,
	Pack,
	Invalid,
}

Type_Nullability_Kind :: enum u32 {
	Non_Null,
	Nullable,
	Unspecified,
	Invalid,
	Nullable_Result,
}

Type_Layout_Error :: enum i32 {
	Invalid            = -1,
	Incomplete         = -2,
	Dependent          = -3,
	Not_Constant_Size  = -4,
	Invalid_Field_Name = -5,
	Undeduced          = -6,
}

Ref_Qualifier_Kind :: enum u32 {
	None,
	L_Value,
	R_Value,
}

Cxx_Access_Specifier :: enum u32 {
	Cxx_Invalid_Access_Specifier,
	Cxx_Public,
	Cxx_Protected,
	Cxx_Private,
}

Storage_Class :: enum u32 {
	Invalid,
	None,
	Extern,
	Static,
	Private_Extern,
	Open_Cl_Work_Group_Local,
	Auto,
	Register,
}

Legacy_Binary_Operator_Kind :: enum u32 {
	Invalid,
	Ptr_Mem_D,
	Ptr_Mem_I,
	Mul,
	Div,
	Rem,
	Add,
	Sub,
	Shl,
	Shr,
	Cmp,
	Lt,
	Gt,
	Le,
	Ge,
	Eq,
	Ne,
	And,
	Xor,
	Or,
	L_And,
	L_Or,
	Assign,
	Mul_Assign,
	Div_Assign,
	Rem_Assign,
	Add_Assign,
	Sub_Assign,
	Shl_Assign,
	Shr_Assign,
	And_Assign,
	Xor_Assign,
	Or_Assign,
	Comma,
	Last = 33,
}

Child_Visit_Result :: enum u32 {
	Break,
	Continue,
	Recurse,
}

Cursor_Visitor :: proc "c" (_: Cursor, _: Cursor, _: Client_Data) -> Child_Visit_Result

Cursor_Visitor_Block :: distinct rawptr

Printing_Policy :: rawptr

Printing_Policy_Property :: enum u32 {
	Indentation,
	Suppress_Specifiers,
	Suppress_Tag_Keyword,
	Include_Tag_Definition,
	Suppress_Scope,
	Suppress_Unwritten_Scope,
	Suppress_Initializers,
	Constant_Array_Size_As_Written,
	Anonymous_Tag_Locations,
	Suppress_Strong_Lifetime,
	Suppress_Lifetime_Qualifiers,
	Suppress_Template_Args_In_Cxx_Constructors,
	Bool,
	Restrict,
	Alignof,
	Underscore_Alignof,
	Use_Void_For_Zero_Params,
	Terse_Output,
	Polish_For_Declaration,
	Half,
	Msw_Char,
	Include_Newlines,
	Msvc_Formatting,
	Constants_As_Written,
	Suppress_Implicit_Base,
	Fully_Qualified_Name,
	Last_Property = 25,
}

Obj_C_Property_Attr_Kind :: enum u32 {
	Noattr,
	Readonly,
	Getter,
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
	None,
	In,
	Inout,
	Out = 4,
	Bycopy = 8,
	Byref = 16,
	Oneway = 32,
}

Module :: rawptr

Name_Ref_Flags :: enum u32 {
	Want_Qualifier = 1,
	Want_Template_Args,
	Want_Single_Piece = 4,
}

Token_Kind :: enum u32 {
	Punctuation,
	Keyword,
	Identifier,
	Literal,
	Comment,
}

Token :: struct {
	int_data: [4]u32,
	ptr_data: rawptr,
}

Completion_String :: rawptr

Completion_Result :: struct {
	cursor_kind:       Cursor_Kind,
	completion_string: Completion_String,
}

Completion_Chunk_Kind :: enum u32 {
	Optional,
	Typed_Text,
	Text,
	Placeholder,
	Informative,
	Current_Parameter,
	Left_Paren,
	Right_Paren,
	Left_Bracket,
	Right_Bracket,
	Left_Brace,
	Right_Brace,
	Left_Angle,
	Right_Angle,
	Comma,
	Result_Type,
	Colon,
	Semi_Colon,
	Equal,
	Horizontal_Space,
	Vertical_Space,
}

Code_Complete_Results :: struct {
	results:     ^Completion_Result,
	num_results: u32,
}

Code_Complete_Flags :: enum u32 {
	Include_Macros = 1,
	Include_Code_Patterns,
	Include_Brief_Comments = 4,
	Skip_Preamble = 8,
	Include_Completions_With_Fix_Its = 16,
}

Completion_Context :: enum u32 {
	Unexposed,
	Any_Type,
	Any_Value,
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
	Float,
	Obj_C_Str_Literal,
	Str_Literal,
	Cf_Str,
	Other,
	Un_Exposed = 0,
}

Eval_Result :: rawptr

Visitor_Result :: enum u32 {
	Break,
	Continue,
}

Cursor_And_Range_Visitor :: struct {
	context_: rawptr,
	visit:    proc "c" (_: rawptr, _: Cursor, _: Source_Range) -> Visitor_Result,
}

Result :: enum u32 {
	Success,
	Invalid,
	Visit_Break,
}

Cursor_And_Range_Visitor_Block :: distinct rawptr

Idx_Client_File :: rawptr

Idx_Client_Entity :: rawptr

Idx_Client_Container :: rawptr

Idx_Client_Ast_File :: rawptr

Idx_Loc :: struct {
	ptr_data: [2]rawptr,
	int_data: u32,
}

Idx_Included_File_Info :: struct {
	hash_loc:         Idx_Loc,
	filename:         cstring,
	file:             File,
	is_import:        i32,
	is_angled:        i32,
	is_module_import: i32,
}

Idx_Imported_Ast_File_Info :: struct {
	file:        File,
	module:      Module,
	loc:         Idx_Loc,
	is_implicit: i32,
}

Idx_Entity_Kind :: enum u32 {
	Unexposed,
	Typedef,
	Function,
	Variable,
	Field,
	Enum_Constant,
	Obj_C_Class,
	Obj_C_Protocol,
	Obj_C_Category,
	Obj_C_Instance_Method,
	Obj_C_Class_Method,
	Obj_C_Property,
	Obj_C_Ivar,
	Enum,
	Struct,
	Union,
	Cxx_Class,
	Cxx_Namespace,
	Cxx_Namespace_Alias,
	Cxx_Static_Variable,
	Cxx_Static_Method,
	Cxx_Instance_Method,
	Cxx_Constructor,
	Cxx_Destructor,
	Cxx_Conversion_Function,
	Cxx_Type_Alias,
	Cxx_Interface,
	Cxx_Concept,
}

Idx_Entity_Language :: enum u32 {
	None,
	C,
	Obj_C,
	Cxx,
	Swift,
}

Idx_Entity_Cxx_Template_Kind :: enum u32 {
	Non_Template,
	Template,
	Template_Partial_Specialization,
	Template_Specialization,
}

Idx_Attr_Kind :: enum u32 {
	Unexposed,
	Ib_Action,
	Ib_Outlet,
	Ib_Outlet_Collection,
}

Idx_Attr_Info :: struct {
	kind:   Idx_Attr_Kind,
	cursor: Cursor,
	loc:    Idx_Loc,
}

Idx_Entity_Info :: struct {
	kind:           Idx_Entity_Kind,
	template_kind:  Idx_Entity_Cxx_Template_Kind,
	lang:           Idx_Entity_Language,
	name:           cstring,
	usr:            cstring,
	cursor:         Cursor,
	attributes:     ^^Idx_Attr_Info,
	num_attributes: u32,
}

Idx_Container_Info :: struct {
	cursor: Cursor,
}

Idx_Ib_Outlet_Collection_Attr_Info :: struct {
	attr_info:    ^Idx_Attr_Info,
	objc_class:   ^Idx_Entity_Info,
	class_cursor: Cursor,
	class_loc:    Idx_Loc,
}

Idx_Decl_Info_Flags :: enum u32 {
	Skipped = 1,
}

Idx_Decl_Info :: struct {
	entity_info:        ^Idx_Entity_Info,
	cursor:             Cursor,
	loc:                Idx_Loc,
	semantic_container: ^Idx_Container_Info,
	lexical_container:  ^Idx_Container_Info,
	is_redeclaration:   i32,
	is_definition:      i32,
	is_container:       i32,
	decl_as_container:  ^Idx_Container_Info,
	is_implicit:        i32,
	attributes:         ^^Idx_Attr_Info,
	num_attributes:     u32,
	flags:              u32,
}

Idx_Obj_C_Container_Kind :: enum u32 {
	Forward_Ref,
	Interface,
	Implementation,
}

Idx_Obj_C_Container_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	kind:      Idx_Obj_C_Container_Kind,
}

Idx_Base_Class_Info :: struct {
	base:   ^Idx_Entity_Info,
	cursor: Cursor,
	loc:    Idx_Loc,
}

Idx_Obj_C_Protocol_Ref_Info :: struct {
	protocol: ^Idx_Entity_Info,
	cursor:   Cursor,
	loc:      Idx_Loc,
}

Idx_Obj_C_Protocol_Ref_List_Info :: struct {
	protocols:     ^^Idx_Obj_C_Protocol_Ref_Info,
	num_protocols: u32,
}

Idx_Obj_C_Interface_Decl_Info :: struct {
	container_info: ^Idx_Obj_C_Container_Decl_Info,
	super_info:     ^Idx_Base_Class_Info,
	protocols:      ^Idx_Obj_C_Protocol_Ref_List_Info,
}

Idx_Obj_C_Category_Decl_Info :: struct {
	container_info: ^Idx_Obj_C_Container_Decl_Info,
	objc_class:     ^Idx_Entity_Info,
	class_cursor:   Cursor,
	class_loc:      Idx_Loc,
	protocols:      ^Idx_Obj_C_Protocol_Ref_List_Info,
}

Idx_Obj_C_Property_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	getter:    ^Idx_Entity_Info,
	setter:    ^Idx_Entity_Info,
}

Idx_Cxx_Class_Decl_Info :: struct {
	decl_info: ^Idx_Decl_Info,
	bases:     ^^Idx_Base_Class_Info,
	num_bases: u32,
}

Idx_Entity_Ref_Kind :: enum u32 {
	Direct = 1,
	Implicit,
}

Symbol_Role :: enum u32 {
	None,
	Declaration,
	Definition,
	Reference = 4,
	Read = 8,
	Write = 16,
	Call = 32,
	Dynamic = 64,
	Address_Of = 128,
	Implicit = 256,
}

Idx_Entity_Ref_Info :: struct {
	kind:              Idx_Entity_Ref_Kind,
	cursor:            Cursor,
	loc:               Idx_Loc,
	referenced_entity: ^Idx_Entity_Info,
	parent_entity:     ^Idx_Entity_Info,
	container:         ^Idx_Container_Info,
	role:              Symbol_Role,
}

Indexer_Callbacks :: struct {
	abort_query:              proc "c" (_: Client_Data, _: rawptr) -> i32,
	diagnostic:               proc "c" (_: Client_Data, _: Diagnostic_Set, _: rawptr),
	entered_main_file:        proc "c" (_: Client_Data, _: File, _: rawptr) -> Idx_Client_File,
	pp_included_file:         proc "c" (_: Client_Data, _: ^Idx_Included_File_Info) -> Idx_Client_File,
	imported_ast_file:        proc "c" (_: Client_Data, _: ^Idx_Imported_Ast_File_Info) -> Idx_Client_Ast_File,
	started_translation_unit: proc "c" (_: Client_Data, _: rawptr) -> Idx_Client_Container,
	index_declaration:        proc "c" (_: Client_Data, _: ^Idx_Decl_Info),
	index_entity_reference:   proc "c" (_: Client_Data, _: ^Idx_Entity_Ref_Info),
}

Index_Action :: rawptr

Index_Opt_Flags :: enum u32 {
	None,
	Suppress_Redundant_Refs,
	Index_Function_Local_Symbols,
	Index_Implicit_Template_Instantiations = 4,
	Suppress_Warnings = 8,
	Skip_Parsed_Bodies_In_Session = 16,
}

Field_Visitor :: proc "c" (_: Cursor, _: Client_Data) -> Visitor_Result

Binary_Operator_Kind :: enum u32 {
	Invalid,
	Ptr_Mem_D,
	Ptr_Mem_I,
	Mul,
	Div,
	Rem,
	Add,
	Sub,
	Shl,
	Shr,
	Cmp,
	Lt,
	Gt,
	Le,
	Ge,
	Eq,
	Ne,
	And,
	Xor,
	Or,
	L_And,
	L_Or,
	Assign,
	Mul_Assign,
	Div_Assign,
	Rem_Assign,
	Add_Assign,
	Sub_Assign,
	Shl_Assign,
	Shr_Assign,
	And_Assign,
	Xor_Assign,
	Or_Assign,
	Comma,
	Last = 33,
}

Unary_Operator_Kind :: enum u32 {
	Invalid,
	Post_Inc,
	Post_Dec,
	Pre_Inc,
	Pre_Dec,
	Addr_Of,
	Deref,
	Plus,
	Minus,
	Not,
	L_Not,
	Real,
	Imag,
	Extension,
	Coawait,
}

Remapping :: rawptr

Translation_Unit_Flags :: bit_set[Translation_Unit_Flag;u32]

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
	parse_translation_unit :: proc(c_idx: Index, source_filename: cstring, command_line_args: [^]cstring, num_command_line_args: i32, unsaved_files: ^Unsaved_File, num_unsaved_files: u32, options: Translation_Unit_Flags) -> Translation_Unit ---
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
	tokenize :: proc(tu: Translation_Unit, range: Source_Range, tokens: ^[^]Token, num_tokens: ^u32) ---
	@(link_name = "clang_annotateTokens")
	annotate_tokens :: proc(tu: Translation_Unit, tokens: ^Token, num_tokens: u32, cursors: ^Cursor) ---
	@(link_name = "clang_disposeTokens")
	dispose_tokens :: proc(tu: Translation_Unit, tokens: [^]Token, num_tokens: u32) ---
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
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_getRemappings")
	get_remappings :: proc(_: cstring) -> Remapping ---
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_getRemappingsFromFileList")
	get_remappings_from_file_list :: proc(_: ^cstring, _: u32) -> Remapping ---
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_remap_getNumFiles")
	remap_get_num_files :: proc(_: Remapping) -> u32 ---
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_remap_getFilenames")
	remap_get_filenames :: proc(_: Remapping, _: u32, _: ^String, _: ^String) ---
	@(deprecated = "deprecated in the C header")
	@(link_name = "clang_remap_dispose")
	remap_dispose :: proc(_: Remapping) ---
}
