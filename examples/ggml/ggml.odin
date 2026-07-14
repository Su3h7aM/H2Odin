package ggml

foreign import lib "system:ggml"

FILE_MAGIC :: 0x67676d6c
FILE_VERSION :: 2
QNT_VERSION :: 2
QNT_VERSION_FACTOR :: 1000
MAX_DIMS :: 4
MAX_PARAMS :: 2048
MAX_SRC :: 10
MAX_N_THREADS :: 512
MAX_OP_PARAMS :: 64
MAX_NAME :: 64
DEFAULT_N_THREADS :: 4
DEFAULT_GRAPH_SIZE :: 2048
MEM_ALIGN :: 16
EXIT_SUCCESS :: 0
EXIT_ABORTED :: 1
ROPE_TYPE_NORMAL :: 0
ROPE_TYPE_NEOX :: 2
ROPE_TYPE_MROPE :: 8
ROPE_TYPE_VISION :: 24
ROPE_TYPE_IMROPE :: 40
MROPE_SECTIONS :: 4
// Function type used in fatal error callbacks
abort_callback_t :: proc "c" (_: cstring)

status :: enum i32 {
	STATUS_ALLOC_FAILED = -2,
	STATUS_FAILED,
	STATUS_SUCCESS,
	STATUS_ABORTED,
}

// ieee 754-2008 half-precision float16
// todo: make this not an integral type
fp16_t :: u16

// google brain half-precision bfloat16
bf16_t :: struct {
	bits: u16,
}

object :: distinct rawptr

context_ :: distinct rawptr

cgraph :: distinct rawptr

// NOTE: always add types at the end of the enum to keep backward compatibility
type :: enum u32 {
	TYPE_F32,
	TYPE_F16,
	TYPE_Q4_0,
	TYPE_Q4_1,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q5_0 = 6,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q5_1,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q8_0,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q8_1,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q2_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q3_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q4_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q5_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q6_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_Q8_K,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ2_XXS,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ2_XS,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ3_XXS,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ1_S,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ4_NL,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ3_S,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ2_S,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ4_XS,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_I8,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_I16,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_I32,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_I64,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_F64,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_IQ1_M,
	// GGML_TYPE_Q4_2 = 4, support has been removed
	// GGML_TYPE_Q4_3 = 5, support has been removed
	TYPE_BF16,
	// GGML_TYPE_Q4_0_4_4 = 31, support has been removed from gguf files
	// GGML_TYPE_Q4_0_4_8 = 32,
	// GGML_TYPE_Q4_0_8_8 = 33,
	TYPE_TQ1_0 = 34,
	// GGML_TYPE_Q4_0_4_4 = 31, support has been removed from gguf files
	// GGML_TYPE_Q4_0_4_8 = 32,
	// GGML_TYPE_Q4_0_8_8 = 33,
	TYPE_TQ2_0,
	// MXFP4 (1 block)
	TYPE_MXFP4 = 39,
	// NVFP4 (4 blocks, E4M3 scale)
	TYPE_NVFP4,
	TYPE_Q1_0,
	TYPE_Q2_0,
	TYPE_COUNT,
}

// precision
prec :: enum u32 {
	// stored as ggml_tensor.op_params, 0 by default
	PREC_DEFAULT,
	PREC_F32 = 10,
}

// op hint
op_hint :: enum u32 {
	HINT_NONE,
	HINT_SRC0_IS_HADAMARD,
}

// model file types
ftype :: enum i32 {
	FTYPE_UNKNOWN = -1,
	FTYPE_ALL_F32,
	// except 1d tensors
	FTYPE_MOSTLY_F16,
	// except 1d tensors
	FTYPE_MOSTLY_Q4_0,
	// except 1d tensors
	FTYPE_MOSTLY_Q4_1,
	// tok_embeddings.weight and output.weight are F16
	FTYPE_MOSTLY_Q4_1_SOME_F16,
	// except 1d tensors
	FTYPE_MOSTLY_Q8_0 = 7,
	// except 1d tensors
	FTYPE_MOSTLY_Q5_0,
	// except 1d tensors
	FTYPE_MOSTLY_Q5_1,
	// except 1d tensors
	FTYPE_MOSTLY_Q2_K,
	// except 1d tensors
	FTYPE_MOSTLY_Q3_K,
	// except 1d tensors
	FTYPE_MOSTLY_Q4_K,
	// except 1d tensors
	FTYPE_MOSTLY_Q5_K,
	// except 1d tensors
	FTYPE_MOSTLY_Q6_K,
	// except 1d tensors
	FTYPE_MOSTLY_IQ2_XXS,
	// except 1d tensors
	FTYPE_MOSTLY_IQ2_XS,
	// except 1d tensors
	FTYPE_MOSTLY_IQ3_XXS,
	// except 1d tensors
	FTYPE_MOSTLY_IQ1_S,
	// except 1d tensors
	FTYPE_MOSTLY_IQ4_NL,
	// except 1d tensors
	FTYPE_MOSTLY_IQ3_S,
	// except 1d tensors
	FTYPE_MOSTLY_IQ2_S,
	// except 1d tensors
	FTYPE_MOSTLY_IQ4_XS,
	// except 1d tensors
	FTYPE_MOSTLY_IQ1_M,
	// except 1d tensors
	FTYPE_MOSTLY_BF16,
	// except 1d tensors
	FTYPE_MOSTLY_MXFP4,
	// except 1d tensors
	FTYPE_MOSTLY_NVFP4,
	// except 1d tensors
	FTYPE_MOSTLY_Q1_0,
	// except 1d tensors
	FTYPE_MOSTLY_Q2_0,
}

// available tensor operations:
op :: enum u32 {
	OP_NONE,
	OP_DUP,
	OP_ADD,
	OP_ADD_ID,
	OP_ADD1,
	OP_ACC,
	OP_SUB,
	OP_MUL,
	OP_DIV,
	OP_SQR,
	OP_SQRT,
	OP_LOG,
	OP_SIN,
	OP_COS,
	OP_SUM,
	OP_SUM_ROWS,
	OP_CUMSUM,
	OP_MEAN,
	OP_ARGMAX,
	OP_COUNT_EQUAL,
	OP_REPEAT,
	OP_REPEAT_BACK,
	OP_CONCAT,
	OP_SILU_BACK,
	// normalize
	OP_NORM,
	OP_RMS_NORM,
	OP_RMS_NORM_BACK,
	OP_GROUP_NORM,
	OP_L2_NORM,
	OP_MUL_MAT,
	OP_MUL_MAT_ID,
	OP_OUT_PROD,
	OP_SCALE,
	OP_SET,
	OP_CPY,
	OP_CONT,
	OP_RESHAPE,
	OP_VIEW,
	OP_PERMUTE,
	OP_TRANSPOSE,
	OP_GET_ROWS,
	OP_GET_ROWS_BACK,
	OP_SET_ROWS,
	OP_DIAG,
	OP_DIAG_MASK_INF,
	OP_DIAG_MASK_ZERO,
	OP_SOFT_MAX,
	OP_SOFT_MAX_BACK,
	OP_ROPE,
	OP_ROPE_BACK,
	OP_CLAMP,
	OP_CONV_TRANSPOSE_1D,
	OP_IM2COL,
	OP_IM2COL_BACK,
	OP_IM2COL_3D,
	OP_COL2IM_1D,
	OP_CONV_2D,
	OP_CONV_3D,
	OP_CONV_2D_DW,
	OP_CONV_TRANSPOSE_2D,
	OP_POOL_1D,
	OP_POOL_2D,
	OP_POOL_2D_BACK,
	OP_UPSCALE,
	OP_PAD,
	OP_PAD_REFLECT_1D,
	OP_ROLL,
	OP_ARANGE,
	OP_TIMESTEP_EMBEDDING,
	OP_ARGSORT,
	OP_TOP_K,
	OP_LEAKY_RELU,
	OP_TRI,
	OP_FILL,
	OP_FLASH_ATTN_EXT,
	OP_FLASH_ATTN_BACK,
	OP_SSM_CONV,
	OP_SSM_SCAN,
	OP_WIN_PART,
	OP_WIN_UNPART,
	OP_GET_REL_POS,
	OP_ADD_REL_POS,
	OP_RWKV_WKV6,
	OP_GATED_LINEAR_ATTN,
	OP_RWKV_WKV7,
	OP_SOLVE_TRI,
	OP_GATED_DELTA_NET,
	OP_UNARY,
	OP_MAP_CUSTOM1,
	OP_MAP_CUSTOM2,
	OP_MAP_CUSTOM3,
	OP_CUSTOM,
	OP_CROSS_ENTROPY_LOSS,
	OP_CROSS_ENTROPY_LOSS_BACK,
	OP_OPT_STEP_ADAMW,
	OP_OPT_STEP_SGD,
	OP_GLU,
	OP_COUNT,
}

unary_op :: enum u32 {
	UNARY_OP_ABS,
	UNARY_OP_SGN,
	UNARY_OP_NEG,
	UNARY_OP_STEP,
	UNARY_OP_TANH,
	UNARY_OP_ELU,
	UNARY_OP_RELU,
	UNARY_OP_SIGMOID,
	UNARY_OP_GELU,
	UNARY_OP_GELU_QUICK,
	UNARY_OP_SILU,
	UNARY_OP_HARDSWISH,
	UNARY_OP_HARDSIGMOID,
	UNARY_OP_EXP,
	UNARY_OP_EXPM1,
	UNARY_OP_SOFTPLUS,
	UNARY_OP_GELU_ERF,
	UNARY_OP_XIELU,
	UNARY_OP_FLOOR,
	UNARY_OP_CEIL,
	UNARY_OP_ROUND,
	UNARY_OP_TRUNC,
	UNARY_OP_COUNT,
}

glu_op :: enum u32 {
	GLU_OP_REGLU,
	GLU_OP_GEGLU,
	GLU_OP_SWIGLU,
	GLU_OP_SWIGLU_OAI,
	GLU_OP_GEGLU_ERF,
	GLU_OP_GEGLU_QUICK,
	GLU_OP_COUNT,
}

object_type :: enum u32 {
	OBJECT_TYPE_TENSOR,
	OBJECT_TYPE_GRAPH,
	OBJECT_TYPE_WORK_BUFFER,
}

log_level :: enum u32 {
	LOG_LEVEL_NONE,
	LOG_LEVEL_DEBUG,
	LOG_LEVEL_INFO,
	LOG_LEVEL_WARN,
	LOG_LEVEL_ERROR,
	// continue previous log
	LOG_LEVEL_CONT,
}

// this tensor...
tensor_flag :: enum u32 {
	// ...is an input for the GGML compute graph
	TENSOR_FLAG_INPUT = 1,
	// ...is an output for the GGML compute graph
	TENSOR_FLAG_OUTPUT,
	// ...contains trainable parameters
	TENSOR_FLAG_PARAM = 4,
	// ...defines loss for numerical optimization (multiple loss tensors add up)
	TENSOR_FLAG_LOSS = 8,
	// ...must be computed
	TENSOR_FLAG_COMPUTE = 16,
}

tri_type :: enum u32 {
	TRI_TYPE_UPPER_DIAG,
	TRI_TYPE_UPPER,
	TRI_TYPE_LOWER_DIAG,
	TRI_TYPE_LOWER,
}

init_params :: struct {
	// bytes
	mem_size:   uint,
	// if NULL, memory will be allocated internally
	mem_buffer: rawptr,
	// don't allocate memory for the tensor data
	no_alloc:   bool,
}

// n-dimensional tensor
tensor :: struct {
	type:      type,
	buffer:    backend_buffer_t,
	// number of elements
	ne:        [4]i64,
	// stride in bytes:
	// nb[0] = ggml_type_size(type)
	// nb[1] = nb[0]   * (ne[0] / ggml_blck_size(type)) + padding
	// nb[i] = nb[i-1] * ne[i-1]
	nb:        [4]uint,
	// compute data
	op:        op,
	// op params - allocated as int32_t for alignment
	op_params: [16]i32,
	flags:     i32,
	src:       [10]^tensor,
	// source tensor and offset for views
	view_src:  ^tensor,
	view_offs: uint,
	data:      rawptr,
	name:      [64]u8,
	// extra things e.g. for ggml-cuda.cu
	extra:     rawptr,
	padding:   [8]u8,
}

// Abort callback
// If not NULL, called before ggml computation
// If it returns true, the computation is aborted
abort_callback :: proc "c" (_: rawptr) -> bool

// GUID types
guid :: [16]u8

guid_t :: ^guid

op_pool :: enum u32 {
	OP_POOL_MAX,
	OP_POOL_AVG,
	OP_POOL_COUNT,
}

scale_mode :: enum u32 {
	SCALE_MODE_NEAREST,
	SCALE_MODE_BILINEAR,
	SCALE_MODE_BICUBIC,
	SCALE_MODE_COUNT,
}

scale_flag :: enum u32 {
	SCALE_FLAG_ALIGN_CORNERS = 256,
	SCALE_FLAG_ANTIALIAS     = 512,
}

// sort rows
sort_order :: enum u32 {
	SORT_ORDER_ASC,
	SORT_ORDER_DESC,
}

// custom operators
custom1_op_t :: proc "c" (_: ^tensor, _: ^tensor, _: i32, _: i32, _: rawptr)

custom2_op_t :: proc "c" (_: ^tensor, _: ^tensor, _: ^tensor, _: i32, _: i32, _: rawptr)

custom3_op_t :: proc "c" (_: ^tensor, _: ^tensor, _: ^tensor, _: ^tensor, _: i32, _: i32, _: rawptr)

custom_op_t :: proc "c" (_: ^tensor, _: i32, _: i32, _: rawptr)

// TODO these functions were sandwiched in the old optimization interface, is there a better place for them?
log_callback :: proc "c" (_: log_level, _: cstring, _: rawptr)

to_float_t :: proc "c" (_: rawptr, _: ^f32, _: i64)

from_float_t :: proc "c" (_: ^f32, _: rawptr, _: i64)

type_traits :: struct {
	type_name:            cstring,
	blck_size:            i64,
	// interleave elements in blocks
	blck_size_interleave: i64,
	type_size:            uint,
	is_quantized:         bool,
	to_float:             to_float_t,
	from_float_ref:       from_float_t,
}

// scheduling priorities
sched_priority :: enum i32 {
	SCHED_PRIO_LOW = -1,
	SCHED_PRIO_NORMAL,
	SCHED_PRIO_MEDIUM,
	SCHED_PRIO_HIGH,
	SCHED_PRIO_REALTIME,
}

// threadpool params
// Use ggml_threadpool_params_default() or ggml_threadpool_params_init() to populate the defaults
threadpool_params :: struct {
	// mask of cpu cores (all-zeros means use default affinity settings)
	cpumask:    [512]bool,
	// number of threads
	n_threads:  i32,
	// thread priority
	prio:       sched_priority,
	// polling level (0 - no polling, 100 - aggressive polling)
	poll:       u32,
	// strict cpu placement
	strict_cpu: bool,
	// start in paused state
	paused:     bool,
}

threadpool_t :: distinct rawptr

_IO_FILE :: distinct rawptr

@(link_prefix = "ggml_")
foreign lib {
	// Set the abort callback (passing null will restore original abort functionality: printing a message to stdout)
	// Returns the old callback for chaining
	set_abort_callback :: proc(callback: abort_callback_t) -> abort_callback_t ---
	abort :: proc(file: cstring, line: i32, fmt: cstring, #c_vararg _: ..any) ---
	// get ggml_status name string
	status_to_string :: proc(status: status) -> cstring ---
	fp16_to_fp32 :: proc(_: fp16_t) -> f32 ---
	fp32_to_fp16 :: proc(_: f32) -> fp16_t ---
	fp16_to_fp32_row :: proc(_: ^fp16_t, _: ^f32, _: i64) ---
	fp32_to_fp16_row :: proc(_: ^f32, _: ^fp16_t, _: i64) ---
	fp32_to_bf16 :: proc(_: f32) -> bf16_t ---
	bf16_to_fp32 :: proc(_: bf16_t) -> f32 ---
	bf16_to_fp32_row :: proc(_: ^bf16_t, _: ^f32, _: i64) ---
	fp32_to_bf16_row_ref :: proc(_: ^f32, _: ^bf16_t, _: i64) ---
	fp32_to_bf16_row :: proc(_: ^f32, _: ^bf16_t, _: i64) ---
	guid_matches :: proc(guid_a: guid_t, guid_b: guid_t) -> bool ---
	// misc
	version :: proc() -> cstring ---
	commit :: proc() -> cstring ---
	time_init :: proc() ---
	time_ms :: proc() -> i64 ---
	time_us :: proc() -> i64 ---
	cycles :: proc() -> i64 ---
	cycles_per_ms :: proc() -> i64 ---
	// accepts a UTF-8 path, even on Windows
	fopen :: proc(fname: cstring, mode: cstring) -> _IO_FILE ---
	print_object :: proc(obj: object) ---
	print_objects :: proc(ctx: context_) ---
	nelements :: proc(tensor_: ^tensor) -> i64 ---
	nrows :: proc(tensor_: ^tensor) -> i64 ---
	nbytes :: proc(tensor_: ^tensor) -> uint ---
	nbytes_pad :: proc(tensor_: ^tensor) -> uint ---
	blck_size :: proc(type: type) -> i64 ---
	type_size :: proc(type: type) -> uint ---
	row_size :: proc(type: type, ne: i64) -> uint ---
	@(deprecated = "use ggml_row_size() instead")
	type_sizef :: proc(type: type) -> f64 ---
	type_name :: proc(type: type) -> cstring ---
	op_name :: proc(op: op) -> cstring ---
	op_symbol :: proc(op: op) -> cstring ---
	unary_op_name :: proc(op: unary_op) -> cstring ---
	glu_op_name :: proc(op: glu_op) -> cstring ---
	op_desc :: proc(t: ^tensor) -> cstring ---
	element_size :: proc(tensor_: ^tensor) -> uint ---
	is_quantized :: proc(type: type) -> bool ---
	// TODO: temporary until model loading of ggml examples is refactored
	ftype_to_ggml_type :: proc(ftype: ftype) -> type ---
	is_transposed :: proc(tensor_: ^tensor) -> bool ---
	is_permuted :: proc(tensor_: ^tensor) -> bool ---
	is_empty :: proc(tensor_: ^tensor) -> bool ---
	is_view :: proc(tensor_: ^tensor) -> bool ---
	is_scalar :: proc(tensor_: ^tensor) -> bool ---
	is_vector :: proc(tensor_: ^tensor) -> bool ---
	is_matrix :: proc(tensor_: ^tensor) -> bool ---
	is_3d :: proc(tensor_: ^tensor) -> bool ---
	n_dims :: proc(tensor_: ^tensor) -> i32 ---
	// returns whether the tensor elements can be iterated over with a flattened index (no gaps, no permutation)
	is_contiguous :: proc(tensor_: ^tensor) -> bool ---
	is_contiguous_0 :: proc(tensor_: ^tensor) -> bool ---
	is_contiguous_1 :: proc(tensor_: ^tensor) -> bool ---
	is_contiguous_2 :: proc(tensor_: ^tensor) -> bool ---
	// returns whether the tensor elements are allocated as one contiguous block of memory (no gaps, but permutation ok)
	is_contiguously_allocated :: proc(tensor_: ^tensor) -> bool ---
	// true for tensor that is stored in memory as CxWxHxN and has been permuted to WxHxCxN
	is_contiguous_channels :: proc(tensor_: ^tensor) -> bool ---
	// true if the elements in dimension 0 are contiguous, or there is just 1 block of elements
	is_contiguous_rows :: proc(tensor_: ^tensor) -> bool ---
	are_same_shape :: proc(t0: ^tensor, t1: ^tensor) -> bool ---
	are_same_stride :: proc(t0: ^tensor, t1: ^tensor) -> bool ---
	can_repeat :: proc(t0: ^tensor, t1: ^tensor) -> bool ---
	// use this to compute the memory overhead of a tensor
	tensor_overhead :: proc() -> uint ---
	validate_row_data :: proc(type: type, data: rawptr, nbytes: uint) -> bool ---
	// main
	init :: proc(params: init_params) -> context_ ---
	reset :: proc(ctx: context_) ---
	free :: proc(ctx: context_) ---
	used_mem :: proc(ctx: context_) -> uint ---
	get_no_alloc :: proc(ctx: context_) -> bool ---
	set_no_alloc :: proc(ctx: context_, no_alloc: bool) ---
	get_mem_buffer :: proc(ctx: context_) -> rawptr ---
	get_mem_size :: proc(ctx: context_) -> uint ---
	get_max_tensor_size :: proc(ctx: context_) -> uint ---
	new_tensor :: proc(ctx: context_, type: type, n_dims: i32, ne: ^i64) -> ^tensor ---
	new_tensor_1d :: proc(ctx: context_, type: type, ne0: i64) -> ^tensor ---
	new_tensor_2d :: proc(ctx: context_, type: type, ne0: i64, ne1: i64) -> ^tensor ---
	new_tensor_3d :: proc(ctx: context_, type: type, ne0: i64, ne1: i64, ne2: i64) -> ^tensor ---
	new_tensor_4d :: proc(ctx: context_, type: type, ne0: i64, ne1: i64, ne2: i64, ne3: i64) -> ^tensor ---
	new_buffer :: proc(ctx: context_, nbytes: uint) -> rawptr ---
	dup_tensor :: proc(ctx: context_, src: ^tensor) -> ^tensor ---
	view_tensor :: proc(ctx: context_, src: ^tensor) -> ^tensor ---
	// Context tensor enumeration and lookup
	get_first_tensor :: proc(ctx: context_) -> ^tensor ---
	get_next_tensor :: proc(ctx: context_, tensor_: ^tensor) -> ^tensor ---
	get_tensor :: proc(ctx: context_, name: cstring) -> ^tensor ---
	// Converts a flat index into coordinates
	unravel_index :: proc(tensor_: ^tensor, i: i64, i0: ^i64, i1: ^i64, i2: ^i64, i3: ^i64) ---
	get_unary_op :: proc(tensor_: ^tensor) -> unary_op ---
	get_glu_op :: proc(tensor_: ^tensor) -> glu_op ---
	get_data :: proc(tensor_: ^tensor) -> rawptr ---
	get_data_f32 :: proc(tensor_: ^tensor) -> ^f32 ---
	get_name :: proc(tensor_: ^tensor) -> cstring ---
	set_name :: proc(tensor_: ^tensor, name: cstring) -> ^tensor ---
	format_name :: proc(tensor_: ^tensor, fmt: cstring, #c_vararg _: ..any) -> ^tensor ---
	// Tensor flags
	set_input :: proc(tensor_: ^tensor) ---
	set_output :: proc(tensor_: ^tensor) ---
	set_param :: proc(tensor_: ^tensor) ---
	set_loss :: proc(tensor_: ^tensor) ---
	//
	// operations on tensors with backpropagation
	//
	dup :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// in-place, returns view(a)
	dup_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	add :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	add_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	add_cast :: proc(ctx: context_, a: ^tensor, b: ^tensor, type: type) -> ^tensor ---
	// dst[i0, i1, i2] = a[i0, i1, i2] + b[i0, ids[i1, i2]]
	add_id :: proc(ctx: context_, a: ^tensor, b: ^tensor, ids: ^tensor) -> ^tensor ---
	@(deprecated = "use ggml_add instead")
	add1 :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	@(deprecated = "use ggml_add_inplace instead")
	add1_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// dst = a
	// view(dst, nb1, nb2, nb3, offset) += b
	// return dst
	acc :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, nb2: uint, nb3: uint, offset: uint) -> ^tensor ---
	acc_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, nb2: uint, nb3: uint, offset: uint) -> ^tensor ---
	sub :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	sub_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	mul :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	mul_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	div :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	div_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	sqr :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sqr_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sqrt :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sqrt_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	log :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	log_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	expm1 :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	expm1_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	softplus :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	softplus_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sin :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sin_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	cos :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	cos_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// return scalar
	sum :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// sums along rows, with input shape [a,b,c,d] return shape [1,b,c,d]
	sum_rows :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	cumsum :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// mean along rows
	mean :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// argmax along rows
	argmax :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// count number of equal elements in a and b
	count_equal :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// if a is the same shape as b, and a is not parameter, return a
	// otherwise, return a new tensor: repeat(a) to fit in b
	repeat :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// repeat a to the specified shape
	repeat_4d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, ne3: i64) -> ^tensor ---
	// sums repetitions in a into shape of b
	repeat_back :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// concat a and b along dim
	// used in stable-diffusion
	concat :: proc(ctx: context_, a: ^tensor, b: ^tensor, dim: i32) -> ^tensor ---
	abs :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	abs_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sgn :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sgn_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	neg :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	neg_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	step :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	step_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	tanh :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	tanh_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	elu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	elu_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	relu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	leaky_relu :: proc(ctx: context_, a: ^tensor, negative_slope: f32, inplace: bool) -> ^tensor ---
	relu_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sigmoid :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	sigmoid_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	gelu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	gelu_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// GELU using erf (error function) when possible
	// some backends may fallback to approximation based on Abramowitz and Stegun formula
	gelu_erf :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	gelu_erf_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	gelu_quick :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	gelu_quick_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	silu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	silu_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// a - dy
	// b - x
	silu_back :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// hardswish(x) = x * relu6(x + 3) / 6
	hardswish :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// hardsigmoid(x) = relu6(x + 3) / 6
	hardsigmoid :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	exp :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	exp_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	floor :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	floor_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	ceil :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	ceil_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	round :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	round_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	/**
	     * Truncates the fractional part of each element in the tensor (towards zero).
	     * For example: trunc(3.7) = 3.0, trunc(-2.9) = -2.0
	     * Similar to std::trunc in C/C++.
	     */
	trunc :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	trunc_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// xIELU activation function
	// x = x * (c_a(alpha_n) + c_b(alpha_p, beta) * sigmoid(beta * x)) + eps * (x > 0)
	// where c_a = softplus and c_b(a, b) = softplus(a) + b are constraining functions
	// that constrain the positive and negative source alpha values respectively
	xielu :: proc(ctx: context_, a: ^tensor, alpha_n: f32, alpha_p: f32, beta: f32, eps: f32) -> ^tensor ---
	// gated linear unit ops
	// A: n columns, r rows,
	// result is n / 2 columns, r rows,
	// expects gate in second half of row, unless swapped is true
	glu :: proc(ctx: context_, a: ^tensor, op: glu_op, swapped: bool) -> ^tensor ---
	reglu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	reglu_swapped :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu_swapped :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	swiglu :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	swiglu_swapped :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu_erf :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu_erf_swapped :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu_quick :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	geglu_quick_swapped :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// A: n columns, r rows,
	// B: n columns, r rows,
	glu_split :: proc(ctx: context_, a: ^tensor, b: ^tensor, op: glu_op) -> ^tensor ---
	reglu_split :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	geglu_split :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	swiglu_split :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	geglu_erf_split :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	geglu_quick_split :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	swiglu_oai :: proc(ctx: context_, a: ^tensor, b: ^tensor, alpha: f32, limit: f32) -> ^tensor ---
	// normalize along rows
	norm :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	norm_inplace :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	rms_norm :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	rms_norm_inplace :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	// group normalize along ne0*ne1*n_groups
	// used in stable-diffusion
	group_norm :: proc(ctx: context_, a: ^tensor, n_groups: i32, eps: f32) -> ^tensor ---
	group_norm_inplace :: proc(ctx: context_, a: ^tensor, n_groups: i32, eps: f32) -> ^tensor ---
	// l2 normalize along rows
	// used in rwkv v7
	l2_norm :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	l2_norm_inplace :: proc(ctx: context_, a: ^tensor, eps: f32) -> ^tensor ---
	// a - x
	// b - dy
	rms_norm_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, eps: f32) -> ^tensor ---
	// A: k columns, n rows => [ne03, ne02, n, k]
	// B: k columns, m rows  (i.e. we transpose it internally) => [ne03 * x, ne02 * y, m, k]
	// result is n columns, m rows => [ne03 * x, ne02 * y, m, n]
	mul_mat :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// change the precision of a matrix multiplication
	// set to GGML_PREC_F32 for higher precision (useful for phi-2)
	mul_mat_set_prec :: proc(a: ^tensor, prec: prec) ---
	// change the hint of a matrix multiplication
	mul_mat_set_hint :: proc(a: ^tensor, hint: op_hint) ---
	// indirect matrix multiplication
	mul_mat_id :: proc(ctx: context_, as: ^tensor, b: ^tensor, ids: ^tensor) -> ^tensor ---
	// A: m columns, n rows,
	// B: p columns, n rows,
	// result is m columns, p rows
	out_prod :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	//
	// operations on tensors without backpropagation
	//
	scale :: proc(ctx: context_, a: ^tensor, s: f32) -> ^tensor ---
	// in-place, returns view(a)
	scale_inplace :: proc(ctx: context_, a: ^tensor, s: f32) -> ^tensor ---
	// x = s * a + b
	scale_bias :: proc(ctx: context_, a: ^tensor, s: f32, b: f32) -> ^tensor ---
	scale_bias_inplace :: proc(ctx: context_, a: ^tensor, s: f32, b: f32) -> ^tensor ---
	// b -> view(a,offset,nb1,nb2,3), return modified a
	set :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, nb2: uint, nb3: uint, offset: uint) -> ^tensor ---
	// b -> view(a,offset,nb1,nb2,3), return view(a)
	set_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, nb2: uint, nb3: uint, offset: uint) -> ^tensor ---
	set_1d :: proc(ctx: context_, a: ^tensor, b: ^tensor, offset: uint) -> ^tensor ---
	set_1d_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, offset: uint) -> ^tensor ---
	// b -> view(a,offset,nb1,nb2,3), return modified a
	set_2d :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, offset: uint) -> ^tensor ---
	// b -> view(a,offset,nb1,nb2,3), return view(a)
	set_2d_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, nb1: uint, offset: uint) -> ^tensor ---
	// a -> b, return view(b)
	cpy :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// note: casting from f32 to i32 will discard the fractional part
	@(link_name = "ggml_cast")
	cast_ :: proc(ctx: context_, a: ^tensor, type: type) -> ^tensor ---
	// make contiguous
	cont :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// make contiguous, with new shape
	cont_1d :: proc(ctx: context_, a: ^tensor, ne0: i64) -> ^tensor ---
	cont_2d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64) -> ^tensor ---
	cont_3d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64) -> ^tensor ---
	cont_4d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, ne3: i64) -> ^tensor ---
	// return view(a), b specifies the new shape
	// TODO: when we start computing gradient, make a copy instead of view
	reshape :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// return view(a)
	// TODO: when we start computing gradient, make a copy instead of view
	reshape_1d :: proc(ctx: context_, a: ^tensor, ne0: i64) -> ^tensor ---
	reshape_2d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64) -> ^tensor ---
	// return view(a)
	// TODO: when we start computing gradient, make a copy instead of view
	reshape_3d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64) -> ^tensor ---
	reshape_4d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, ne3: i64) -> ^tensor ---
	// offset in bytes
	view_1d :: proc(ctx: context_, a: ^tensor, ne0: i64, offset: uint) -> ^tensor ---
	view_2d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, nb1: uint, offset: uint) -> ^tensor ---
	view_3d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, nb1: uint, nb2: uint, offset: uint) -> ^tensor ---
	view_4d :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, ne3: i64, nb1: uint, nb2: uint, nb3: uint, offset: uint) -> ^tensor ---
	permute :: proc(ctx: context_, a: ^tensor, axis0: i32, axis1: i32, axis2: i32, axis3: i32) -> ^tensor ---
	// alias for ggml_permute(ctx, a, 1, 0, 2, 3)
	transpose :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// supports 4D a:
	// a     [n_embd, ne1, ne2, ne3]
	// b I32 [n_rows, ne2, ne3, 1]
	//
	// return [n_embd, n_rows, ne2, ne3]
	get_rows :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	get_rows_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor) -> ^tensor ---
	// a TD  [n_embd, ne1,    ne2,    ne3]
	// b TS  [n_embd, n_rows, ne02,   ne03] | ne02 == ne2, ne03 == ne3
	// c I64 [n_rows, ne11,   ne12,   1]    | c[i] in [0, ne1)
	//
	// undefined behavior if destination rows overlap
	//
	// broadcast:
	//   ne2 % ne11 == 0
	//   ne3 % ne12 == 0
	//
	// return view(a)
	set_rows :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor) -> ^tensor ---
	diag :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// set elements above the diagonal to -INF
	diag_mask_inf :: proc(ctx: context_, a: ^tensor, n_past: i32) -> ^tensor ---
	// in-place, returns view(a)
	diag_mask_inf_inplace :: proc(ctx: context_, a: ^tensor, n_past: i32) -> ^tensor ---
	// set elements above the diagonal to 0
	diag_mask_zero :: proc(ctx: context_, a: ^tensor, n_past: i32) -> ^tensor ---
	// in-place, returns view(a)
	diag_mask_zero_inplace :: proc(ctx: context_, a: ^tensor, n_past: i32) -> ^tensor ---
	soft_max :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// in-place, returns view(a)
	soft_max_inplace :: proc(ctx: context_, a: ^tensor) -> ^tensor ---
	// a    [ne0, ne01, ne02, ne03]
	// mask [ne0, ne11, ne12, ne13] | ne11 >= ne01, F16 or F32, optional
	//
	// broadcast:
	//   ne02 % ne12 == 0
	//   ne03 % ne13 == 0
	//
	// fused soft_max(a*scale + mask*(ALiBi slope))
	// max_bias = 0.0f for no ALiBi
	soft_max_ext :: proc(ctx: context_, a: ^tensor, mask: ^tensor, scale: f32, max_bias: f32) -> ^tensor ---
	soft_max_ext_inplace :: proc(ctx: context_, a: ^tensor, mask: ^tensor, scale: f32, max_bias: f32) -> ^tensor ---
	soft_max_add_sinks :: proc(a: ^tensor, sinks: ^tensor) ---
	soft_max_ext_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, scale: f32, max_bias: f32) -> ^tensor ---
	// in-place, returns view(a)
	soft_max_ext_back_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, scale: f32, max_bias: f32) -> ^tensor ---
	// rotary position embedding
	// if (mode & 1) - skip n_past elements (NOT SUPPORTED)
	// if (mode & GGML_ROPE_TYPE_NEOX) - GPT-NeoX style
	//
	// b is an int32 vector with size a->ne[2], it contains the positions
	rope :: proc(ctx: context_, a: ^tensor, b: ^tensor, n_dims: i32, mode: i32) -> ^tensor ---
	// in-place, returns view(a)
	rope_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, n_dims: i32, mode: i32) -> ^tensor ---
	// RoPE operations with extended options
	// a is the input tensor to apply RoPE to, shape [n_embd, n_head, n_token]
	// b is an int32 vector with size n_token
	// c is freq factors (e.g. phi3-128k), (optional)
	// mode can be GGML_ROPE_TYPE_NORMAL or NEOX; for MROPE and VISION mode, use ggml_rope_multi
	//
	// pseudo-code for computing theta:
	//   for i in [0, n_dims/2):
	//     theta[i] = b[i] * powf(freq_base, -2.0 * i / n_dims);
	//     theta[i] = theta[i] / c[i];  # if c is provided, divide theta by c
	//     theta[i] = rope_yarn(theta[i], ...);  # note: theta = theta * freq_scale is applied here
	//
	// other params are used by YaRN RoPE scaling, these default values will disable YaRN:
	//   freq_scale  = 1.0f
	//   ext_factor  = 0.0f
	//   attn_factor = 1.0f
	//   beta_fast   = 0.0f
	//   beta_slow   = 0.0f
	//
	// example:
	//   (marking: c = cos, s = sin, 0 = unrotated)
	//   given a single head with size = 8 --> [00000000]
	//   GGML_ROPE_TYPE_NORMAL  n_dims = 4 --> [cscs0000]
	//   GGML_ROPE_TYPE_NORMAL  n_dims = 8 --> [cscscscs]
	//   GGML_ROPE_TYPE_NEOX    n_dims = 4 --> [ccss0000]
	//   GGML_ROPE_TYPE_NEOX    n_dims = 8 --> [ccccssss]
	rope_ext :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	// multi-dimensional RoPE, for Qwen-VL and similar vision models
	// mode can be either VISION, MROPE, IMROPE, cannot be combined with NORMAL or NEOX
	// sections specify how many dimensions to rotate in each section:
	//   section length is equivalent to number of cos/sin pairs, NOT the number of dims
	//   (i.e. sum of 4 sections are expected to be n_dims/2)
	//   last sections can be 0, means ignored
	// all other options are identical to ggml_rope_ext
	//
	// important note:
	//   - NEOX ordering is automatically applied and cannot be disabled for MROPE and VISION
	//     if you need normal ordering, there are 2 methods:
	//     (1) split the tensor manually using ggml_view
	//     (2) permute the weight upon conversion
	//   - for VISION, n_dims must be head_size/2
	//
	// example M-RoPE:
	//  given sections = [t=4, y=2, x=2, 0]
	//  given a single head with size = 18 --> [000000000000000000]
	//  GGML_ROPE_TYPE_MROPE   n_dims = 16 --> [ttttyyxxttttyyxx00] (cos/sin are applied in NEOX ordering)
	//  GGML_ROPE_TYPE_IMROPE  n_dims = 16 --> [ttyxttyxttyxttyx00] (interleaved M-RoPE, still NEOX ordering)
	//  note: the theta for each dim is computed the same way as ggml_rope_ext, no matter the section
	//        in other words, idx used for theta: [0123456789... until n_dims/2], not reset for each section
	//
	// example vision RoPE:
	//  given sections = [y=4, x=4, 0, 0] (last 2 sections are ignored)
	//  given a single head with size = 8 --> [00000000]
	//  GGML_ROPE_TYPE_VISION  n_dims = 4 --> [yyyyxxxx]
	//  other values of n_dims are untested and is undefined behavior
	//  note: unlike MROPE, the theta for each dim is computed differently for each section
	//        in other words, idx used for theta: [0123] for y section, then [0123] for x section
	rope_multi :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, sections: [^]i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	// in-place, returns view(a)
	rope_ext_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	rope_multi_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, sections: [^]i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	@(deprecated = "use ggml_rope_ext instead")
	rope_custom :: proc(ctx: context_, a: ^tensor, b: ^tensor, n_dims: i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	@(deprecated = "use ggml_rope_ext_inplace instead")
	rope_custom_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, n_dims: i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	// compute correction dims for YaRN RoPE scaling
	rope_yarn_corr_dims :: proc(n_dims: i32, n_ctx_orig: i32, freq_base: f32, beta_fast: f32, beta_slow: f32, dims: [^]f32) ---
	// rotary position embedding backward, i.e compute dx from dy
	// a - dy
	rope_ext_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	rope_multi_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, n_dims: i32, sections: [^]i32, mode: i32, n_ctx_orig: i32, freq_base: f32, freq_scale: f32, ext_factor: f32, attn_factor: f32, beta_fast: f32, beta_slow: f32) -> ^tensor ---
	// clamp
	// in-place, returns view(a)
	clamp :: proc(ctx: context_, a: ^tensor, min: f32, max: f32) -> ^tensor ---
	// im2col
	// converts data into a format that effectively results in a convolution when combined with matrix multiplication
	im2col :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, s1: i32, p0: i32, p1: i32, d0: i32, d1: i32, is_2D: bool, dst_type: type) -> ^tensor ---
	im2col_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, ne: ^i64, s0: i32, s1: i32, p0: i32, p1: i32, d0: i32, d1: i32, is_2D: bool) -> ^tensor ---
	// col2im_1d: scatter-add GEMM columns back to 1D signal
	// a: [K*OC, T_in]  (columns from matmul, K = a->ne[0]/OC)
	// result: [T_out, OC]  where T_out = (T_in - 1)*s0 + K - 2*p0
	col2im_1d :: proc(ctx: context_, a: ^tensor, s0: i32, oc: i32, p0: i32) -> ^tensor ---
	conv_1d :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, p0: i32, d0: i32) -> ^tensor ---
	// conv_1d with padding = half
	// alias for ggml_conv_1d(a, b, s, a->ne[0]/2, d)
	conv_1d_ph :: proc(ctx: context_, a: ^tensor, b: ^tensor, s: i32, d: i32) -> ^tensor ---
	// depthwise
	// TODO: this is very likely wrong for some cases! - needs more testing
	conv_1d_dw :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, p0: i32, d0: i32) -> ^tensor ---
	conv_1d_dw_ph :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, d0: i32) -> ^tensor ---
	conv_transpose_1d :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, p0: i32, d0: i32) -> ^tensor ---
	conv_2d :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, s1: i32, p0: i32, p1: i32, d0: i32, d1: i32) -> ^tensor ---
	im2col_3d :: proc(ctx: context_, a: ^tensor, b: ^tensor, IC: i64, s0: i32, s1: i32, s2: i32, p0: i32, p1: i32, p2: i32, d0: i32, d1: i32, d2: i32, dst_type: type) -> ^tensor ---
	// a: [OC*IC, KD, KH, KW]
	// b: [N*IC, ID, IH, IW]
	// result: [N*OC, OD, OH, OW]
	conv_3d :: proc(ctx: context_, a: ^tensor, b: ^tensor, IC: i64, s0: i32, s1: i32, s2: i32, p0: i32, p1: i32, p2: i32, d0: i32, d1: i32, d2: i32) -> ^tensor ---
	// kernel size is a->ne[0] x a->ne[1]
	// stride is equal to kernel size
	// padding is zero
	// example:
	// a:     16   16    3  768
	// b:   1024 1024    3    1
	// res:   64   64  768    1
	// used in sam
	conv_2d_sk_p0 :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// kernel size is a->ne[0] x a->ne[1]
	// stride is 1
	// padding is half
	// example:
	// a:      3    3    256  256
	// b:     64   64    256    1
	// res:   64   64    256    1
	// used in sam
	conv_2d_s1_ph :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	// depthwise (via im2col and mul_mat)
	conv_2d_dw :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, s1: i32, p0: i32, p1: i32, d0: i32, d1: i32) -> ^tensor ---
	// Depthwise 2D convolution
	// may be faster than ggml_conv_2d_dw, but not available in all backends
	// a:   KW    KH    1    C    convolution kernel
	// b:   W     H     C    N    input data
	// res: W_out H_out C    N
	conv_2d_dw_direct :: proc(ctx: context_, a: ^tensor, b: ^tensor, stride0: i32, stride1: i32, pad0: i32, pad1: i32, dilation0: i32, dilation1: i32) -> ^tensor ---
	conv_transpose_2d_p0 :: proc(ctx: context_, a: ^tensor, b: ^tensor, stride: i32) -> ^tensor ---
	conv_2d_direct :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, s1: i32, p0: i32, p1: i32, d0: i32, d1: i32) -> ^tensor ---
	conv_3d_direct :: proc(ctx: context_, a: ^tensor, b: ^tensor, s0: i32, s1: i32, s2: i32, p0: i32, p1: i32, p2: i32, d0: i32, d1: i32, d2: i32, n_channels: i32, n_batch: i32, n_channels_out: i32) -> ^tensor ---
	pool_1d :: proc(ctx: context_, a: ^tensor, op: op_pool, k0: i32, s0: i32, p0: i32) -> ^tensor ---
	// the result will have 2*p0 padding for the first dimension
	// and 2*p1 padding for the second dimension
	pool_2d :: proc(ctx: context_, a: ^tensor, op: op_pool, k0: i32, k1: i32, s0: i32, s1: i32, p0: f32, p1: f32) -> ^tensor ---
	pool_2d_back :: proc(ctx: context_, a: ^tensor, af: ^tensor, op: op_pool, k0: i32, k1: i32, s0: i32, s1: i32, p0: f32, p1: f32) -> ^tensor ---
	// interpolate
	// multiplies ne0 and ne1 by scale factor
	upscale :: proc(ctx: context_, a: ^tensor, scale_factor: i32, mode: scale_mode) -> ^tensor ---
	// interpolate
	// interpolate scale to specified dimensions
	@(deprecated = "use ggml_interpolate instead")
	upscale_ext :: proc(ctx: context_, a: ^tensor, ne0: i32, ne1: i32, ne2: i32, ne3: i32, mode: scale_mode) -> ^tensor ---
	// Up- or downsamples the input to the specified size.
	// 2D scale modes (eg. bilinear) are applied to the first two dimensions.
	interpolate :: proc(ctx: context_, a: ^tensor, ne0: i64, ne1: i64, ne2: i64, ne3: i64, mode: u32) -> ^tensor ---
	// pad each dimension with zeros: [x, ..., x] -> [x, ..., x, 0, ..., 0]
	pad :: proc(ctx: context_, a: ^tensor, p0: i32, p1: i32, p2: i32, p3: i32) -> ^tensor ---
	// pad each dimension with values on the other side of the torus (looping around)
	pad_circular :: proc(ctx: context_, a: ^tensor, p0: i32, p1: i32, p2: i32, p3: i32) -> ^tensor ---
	pad_ext :: proc(ctx: context_, a: ^tensor, lp0: i32, rp0: i32, lp1: i32, rp1: i32, lp2: i32, rp2: i32, lp3: i32, rp3: i32) -> ^tensor ---
	// pad each dimension with values on the other side of the torus (looping around)
	pad_ext_circular :: proc(ctx: context_, a: ^tensor, lp0: i32, rp0: i32, lp1: i32, rp1: i32, lp2: i32, rp2: i32, lp3: i32, rp3: i32) -> ^tensor ---
	// pad each dimension with reflection: [a, b, c, d] -> [b, a, b, c, d, c]
	pad_reflect_1d :: proc(ctx: context_, a: ^tensor, p0: i32, p1: i32) -> ^tensor ---
	// Move tensor elements by an offset given for each dimension. Elements that
	// are shifted beyond the last position are wrapped around to the beginning.
	roll :: proc(ctx: context_, a: ^tensor, shift0: i32, shift1: i32, shift2: i32, shift3: i32) -> ^tensor ---
	// Convert matrix into a triangular one (upper, strict upper, lower or strict lower) by writing
	// zeroes everywhere outside the masked area
	tri :: proc(ctx: context_, a: ^tensor, type: tri_type) -> ^tensor ---
	// Fill tensor a with constant c
	fill :: proc(ctx: context_, a: ^tensor, c: f32) -> ^tensor ---
	fill_inplace :: proc(ctx: context_, a: ^tensor, c: f32) -> ^tensor ---
	// Ref: https://github.com/CompVis/stable-diffusion/blob/main/ldm/modules/diffusionmodules/util.py#L151
	// timesteps: [N,]
	// return: [N, dim]
	timestep_embedding :: proc(ctx: context_, timesteps: ^tensor, dim: i32, max_period: i32) -> ^tensor ---
	argsort :: proc(ctx: context_, a: ^tensor, order: sort_order) -> ^tensor ---
	// similar to ggml_top_k but implemented as `argsort` + `view`
	argsort_top_k :: proc(ctx: context_, a: ^tensor, k: i32) -> ^tensor ---
	// top k elements per row
	// note: the resulting top k indices are in no particular order
	top_k :: proc(ctx: context_, a: ^tensor, k: i32) -> ^tensor ---
	arange :: proc(ctx: context_, start: f32, stop: f32, step: f32) -> ^tensor ---
	// q:    [n_embd_k, n_batch, n_head,    ne3 ]
	// k:    [n_embd_k, n_kv,    n_head_kv, ne3 ]
	// v:    [n_embd_v, n_kv,    n_head_kv, ne3 ] !! not transposed !!
	// mask: [n_kv,     n_batch, ne32,      ne33]
	// res:  [n_embd_v, n_head,  n_batch,   ne3 ] !! permuted !!
	//
	// broadcast:
	//   n_head % n_head_kv == 0
	//   n_head % ne32      == 0
	//   ne3    % ne33      == 0
	//
	flash_attn_ext :: proc(ctx: context_, q: ^tensor, k: ^tensor, v: ^tensor, mask: ^tensor, scale: f32, max_bias: f32, logit_softcap: f32) -> ^tensor ---
	flash_attn_ext_set_prec :: proc(a: ^tensor, prec: prec) ---
	flash_attn_ext_get_prec :: proc(a: ^tensor) -> prec ---
	flash_attn_ext_add_sinks :: proc(a: ^tensor, sinks: ^tensor) ---
	// TODO: needs to be adapted to ggml_flash_attn_ext
	flash_attn_back :: proc(ctx: context_, q: ^tensor, k: ^tensor, v: ^tensor, d: ^tensor, masked: bool) -> ^tensor ---
	ssm_conv :: proc(ctx: context_, sx: ^tensor, c: ^tensor) -> ^tensor ---
	ssm_scan :: proc(ctx: context_, s: ^tensor, x: ^tensor, dt: ^tensor, A: ^tensor, B: ^tensor, C: ^tensor, ids: ^tensor) -> ^tensor ---
	// partition into non-overlapping windows with padding if needed
	// example:
	// a:   768   64   64    1
	// w:    14
	// res: 768   14   14    25
	// used in sam
	win_part :: proc(ctx: context_, a: ^tensor, w: i32) -> ^tensor ---
	// reverse of ggml_win_part
	// used in sam
	win_unpart :: proc(ctx: context_, a: ^tensor, w0: i32, h0: i32, w: i32) -> ^tensor ---
	unary :: proc(ctx: context_, a: ^tensor, op: unary_op) -> ^tensor ---
	unary_inplace :: proc(ctx: context_, a: ^tensor, op: unary_op) -> ^tensor ---
	// used in sam
	get_rel_pos :: proc(ctx: context_, a: ^tensor, qh: i32, kh: i32) -> ^tensor ---
	// used in sam
	add_rel_pos :: proc(ctx: context_, a: ^tensor, pw: ^tensor, ph: ^tensor) -> ^tensor ---
	add_rel_pos_inplace :: proc(ctx: context_, a: ^tensor, pw: ^tensor, ph: ^tensor) -> ^tensor ---
	rwkv_wkv6 :: proc(ctx: context_, k: ^tensor, v: ^tensor, r: ^tensor, tf: ^tensor, td: ^tensor, state: ^tensor) -> ^tensor ---
	gated_linear_attn :: proc(ctx: context_, k: ^tensor, v: ^tensor, q: ^tensor, g: ^tensor, state: ^tensor, scale: f32) -> ^tensor ---
	rwkv_wkv7 :: proc(ctx: context_, r: ^tensor, w: ^tensor, k: ^tensor, v: ^tensor, a: ^tensor, b: ^tensor, state: ^tensor) -> ^tensor ---
	/* Solves a specific equation of the form Ax=B, where A is a triangular matrix
	    *  without zeroes on the diagonal (i.e. invertible).
	    *  B can have any number of columns, but must have the same number of rows as A
	    *  If A is [n, n] and B is [n, m], then the result will be [n, m] as well
	    *  Has O(n^3) complexity (unlike most matrix ops out there), so use on cases
	    *  where n > 100 sparingly, pre-chunk if necessary.
	    *
	    *  If left = false, solves xA=B instead
	    *  If lower = false, assumes upper triangular instead
	    *  If uni = true, assumes diagonal of A to be all ones (will override actual values)
	    *
	    *  TODO: currently only lower, right, non-unitriangular variant is implemented
	    */
	solve_tri :: proc(ctx: context_, a: ^tensor, b: ^tensor, left: bool, lower: bool, uni: bool) -> ^tensor ---
	// TODO: add ggml_gated_delta_net_set_bcast() to be able to configure Q, K broadcast type: tiled vs interleaved [TAG_GGML_GDN_BCAST]
	// ref: https://github.com/ggml-org/llama.cpp/pull/19468#discussion_r2786394306
	//
	// tensor shapes (S_k == S_v, H_v % H_k == 0):
	//   q, k  : [S_k, H_k, n_tokens, n_seqs]
	//   v     : [S_v, H_v, n_tokens, n_seqs]
	//   g     : [1, H_v, n_tokens, n_seqs] (scalar gate) or [S_v, H_v, n_tokens, n_seqs] (KDA)
	//   beta  : [1, H_v, n_tokens, n_seqs]
	//   state : [S_v, S_v, H_v, n_seqs] -- initial recurrent state s0
	//
	// the output packs the attention scores [S_v, H_v, n_tokens, n_seqs] followed by K state
	// snapshots, most-recent first (slot 0 = final state, slot s = state s tokens back). K == 1
	// keeps only the final state; when n_tokens < K only slots 0..n_tokens-1 are written.
	gated_delta_net :: proc(ctx: context_, q: ^tensor, k: ^tensor, v: ^tensor, g: ^tensor, beta: ^tensor, state: ^tensor, K: i64) -> ^tensor ---
	// n_tasks == GGML_N_TASKS_MAX means to use max number of tasks
	map_custom1 :: proc(ctx: context_, a: ^tensor, fun: custom1_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	map_custom1_inplace :: proc(ctx: context_, a: ^tensor, fun: custom1_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	map_custom2 :: proc(ctx: context_, a: ^tensor, b: ^tensor, fun: custom2_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	map_custom2_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, fun: custom2_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	map_custom3 :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, fun: custom3_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	map_custom3_inplace :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor, fun: custom3_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	custom_4d :: proc(ctx: context_, type: type, ne0: i64, ne1: i64, ne2: i64, ne3: i64, args: ^^tensor, n_args: i32, fun: custom_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	custom_inplace :: proc(ctx: context_, a: ^tensor, args: ^^tensor, n_args: i32, fun: custom_op_t, n_tasks: i32, userdata: rawptr) -> ^tensor ---
	// loss function
	cross_entropy_loss :: proc(ctx: context_, a: ^tensor, b: ^tensor) -> ^tensor ---
	cross_entropy_loss_back :: proc(ctx: context_, a: ^tensor, b: ^tensor, c: ^tensor) -> ^tensor ---
	// AdamW optimizer step
	// Paper: https://arxiv.org/pdf/1711.05101v3.pdf
	// PyTorch: https://pytorch.org/docs/stable/generated/torch.optim.AdamW.html
	opt_step_adamw :: proc(ctx: context_, a: ^tensor, grad: ^tensor, m: ^tensor, v: ^tensor, adamw_params: ^tensor) -> ^tensor ---
	// stochastic gradient descent step (with weight decay)
	opt_step_sgd :: proc(ctx: context_, a: ^tensor, grad: ^tensor, sgd_params: ^tensor) -> ^tensor ---
	// build forward multiple tensors and select one of them for computing
	// this is useful for creating graphs that have constant topology but compute different things based on the input
	// ref: https://github.com/ggml-org/llama.cpp/pull/18550
	//
	// nodes:
	//   | - build forward into the graph but do not compute
	//   c - build forward into the graph and compute
	//
	//    |  |  ...  c  ...  |
	//    |  |  ...  c  ...  |
	//    |  |  ...  c  ...  |
	//   [0  1  ... idx ...  n-1]        <-- ggml_build_forward_select(..., n, idx)
	//               c
	//               c
	//
	// example:
	//   struct ggml_tensor * curs[3];
	//
	//   curs[0]  = compute0(...);
	//   curs[1]  = compute1(...);
	//   curs[2]  = compute2(...);
	//
	//   int idx = select_branch(some_input);
	//
	//   struct ggml_tensor * out = ggml_build_forward_select(cgraph, curs, 3, idx);
	//
	build_forward_select :: proc(cgraph_: cgraph, tensors: ^^tensor, n_tensors: i32, idx: i32) -> ^tensor ---
	build_forward_expand :: proc(cgraph_: cgraph, tensor_: ^tensor) ---
	build_backward_expand :: proc(ctx: context_, cgraph_: cgraph, grad_accs: ^^tensor) ---
	// graph allocation in a context
	new_graph :: proc(ctx: context_) -> cgraph ---
	new_graph_custom :: proc(ctx: context_, size: uint, grads: bool) -> cgraph ---
	graph_dup :: proc(ctx: context_, cgraph_: cgraph, force_grads: bool) -> cgraph ---
	graph_cpy :: proc(src: cgraph, dst: cgraph) ---
	graph_reset :: proc(cgraph_: cgraph) ---
	graph_clear :: proc(cgraph_: cgraph) ---
	graph_size :: proc(cgraph_: cgraph) -> i32 ---
	graph_node :: proc(cgraph_: cgraph, i: i32) -> ^tensor ---
	graph_nodes :: proc(cgraph_: cgraph) -> ^^tensor ---
	graph_n_nodes :: proc(cgraph_: cgraph) -> i32 ---
	graph_add_node :: proc(cgraph_: cgraph, tensor_: ^tensor) ---
	graph_overhead :: proc() -> uint ---
	graph_overhead_custom :: proc(size: uint, grads: bool) -> uint ---
	graph_get_tensor :: proc(cgraph_: cgraph, name: cstring) -> ^tensor ---
	graph_get_grad :: proc(cgraph_: cgraph, node: ^tensor) -> ^tensor ---
	graph_get_grad_acc :: proc(cgraph_: cgraph, node: ^tensor) -> ^tensor ---
	// print info and performance information for the graph
	graph_print :: proc(cgraph_: cgraph) ---
	// dump the graph into a file using the dot format
	graph_dump_dot :: proc(gb: cgraph, cgraph_: cgraph, filename: cstring) ---
	// Set callback for all future logging events.
	// If this is not called, or NULL is supplied, everything is output on stderr.
	log_get :: proc(log_callback: ^log_callback, user_data: ^rawptr) ---
	log_set :: proc(log_callback: log_callback, user_data: rawptr) ---
	set_zero :: proc(tensor_: ^tensor) -> ^tensor ---
	// - ggml_quantize_init can be called multiple times with the same type
	//   it will only initialize the quantization tables for the first call or after ggml_quantize_free
	//   automatically called by ggml_quantize_chunk for convenience
	//
	// - ggml_quantize_free will free any memory allocated by ggml_quantize_init
	//   call this at the end of the program to avoid memory leaks
	//
	// note: these are thread-safe
	//
	quantize_init :: proc(type: type) ---
	quantize_free :: proc() ---
	// some quantization type cannot be used without an importance matrix
	quantize_requires_imatrix :: proc(type: type) -> bool ---
	// calls ggml_quantize_init internally (i.e. can allocate memory)
	quantize_chunk :: proc(type: type, src: ^f32, dst: rawptr, start: i64, nrows: i64, n_per_row: i64, imatrix: ^f32) -> uint ---
	get_type_traits :: proc(type: type) -> ^type_traits ---
	threadpool_params_default :: proc(n_threads: i32) -> threadpool_params ---
	threadpool_params_init :: proc(p: ^threadpool_params, n_threads: i32) ---
	threadpool_params_match :: proc(p0: ^threadpool_params, p1: ^threadpool_params) -> bool ---
}
