package ggml

foreign import lib "system:ggml"

GGUF_MAGIC :: "GGUF"
GGUF_VERSION :: 3
GGUF_KEY_GENERAL_ALIGNMENT :: "general.alignment"
GGUF_DEFAULT_ALIGNMENT :: 32
// types that can be stored as GGUF KV data
gguf_type :: enum u32 {
	TYPE_UINT8,
	TYPE_INT8,
	TYPE_UINT16,
	TYPE_INT16,
	TYPE_UINT32,
	TYPE_INT32,
	TYPE_FLOAT32,
	TYPE_BOOL,
	TYPE_STRING,
	TYPE_ARRAY,
	TYPE_UINT64,
	TYPE_INT64,
	TYPE_FLOAT64,
	// marks the end of the enum
	TYPE_COUNT,
}

gguf_context :: distinct rawptr

gguf_init_params :: struct {
	no_alloc: bool,
	// if not NULL, create a ggml_context and allocate the tensor data in it
	ctx:      ^context_,
}

// callback to simulate or wrap a FILE pointer - read up to `len` bytes at `offset` into `output` and return the number of bytes read
gguf_reader_callback_t :: proc "c" (_: rawptr, _: rawptr, _: u64, _: uint) -> uint

@(link_prefix = "ggml_")
foreign lib {
	gguf_init_empty :: proc() -> gguf_context ---
	gguf_init_from_file_ptr :: proc(file: _IO_FILE, params: gguf_init_params) -> gguf_context ---
	gguf_init_from_file :: proc(fname: cstring, params: gguf_init_params) -> gguf_context ---
	gguf_init_from_buffer :: proc(data: rawptr, size: uint, params: gguf_init_params) -> gguf_context ---
	// max_chunk_read is the maximum number of bytes that the GGUF code will read at once from the callback, a value of 0 means no limit
	gguf_init_from_callback :: proc(callback: gguf_reader_callback_t, userdata: rawptr, max_chunk_read: uint, max_expected_size: u64, params: gguf_init_params) -> gguf_context ---
	gguf_free :: proc(ctx: gguf_context) ---
	gguf_type_name :: proc(type: gguf_type) -> cstring ---
	gguf_get_version :: proc(ctx: gguf_context) -> u32 ---
	gguf_get_alignment :: proc(ctx: gguf_context) -> uint ---
	gguf_get_data_offset :: proc(ctx: gguf_context) -> uint ---
	gguf_get_n_kv :: proc(ctx: gguf_context) -> i64 ---
	gguf_find_key :: proc(ctx: gguf_context, key: cstring) -> i64 ---
	gguf_get_key :: proc(ctx: gguf_context, key_id: i64) -> cstring ---
	gguf_get_kv_type :: proc(ctx: gguf_context, key_id: i64) -> gguf_type ---
	gguf_get_arr_type :: proc(ctx: gguf_context, key_id: i64) -> gguf_type ---
	// will abort if the wrong type is used for the key
	gguf_get_val_u8 :: proc(ctx: gguf_context, key_id: i64) -> u8 ---
	gguf_get_val_i8 :: proc(ctx: gguf_context, key_id: i64) -> i8 ---
	gguf_get_val_u16 :: proc(ctx: gguf_context, key_id: i64) -> u16 ---
	gguf_get_val_i16 :: proc(ctx: gguf_context, key_id: i64) -> i16 ---
	gguf_get_val_u32 :: proc(ctx: gguf_context, key_id: i64) -> u32 ---
	gguf_get_val_i32 :: proc(ctx: gguf_context, key_id: i64) -> i32 ---
	gguf_get_val_f32 :: proc(ctx: gguf_context, key_id: i64) -> f32 ---
	gguf_get_val_u64 :: proc(ctx: gguf_context, key_id: i64) -> u64 ---
	gguf_get_val_i64 :: proc(ctx: gguf_context, key_id: i64) -> i64 ---
	gguf_get_val_f64 :: proc(ctx: gguf_context, key_id: i64) -> f64 ---
	gguf_get_val_bool :: proc(ctx: gguf_context, key_id: i64) -> bool ---
	gguf_get_val_str :: proc(ctx: gguf_context, key_id: i64) -> cstring ---
	gguf_get_val_data :: proc(ctx: gguf_context, key_id: i64) -> rawptr ---
	gguf_get_arr_n :: proc(ctx: gguf_context, key_id: i64) -> uint ---
	// get raw pointer to the first element of the array with the given key_id
	// for bool arrays, note that they are always stored as int8 on all platforms (usually this makes no difference)
	gguf_get_arr_data :: proc(ctx: gguf_context, key_id: i64) -> rawptr ---
	// get ith C string from array with given key_id
	gguf_get_arr_str :: proc(ctx: gguf_context, key_id: i64, i: uint) -> cstring ---
	gguf_get_n_tensors :: proc(ctx: gguf_context) -> i64 ---
	gguf_find_tensor :: proc(ctx: gguf_context, name: cstring) -> i64 ---
	gguf_get_tensor_offset :: proc(ctx: gguf_context, tensor_id: i64) -> uint ---
	gguf_get_tensor_name :: proc(ctx: gguf_context, tensor_id: i64) -> cstring ---
	gguf_get_tensor_type :: proc(ctx: gguf_context, tensor_id: i64) -> type ---
	gguf_get_tensor_size :: proc(ctx: gguf_context, tensor_id: i64) -> uint ---
	// removes key if it exists, returns id that the key had prior to removal (-1 if it didn't exist)
	gguf_remove_key :: proc(ctx: gguf_context, key: cstring) -> i64 ---
	// overrides an existing KV pair or adds a new one, the new KV pair is always at the back
	gguf_set_val_u8 :: proc(ctx: gguf_context, key: cstring, val: u8) ---
	gguf_set_val_i8 :: proc(ctx: gguf_context, key: cstring, val: i8) ---
	gguf_set_val_u16 :: proc(ctx: gguf_context, key: cstring, val: u16) ---
	gguf_set_val_i16 :: proc(ctx: gguf_context, key: cstring, val: i16) ---
	gguf_set_val_u32 :: proc(ctx: gguf_context, key: cstring, val: u32) ---
	gguf_set_val_i32 :: proc(ctx: gguf_context, key: cstring, val: i32) ---
	gguf_set_val_f32 :: proc(ctx: gguf_context, key: cstring, val: f32) ---
	gguf_set_val_u64 :: proc(ctx: gguf_context, key: cstring, val: u64) ---
	gguf_set_val_i64 :: proc(ctx: gguf_context, key: cstring, val: i64) ---
	gguf_set_val_f64 :: proc(ctx: gguf_context, key: cstring, val: f64) ---
	gguf_set_val_bool :: proc(ctx: gguf_context, key: cstring, val: bool) ---
	gguf_set_val_str :: proc(ctx: gguf_context, key: cstring, val: cstring) ---
	// creates a new array with n elements of the given type and copies the corresponding number of bytes from data
	gguf_set_arr_data :: proc(ctx: gguf_context, key: cstring, type: gguf_type, data: rawptr, n: uint) ---
	// creates a new array with n strings and copies the corresponding strings from data
	gguf_set_arr_str :: proc(ctx: gguf_context, key: cstring, data: ^cstring, n: uint) ---
	// set or add KV pairs from another context
	gguf_set_kv :: proc(ctx: gguf_context, src: gguf_context) ---
	// add tensor to GGUF context, tensor name must be unique
	gguf_add_tensor :: proc(ctx: gguf_context, tensor_: ^tensor) ---
	// after changing a tensor's type, the offsets of all tensors with higher indices are immediately recalculated
	//   in such a way that the tensor data remains as one contiguous block (except for padding)
	gguf_set_tensor_type :: proc(ctx: gguf_context, name: cstring, type: type) ---
	// assumes that at least gguf_get_tensor_size bytes can be read from data
	gguf_set_tensor_data :: proc(ctx: gguf_context, name: cstring, data: rawptr) ---
	// write the entire context to a binary file
	gguf_write_to_file_ptr :: proc(ctx: gguf_context, file: _IO_FILE, only_meta: bool) -> bool ---
	gguf_write_to_file :: proc(ctx: gguf_context, fname: cstring, only_meta: bool) -> bool ---
	// get the size in bytes of the meta data (header, kv pairs, tensor info) including padding
	gguf_get_meta_size :: proc(ctx: gguf_context) -> uint ---
	// writes the meta data to pointer "data"
	gguf_get_meta_data :: proc(ctx: gguf_context, data: rawptr) ---
}
