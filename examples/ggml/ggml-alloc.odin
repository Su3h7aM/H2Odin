package ggml

foreign import lib "system:ggml"

backend_buffer_type_t :: distinct rawptr

backend_buffer_t :: distinct rawptr

backend_t :: distinct rawptr

// Tensor allocator
tallocr :: struct {
	buffer:    backend_buffer_t,
	base:      rawptr,
	alignment: uint,
	offset:    uint,
}

// special tensor flags for use with the graph allocator:
//   ggml_set_input(): all input tensors are allocated at the beginning of the graph in non-overlapping addresses
//   ggml_set_output(): output tensors are never freed and never overwritten
gallocr_t :: distinct rawptr

@(link_prefix = "ggml_")
foreign lib {
	tallocr_new :: proc(buffer: backend_buffer_t) -> tallocr ---
	tallocr_alloc :: proc(talloc: ^tallocr, tensor_: ^tensor) -> status ---
	gallocr_new :: proc(buft: backend_buffer_type_t) -> gallocr_t ---
	gallocr_new_n :: proc(bufts: [^]backend_buffer_type_t, n_bufs: i32) -> gallocr_t ---
	gallocr_free :: proc(galloc: gallocr_t) ---
	// pre-allocate buffers from a measure graph - does not allocate or modify the graph
	// call with a worst-case graph to avoid buffer reallocations
	// not strictly required for single buffer usage: ggml_gallocr_alloc_graph will reallocate the buffers automatically if needed
	// returns false if the buffer allocation failed
	// ggml_gallocr_resrve_n_size writes the buffer sizes per galloc buffer that would be allocated by ggml_gallocr_reserve_n to sizes
	gallocr_reserve :: proc(galloc: gallocr_t, graph: cgraph) -> bool ---
	gallocr_reserve_n_size :: proc(galloc: gallocr_t, graph: cgraph, node_buffer_ids: ^i32, leaf_buffer_ids: ^i32, sizes: ^uint) ---
	gallocr_reserve_n :: proc(galloc: gallocr_t, graph: cgraph, node_buffer_ids: ^i32, leaf_buffer_ids: ^i32) -> bool ---
	// automatic reallocation if the topology changes when using a single buffer
	// returns false if using multiple buffers and a re-allocation is needed (call ggml_gallocr_reserve_n first to set the node buffers)
	gallocr_alloc_graph :: proc(galloc: gallocr_t, graph: cgraph) -> bool ---
	gallocr_get_buffer_size :: proc(galloc: gallocr_t, buffer_id: i32) -> uint ---
	// Utils
	// Create a buffer and allocate all the tensors in a ggml_context
	// ggml_backend_alloc_ctx_tensors_from_buft_size returns the size of the buffer that would be allocated by ggml_backend_alloc_ctx_tensors_from_buft
	// ggml_backend_alloc_ctx_tensors_from_buft returns NULL on failure or if all tensors in ctx are already allocated or zero-sized
	backend_alloc_ctx_tensors_from_buft_size :: proc(ctx: context_, buft: backend_buffer_type_t) -> uint ---
	backend_alloc_ctx_tensors_from_buft :: proc(ctx: context_, buft: backend_buffer_type_t) -> backend_buffer_t ---
	backend_alloc_ctx_tensors :: proc(ctx: context_, backend: backend_t) -> backend_buffer_t ---
}
