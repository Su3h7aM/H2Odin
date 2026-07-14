package ggml

foreign import lib "system:ggml"

// the compute plan that needs to be prepared for ggml_graph_compute()
// since https://github.com/ggml-org/ggml/issues/287
cplan :: struct {
	// size of work buffer, calculated by `ggml_graph_plan()`
	work_size:           uint,
	// work buffer, to be allocated by caller before calling to `ggml_graph_compute()`
	work_data:           ^u8,
	n_threads:           i32,
	threadpool:          threadpool_t,
	// abort ggml_graph_compute when true
	abort_callback:      abort_callback,
	abort_callback_data: rawptr,
	// use only reference implementations
	use_ref:             bool,
}

// numa strategies
numa_strategy :: enum u32 {
	NUMA_STRATEGY_DISABLED,
	NUMA_STRATEGY_DISTRIBUTE,
	NUMA_STRATEGY_ISOLATE,
	NUMA_STRATEGY_NUMACTL,
	NUMA_STRATEGY_MIRROR,
	NUMA_STRATEGY_COUNT,
}

// Internal types and functions exposed for tests and benchmarks
vec_dot_t :: proc "c" (_: i32, _: ^f32, _: uint, _: rawptr, _: uint, _: rawptr, _: uint, _: i32)

type_traits_cpu :: struct {
	from_float:   from_float_t,
	vec_dot:      vec_dot_t,
	vec_dot_type: type,
	// number of rows to process simultaneously
	nrows:        i64,
}

@(link_prefix = "ggml_")
foreign lib {
	numa_init :: proc(numa: numa_strategy) ---
	is_numa :: proc() -> bool ---
	new_i32 :: proc(ctx: context_, value: i32) -> ^tensor ---
	new_f32 :: proc(ctx: context_, value: f32) -> ^tensor ---
	set_i32 :: proc(tensor_: ^tensor, value: i32) -> ^tensor ---
	set_f32 :: proc(tensor_: ^tensor, value: f32) -> ^tensor ---
	get_i32_1d :: proc(tensor_: ^tensor, i: i32) -> i32 ---
	set_i32_1d :: proc(tensor_: ^tensor, i: i32, value: i32) ---
	get_i32_nd :: proc(tensor_: ^tensor, i0: i32, i1: i32, i2: i32, i3: i32) -> i32 ---
	set_i32_nd :: proc(tensor_: ^tensor, i0: i32, i1: i32, i2: i32, i3: i32, value: i32) ---
	get_f32_1d :: proc(tensor_: ^tensor, i: i32) -> f32 ---
	set_f32_1d :: proc(tensor_: ^tensor, i: i32, value: f32) ---
	get_f32_nd :: proc(tensor_: ^tensor, i0: i32, i1: i32, i2: i32, i3: i32) -> f32 ---
	set_f32_nd :: proc(tensor_: ^tensor, i0: i32, i1: i32, i2: i32, i3: i32, value: f32) ---
	threadpool_new :: proc(params: ^threadpool_params) -> threadpool_t ---
	threadpool_free :: proc(threadpool: threadpool_t) ---
	threadpool_get_n_threads :: proc(threadpool: threadpool_t) -> i32 ---
	threadpool_pause :: proc(threadpool: threadpool_t) ---
	threadpool_resume :: proc(threadpool: threadpool_t) ---
	// ggml_graph_plan() has to be called before ggml_graph_compute()
	// when plan.work_size > 0, caller must allocate memory for plan.work_data
	graph_plan :: proc(cgraph_: cgraph, n_threads: i32, threadpool: threadpool_t) -> cplan ---
	graph_compute :: proc(cgraph_: cgraph, cplan: ^cplan) -> status ---
	// same as ggml_graph_compute() but the work data is allocated as a part of the context
	// note: the drawback of this API is that you must have ensured that the context has enough memory for the work data
	graph_compute_with_ctx :: proc(ctx: context_, cgraph_: cgraph, n_threads: i32) -> status ---
	// x86
	cpu_has_sse3 :: proc() -> i32 ---
	cpu_has_ssse3 :: proc() -> i32 ---
	cpu_has_avx :: proc() -> i32 ---
	cpu_has_avx_vnni :: proc() -> i32 ---
	cpu_has_avx2 :: proc() -> i32 ---
	cpu_has_bmi2 :: proc() -> i32 ---
	cpu_has_f16c :: proc() -> i32 ---
	cpu_has_fma :: proc() -> i32 ---
	cpu_has_avx512 :: proc() -> i32 ---
	cpu_has_avx512_vbmi :: proc() -> i32 ---
	cpu_has_avx512_vnni :: proc() -> i32 ---
	cpu_has_avx512_bf16 :: proc() -> i32 ---
	cpu_has_amx_int8 :: proc() -> i32 ---
	// ARM
	cpu_has_neon :: proc() -> i32 ---
	cpu_has_arm_fma :: proc() -> i32 ---
	cpu_has_fp16_va :: proc() -> i32 ---
	cpu_has_dotprod :: proc() -> i32 ---
	cpu_has_matmul_int8 :: proc() -> i32 ---
	cpu_has_sve :: proc() -> i32 ---
	cpu_get_sve_cnt :: proc() -> i32 ---
	cpu_has_sme :: proc() -> i32 ---
	// other
	cpu_has_riscv_v :: proc() -> i32 ---
	cpu_get_rvv_vlen :: proc() -> i32 ---
	cpu_has_vsx :: proc() -> i32 ---
	cpu_has_vxe :: proc() -> i32 ---
	cpu_has_wasm_simd :: proc() -> i32 ---
	cpu_has_llamafile :: proc() -> i32 ---
	get_type_traits_cpu :: proc(type: type) -> ^type_traits_cpu ---
	cpu_init :: proc() ---
	//
	// CPU backend
	//
	backend_cpu_init :: proc() -> backend_t ---
	backend_is_cpu :: proc(backend: backend_t) -> bool ---
	backend_cpu_set_n_threads :: proc(backend_cpu: backend_t, n_threads: i32) ---
	backend_cpu_set_threadpool :: proc(backend_cpu: backend_t, threadpool: threadpool_t) ---
	backend_cpu_set_abort_callback :: proc(backend_cpu: backend_t, abort_callback: abort_callback, abort_callback_data: rawptr) ---
	backend_cpu_set_use_ref :: proc(backend_cpu: backend_t, use_ref: bool) ---
	backend_cpu_reg :: proc() -> backend_reg_t ---
	cpu_fp32_to_fp32 :: proc(_: ^f32, _: ^f32, _: i64) ---
	cpu_fp32_to_i32 :: proc(_: ^f32, _: ^i32, _: i64) ---
	cpu_fp32_to_fp16 :: proc(_: ^f32, _: ^fp16_t, _: i64) ---
	cpu_fp16_to_fp32 :: proc(_: ^fp16_t, _: ^f32, _: i64) ---
	cpu_fp32_to_bf16 :: proc(_: ^f32, _: ^bf16_t, _: i64) ---
	cpu_bf16_to_fp32 :: proc(_: ^bf16_t, _: ^f32, _: i64) ---
}
