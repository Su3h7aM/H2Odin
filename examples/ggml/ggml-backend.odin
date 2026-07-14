package ggml

foreign import lib "system:ggml"

BACKEND_META_MAX_DEVICES :: 16
backend_event_t :: distinct rawptr

backend_graph_plan_t :: rawptr

backend_reg_t :: distinct rawptr

backend_dev_t :: distinct rawptr

//
// Backend buffer
//
backend_buffer_usage :: enum u32 {
	BACKEND_BUFFER_USAGE_ANY,
	BACKEND_BUFFER_USAGE_WEIGHTS,
	BACKEND_BUFFER_USAGE_COMPUTE,
}

//
// Backend device
//
backend_dev_type :: enum u32 {
	// CPU device using system memory
	BACKEND_DEVICE_TYPE_CPU,
	// GPU device using dedicated memory
	BACKEND_DEVICE_TYPE_GPU,
	// integrated GPU device using host memory
	BACKEND_DEVICE_TYPE_IGPU,
	// accelerator devices intended to be used together with the CPU backend (e.g. BLAS or AMX)
	BACKEND_DEVICE_TYPE_ACCEL,
	// "meta" device wrapping multiple other devices for tensor parallelism
	BACKEND_DEVICE_TYPE_META,
}

// functionality supported by the device
backend_dev_caps :: struct {
	// asynchronous operations
	async:                bool,
	// pinned host buffer
	host_buffer:          bool,
	// creating buffers from host ptr
	buffer_from_host_ptr: bool,
	// event synchronization
	events:               bool,
}

// all the device properties
backend_dev_props :: struct {
	// device name
	name:         cstring,
	// device description
	description:  cstring,
	// device free memory in bytes
	memory_free:  uint,
	// device total memory in bytes
	memory_total: uint,
	// device type
	type:         backend_dev_type,
	// device id
	//   for PCI devices, this should be the lower-case PCI bus id formatted as "domain:bus:device.function" (e.g. "0000:c1:00.0")
	//   if the id is unknown, this should be NULL
	device_id:    cstring,
	// device capabilities
	caps:         backend_dev_caps,
}

// Context management and operations for faster communication between backends, used for tensor parallelism (meta backend)
backend_comm_init_t :: proc "c" (_: ^backend_t, _: uint) -> rawptr

backend_comm_free_t :: proc "c" (_: rawptr)

backend_comm_allreduce_tensor_t :: proc "c" (_: rawptr, _: ^^tensor) -> bool

// Split buffer type for tensor parallelism (old)
backend_split_buffer_type_t :: proc "c" (_: i32, _: ^f32) -> backend_buffer_type_t

// Set the number of threads for the backend
backend_set_n_threads_t :: proc "c" (_: backend_t, _: i32)

// Get additional buffer types provided by the device (returns a NULL-terminated array)
backend_dev_get_extra_bufts_t :: proc "c" (_: backend_dev_t) -> ^backend_buffer_type_t

// Set the abort callback for the backend
backend_set_abort_callback_t :: proc "c" (_: backend_t, _: abort_callback, _: rawptr)

// Get a list of feature flags supported by the backend (returns a NULL-terminated array)
backend_feature :: struct {
	name:  cstring,
	value: cstring,
}

backend_get_features_t :: proc "c" (_: backend_reg_t) -> ^backend_feature

// The backend scheduler allows for multiple backend devices to be used together
// Handles compute buffer allocation, assignment of tensors to backends, and copying of tensors between backends
// The backends are selected based on:
// - the backend that supports the operation
// - the location of the pre-allocated tensors (e.g. the weights)
/*
      Example usage:

        // operations that use tensors allocated in a buffer with USAGE_WEIGHTS will be assigned
        // preferably to run on the same backend as the buffer
        ggml_backend_buffer_set_usage(buf_weights, GGML_BACKEND_BUFFER_USAGE_WEIGHTS);

        sched = ggml_backend_sched_new({backend_gpu, backend_gpu2, backend_cpu}, NULL, num_backends, GGML_DEFAULT_GRAPH_SIZE, false, true);

        // initialize buffers from a max size graph (optional)
        reserve_graph = build_graph(sched, max_batch_size);

        // manually assign nodes to a backend (optional, should not be needed in most cases)
        struct ggml_tensor * node = ggml_mul_mat(ctx, ...);
        ggml_backend_sched_set_tensor_backend(sched, node, backend_gpu);

        ggml_backend_sched_reserve(sched, reserve_graph);

        // compute
        graph = build_graph(sched); // the graph and its tensors are single-use in terms of allocation, multi-use in terms of computation
        for (int i = 0; i < 10; ++i) {
            ggml_backend_sched_graph_compute(sched, graph); // on the first iteration the graph is allocated automatically
        }

        // if there are graph inputs:
        graph = build_graph(sched); // get a new graph that is not allocated (the metadata for the old graph is freed once ggml_free is called)
        ggml_backend_sched_reset(sched); // clear the allocation of the previous graph
        ggml_backend_sched_alloc_graph(sched, graph); // explicitly allocate the new graph but do not execute it
        ggml_backend_tensor_set(input_tensor, ...); // copy data to the newly allocated graph tensors
        ggml_backend_sched_graph_compute(sched, graph); // execute the graph

        // as an alternative to the above it is also possible to assign the inputs to a dedicated context and
        // allocate them statically via ggml_backend_alloc_ctx_tensors
    }
    */
backend_sched_t :: distinct rawptr

// Evaluation callback for each node in the graph (set with ggml_backend_sched_set_eval_callback)
// when ask == true, the scheduler wants to know if the user wants to observe this node
// this allows the scheduler to batch nodes together in order to evaluate them in a single call
//
// when ask == false, the scheduler is passing the node tensor to the user for observation
// if the user returns false, the scheduler will cancel the graph compute
//
backend_sched_eval_callback :: proc "c" (_: ^tensor, _: bool, _: rawptr) -> bool

backend_meta_split_axis :: enum u32 {
	// tensor split by tensor dimensions:
	BACKEND_SPLIT_AXIS_0,
	// tensor split by tensor dimensions:
	BACKEND_SPLIT_AXIS_1,
	// tensor split by tensor dimensions:
	BACKEND_SPLIT_AXIS_2,
	// tensor split by tensor dimensions:
	BACKEND_SPLIT_AXIS_3,
	// all values on all backends
	BACKEND_SPLIT_AXIS_MIRRORED = 10,
	// each backend has a partial sum
	BACKEND_SPLIT_AXIS_PARTIAL,
	// for internal bookkeeping only:
	BACKEND_SPLIT_AXIS_NONE = 98,
	// for internal bookkeeping only:
	BACKEND_SPLIT_AXIS_UNKNOWN,
}

backend_meta_split_state :: struct {
	axis:       backend_meta_split_axis,
	// for tensors with axis >= 0 && axis < GGML_MAX_DIMS:
	//   - each device has a slice of the tensor along the split axis
	//   - most tensors have n_segments == 1 and a contiguous slice of the tensor data
	//   - some tensors have an inhomogenenous data layout along the split axis,
	//     those tensors are divided into segments which are each individually split across devices
	//   - ne has one entry per segment and device and that segment repeats nr times,
	//     in total when accounting for repetitions the segments add up to ggml_tensor::ne for that axis,
	//     the outer/inner loops are over segments/devices like [seg0_dev0_r0, seg0_dev1_r0, seg0_dev0_r1, seg0_dev1_r1, seg1_dev0_r0, seg1_dev1_r0],
	//   - for example, a transformer may have a fused QKV matrix rather than 3 matrices, those would be 3 separate segments
	//     that each need to be split individually across devices so that each device gets a slice of Q, K, and V,
	//     the Q matrix can be larger than the K and V matrices so this can either be expressed as 3 segments or as 2 segments
	//     where the segment for K/V repeats twice
	ne:         [256]i64,
	nr:         [16]u32,
	n_segments: u32,
}

// function to assign split states for statically allocated tensors, compute tensor split states will be assigned to be compatible:
backend_meta_get_split_state_t :: proc "c" (_: ^tensor, _: rawptr) -> backend_meta_split_state

//
// Utils
//
backend_graph_copy :: struct {
	buffer:          backend_buffer_t,
	ctx_allocated:   context_,
	ctx_unallocated: context_,
	graph:           cgraph,
}

backend_eval_callback :: proc "c" (_: i32, _: ^tensor, _: ^tensor, _: rawptr) -> bool

@(link_prefix = "ggml_")
foreign lib {
	//
	// Backend buffer type
	//
	backend_buft_name :: proc(buft: backend_buffer_type_t) -> cstring ---
	backend_buft_alloc_buffer :: proc(buft: backend_buffer_type_t, size: uint) -> backend_buffer_t ---
	backend_buft_get_alignment :: proc(buft: backend_buffer_type_t) -> uint ---
	backend_buft_get_max_size :: proc(buft: backend_buffer_type_t) -> uint ---
	backend_buft_get_alloc_size :: proc(buft: backend_buffer_type_t, tensor_: ^tensor) -> uint ---
	backend_buft_is_host :: proc(buft: backend_buffer_type_t) -> bool ---
	backend_buft_get_device :: proc(buft: backend_buffer_type_t) -> backend_dev_t ---
	backend_buffer_name :: proc(buffer: backend_buffer_t) -> cstring ---
	backend_buffer_free :: proc(buffer: backend_buffer_t) ---
	backend_buffer_get_base :: proc(buffer: backend_buffer_t) -> rawptr ---
	backend_buffer_get_size :: proc(buffer: backend_buffer_t) -> uint ---
	backend_buffer_init_tensor :: proc(buffer: backend_buffer_t, tensor_: ^tensor) -> status ---
	backend_buffer_get_alignment :: proc(buffer: backend_buffer_t) -> uint ---
	backend_buffer_get_max_size :: proc(buffer: backend_buffer_t) -> uint ---
	backend_buffer_get_alloc_size :: proc(buffer: backend_buffer_t, tensor_: ^tensor) -> uint ---
	backend_buffer_clear :: proc(buffer: backend_buffer_t, value: u8) ---
	backend_buffer_is_host :: proc(buffer: backend_buffer_t) -> bool ---
	backend_buffer_set_usage :: proc(buffer: backend_buffer_t, usage: backend_buffer_usage) ---
	backend_buffer_get_usage :: proc(buffer: backend_buffer_t) -> backend_buffer_usage ---
	backend_buffer_get_type :: proc(buffer: backend_buffer_t) -> backend_buffer_type_t ---
	backend_buffer_reset :: proc(buffer: backend_buffer_t) ---
	// tensor copy between different backends
	backend_tensor_copy :: proc(src: ^tensor, dst: ^tensor) ---
	//
	// Backend (stream)
	//
	backend_guid :: proc(backend: backend_t) -> guid_t ---
	backend_name :: proc(backend: backend_t) -> cstring ---
	backend_free :: proc(backend: backend_t) ---
	backend_get_default_buffer_type :: proc(backend: backend_t) -> backend_buffer_type_t ---
	backend_alloc_buffer :: proc(backend: backend_t, size: uint) -> backend_buffer_t ---
	backend_get_alignment :: proc(backend: backend_t) -> uint ---
	backend_get_max_size :: proc(backend: backend_t) -> uint ---
	backend_tensor_set_async :: proc(backend: backend_t, tensor_: ^tensor, data: rawptr, offset: uint, size: uint) ---
	backend_tensor_get_async :: proc(backend: backend_t, tensor_: ^tensor, data: rawptr, offset: uint, size: uint) ---
	backend_tensor_set_2d_async :: proc(backend: backend_t, tensor_: ^tensor, data: rawptr, offset: uint, size: uint, n_copies: uint, stride_tensor: uint, stride_data: uint) ---
	backend_tensor_get_2d_async :: proc(backend: backend_t, tensor_: ^tensor, data: rawptr, offset: uint, size: uint, n_copies: uint, stride_tensor: uint, stride_data: uint) ---
	// "offset" refers to the offset in tensor->data for setting/getting data
	backend_tensor_set :: proc(tensor_: ^tensor, data: rawptr, offset: uint, size: uint) ---
	backend_tensor_get :: proc(tensor_: ^tensor, data: rawptr, offset: uint, size: uint) ---
	backend_tensor_set_2d :: proc(tensor_: ^tensor, data: rawptr, offset: uint, size: uint, n_copies: uint, stride_tensor: uint, stride_data: uint) ---
	backend_tensor_get_2d :: proc(tensor_: ^tensor, data: rawptr, offset: uint, size: uint, n_copies: uint, stride_tensor: uint, stride_data: uint) ---
	backend_tensor_memset :: proc(tensor_: ^tensor, value: u8, offset: uint, size: uint) ---
	backend_synchronize :: proc(backend: backend_t) ---
	backend_graph_plan_create :: proc(backend: backend_t, cgraph_: cgraph) -> backend_graph_plan_t ---
	backend_graph_plan_free :: proc(backend: backend_t, plan: backend_graph_plan_t) ---
	backend_graph_plan_compute :: proc(backend: backend_t, plan: backend_graph_plan_t) -> status ---
	backend_graph_compute :: proc(backend: backend_t, cgraph_: cgraph) -> status ---
	backend_graph_compute_async :: proc(backend: backend_t, cgraph_: cgraph) -> status ---
	// NOTE: will be removed, use device version instead
	backend_supports_op :: proc(backend: backend_t, op: ^tensor) -> bool ---
	backend_supports_buft :: proc(backend: backend_t, buft: backend_buffer_type_t) -> bool ---
	backend_offload_op :: proc(backend: backend_t, op: ^tensor) -> bool ---
	// asynchronous copy
	// the copy is performed after all the currently queued operations in backend_src
	// backend_dst will wait for the copy to complete before performing other operations
	// automatic fallback to sync copy if async is not supported
	backend_tensor_copy_async :: proc(backend_src: backend_t, backend_dst: backend_t, src: ^tensor, dst: ^tensor) ---
	backend_get_device :: proc(backend: backend_t) -> backend_dev_t ---
	//
	// Events
	//
	backend_event_new :: proc(device: backend_dev_t) -> backend_event_t ---
	backend_event_free :: proc(event: backend_event_t) ---
	backend_event_record :: proc(event: backend_event_t, backend: backend_t) ---
	backend_event_synchronize :: proc(event: backend_event_t) ---
	backend_event_wait :: proc(backend: backend_t, event: backend_event_t) ---
	backend_dev_name :: proc(device: backend_dev_t) -> cstring ---
	backend_dev_description :: proc(device: backend_dev_t) -> cstring ---
	backend_dev_memory :: proc(device: backend_dev_t, free: ^uint, total: ^uint) ---
	@(link_name = "ggml_backend_dev_type")
	backend_dev_get_type :: proc(device: backend_dev_t) -> backend_dev_type ---
	backend_dev_get_props :: proc(device: backend_dev_t, props: ^backend_dev_props) ---
	backend_dev_backend_reg :: proc(device: backend_dev_t) -> backend_reg_t ---
	backend_dev_init :: proc(device: backend_dev_t, params: cstring) -> backend_t ---
	backend_dev_buffer_type :: proc(device: backend_dev_t) -> backend_buffer_type_t ---
	backend_dev_host_buffer_type :: proc(device: backend_dev_t) -> backend_buffer_type_t ---
	backend_dev_buffer_from_host_ptr :: proc(device: backend_dev_t, ptr: rawptr, size: uint, max_tensor_size: uint) -> backend_buffer_t ---
	backend_dev_supports_op :: proc(device: backend_dev_t, op: ^tensor) -> bool ---
	backend_dev_supports_buft :: proc(device: backend_dev_t, buft: backend_buffer_type_t) -> bool ---
	backend_dev_offload_op :: proc(device: backend_dev_t, op: ^tensor) -> bool ---
	//
	// Backend (reg)
	//
	backend_reg_name :: proc(reg: backend_reg_t) -> cstring ---
	backend_reg_dev_count :: proc(reg: backend_reg_t) -> uint ---
	backend_reg_dev_get :: proc(reg: backend_reg_t, index: uint) -> backend_dev_t ---
	backend_reg_get_proc_address :: proc(reg: backend_reg_t, name: cstring) -> rawptr ---
	//
	// Backend registry
	//
	backend_register :: proc(reg: backend_reg_t) ---
	backend_device_register :: proc(device: backend_dev_t) ---
	// Backend (reg) enumeration
	backend_reg_count :: proc() -> uint ---
	backend_reg_get :: proc(index: uint) -> backend_reg_t ---
	backend_reg_by_name :: proc(name: cstring) -> backend_reg_t ---
	// Device enumeration
	backend_dev_count :: proc() -> uint ---
	backend_dev_get :: proc(index: uint) -> backend_dev_t ---
	backend_dev_by_name :: proc(name: cstring) -> backend_dev_t ---
	backend_dev_by_type :: proc(type: backend_dev_type) -> backend_dev_t ---
	// Direct backend (stream) initialization
	// = ggml_backend_dev_init(ggml_backend_dev_by_name(name), params)
	backend_init_by_name :: proc(name: cstring, params: cstring) -> backend_t ---
	// = ggml_backend_dev_init(ggml_backend_dev_by_type(type), params)
	backend_init_by_type :: proc(type: backend_dev_type, params: cstring) -> backend_t ---
	// = ggml_backend_dev_init(ggml_backend_dev_by_type(GPU) OR ggml_backend_dev_by_type(CPU), NULL)
	backend_init_best :: proc() -> backend_t ---
	// Load a backend from a dynamic library and register it
	backend_load :: proc(path: cstring) -> backend_reg_t ---
	// Unload a backend if loaded dynamically and unregister it
	backend_unload :: proc(reg: backend_reg_t) ---
	// Load all known backends from dynamic libraries
	backend_load_all :: proc() ---
	backend_load_all_from_path :: proc(dir_path: cstring) ---
	// Initialize a backend scheduler, backends with low index are given priority over backends with high index
	backend_sched_new :: proc(backends: [^]backend_t, bufts: [^]backend_buffer_type_t, n_backends: i32, graph_size: uint, parallel: bool, op_offload: bool) -> backend_sched_t ---
	backend_sched_free :: proc(sched: backend_sched_t) ---
	// Initialize backend buffers from a measure graph
	backend_sched_reserve_size :: proc(sched: backend_sched_t, measure_graph: cgraph, sizes: ^uint) ---
	backend_sched_reserve :: proc(sched: backend_sched_t, measure_graph: cgraph) -> bool ---
	backend_sched_get_n_backends :: proc(sched: backend_sched_t) -> i32 ---
	backend_sched_get_backend :: proc(sched: backend_sched_t, i: i32) -> backend_t ---
	// Get the number of splits of the last graph
	backend_sched_get_n_splits :: proc(sched: backend_sched_t) -> i32 ---
	backend_sched_get_n_copies :: proc(sched: backend_sched_t) -> i32 ---
	backend_sched_get_buffer_type :: proc(sched: backend_sched_t, backend: backend_t) -> backend_buffer_type_t ---
	backend_sched_get_buffer_size :: proc(sched: backend_sched_t, backend: backend_t) -> uint ---
	backend_sched_set_tensor_backend :: proc(sched: backend_sched_t, node: ^tensor, backend: backend_t) ---
	backend_sched_get_tensor_backend :: proc(sched: backend_sched_t, node: ^tensor) -> backend_t ---
	// Split graph without allocating it
	backend_sched_split_graph :: proc(sched: backend_sched_t, graph: cgraph) ---
	// Allocate and compute graph on the backend scheduler
	backend_sched_alloc_graph :: proc(sched: backend_sched_t, graph: cgraph) -> bool ---
	backend_sched_graph_compute :: proc(sched: backend_sched_t, graph: cgraph) -> status ---
	backend_sched_graph_compute_async :: proc(sched: backend_sched_t, graph: cgraph) -> status ---
	backend_sched_synchronize :: proc(sched: backend_sched_t) ---
	// Reset all assignments and allocators - must be called before changing the node backends or allocating a new graph.
	// This in effect deallocates all tensors that were previously allocated and leaves them with dangling pointers.
	// The correct way to use this API is to discard the deallocated tensors and create new ones.
	backend_sched_reset :: proc(sched: backend_sched_t) ---
	// Set a callback to be called for each resulting node during graph compute
	backend_sched_set_eval_callback :: proc(sched: backend_sched_t, callback: backend_sched_eval_callback, user_data: rawptr) ---
	backend_meta_split_axis_name :: proc(split_axis: backend_meta_split_axis) -> cstring ---
	// create a new meta device from "simple" devices, meta buffer type/buffer/backend is then derived from this:
	// TODO: this looks a bit strange - a backend API creates a device. I think we should try
	//       express this as a backend registry functionality instead
	backend_meta_device :: proc(devs: ^backend_dev_t, n_devs: uint, get_split_state: backend_meta_get_split_state_t, get_split_state_ud: rawptr) -> backend_dev_t ---
	// Copy a graph to a different backend
	@(link_name = "ggml_backend_graph_copy")
	backend_graph_copy_create :: proc(backend: backend_t, graph: cgraph) -> backend_graph_copy ---
	backend_graph_copy_free :: proc(copy: backend_graph_copy) ---
	// Compare the output of two backends
	backend_compare_graph_backend :: proc(backend1: backend_t, backend2: backend_t, graph: cgraph, callback: backend_eval_callback, user_data: rawptr, test_nodes: ^^tensor, num_test_nodes: uint) -> bool ---
	// Tensor initialization
	backend_tensor_alloc :: proc(buffer: backend_buffer_t, tensor_: ^tensor, addr: rawptr) -> status ---
	backend_view_init :: proc(tensor_: ^tensor) -> status ---
	// CPU buffer types are always available
	backend_cpu_buffer_from_ptr :: proc(ptr: rawptr, size: uint) -> backend_buffer_t ---
	backend_cpu_buffer_type :: proc() -> backend_buffer_type_t ---
}
