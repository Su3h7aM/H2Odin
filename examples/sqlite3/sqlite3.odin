package sqlite3

foreign import lib "system:sqlite3"

SQLITE_VERSION :: "3.53.2"
SQLITE_VERSION_NUMBER :: 3053002
SQLITE_SOURCE_ID :: "2026-06-03 19:12:13 d6e03d8c777cfa2d35e3b60d8ec3e0187f3e9f99d8e2ee9cac695fd6fcdfalt1"
SQLITE_SCM_BRANCH :: "branch-3.53"
SQLITE_SCM_TAGS :: "release version-3.53.2"
SQLITE_SCM_DATETIME :: "2026-06-03T19:12:13.350Z"
SQLITE_SHM_NLOCK :: 8
SQLITE_SETLK_BLOCK_ON_CONNECT :: 0x01
SQLITE3_TEXT :: 3
SQLITE_DETERMINISTIC :: 0x000000800
SQLITE_DIRECTONLY :: 0x000080000
SQLITE_SUBTYPE :: 0x000100000
SQLITE_INNOCUOUS :: 0x000200000
SQLITE_RESULT_SUBTYPE :: 0x001000000
SQLITE_SELFORDER1 :: 0x002000000
SQLITE_WIN32_DATA_DIRECTORY_TYPE :: 1
SQLITE_WIN32_TEMP_DIRECTORY_TYPE :: 2
SQLITE_SCANSTAT_COMPLEX :: 0x0001
NOT_WITHIN :: 0
PARTLY_WITHIN :: 1
FULLY_WITHIN :: 2
FTS5_TOKENIZE_QUERY :: 0x0001
FTS5_TOKENIZE_PREFIX :: 0x0002
FTS5_TOKENIZE_DOCUMENT :: 0x0004
FTS5_TOKENIZE_AUX :: 0x0008
FTS5_TOKEN_COLOCATED :: 0x0001
Sqlite3 :: struct {}

Callback :: proc "c" (_: rawptr, _: i32, _: ^^u8, _: ^^u8) -> i32

File :: struct {
	p_methods: ^Io_Methods,
}

Io_Methods :: struct {
	i_version: i32,
	x_close: proc "c" (_: ^File) -> i32,
	x_read: proc "c" (_: ^File, _: rawptr, _: i32, _: i64) -> i32,
	x_write: proc "c" (_: ^File, _: rawptr, _: i32, _: i64) -> i32,
	x_truncate: proc "c" (_: ^File, _: i64) -> i32,
	x_sync: proc "c" (_: ^File, _: i32) -> i32,
	x_file_size: proc "c" (_: ^File, _: ^i64) -> i32,
	x_lock: proc "c" (_: ^File, _: i32) -> i32,
	x_unlock: proc "c" (_: ^File, _: i32) -> i32,
	x_check_reserved_lock: proc "c" (_: ^File, _: ^i32) -> i32,
	x_file_control: proc "c" (_: ^File, _: i32, _: rawptr) -> i32,
	x_sector_size: proc "c" (_: ^File) -> i32,
	x_device_characteristics: proc "c" (_: ^File) -> i32,
	x_shm_map: proc "c" (_: ^File, _: i32, _: i32, _: i32, _: ^rawptr) -> i32,
	x_shm_lock: proc "c" (_: ^File, _: i32, _: i32, _: i32) -> i32,
	x_shm_barrier: proc "c" (_: ^File),
	x_shm_unmap: proc "c" (_: ^File, _: i32) -> i32,
	x_fetch: proc "c" (_: ^File, _: i64, _: i32, _: ^rawptr) -> i32,
	x_unfetch: proc "c" (_: ^File, _: i64, _: rawptr) -> i32,
}

Mutex :: struct {}

Api_Routines :: struct {}

Filename :: cstring

Vfs :: struct {
	i_version: i32,
	sz_os_file: i32,
	mx_pathname: i32,
	p_next: ^Vfs,
	z_name: cstring,
	p_app_data: rawptr,
	x_open: proc "c" (_: ^Vfs, _: Filename, _: ^File, _: i32, _: ^i32) -> i32,
	x_delete: proc "c" (_: ^Vfs, _: cstring, _: i32) -> i32,
	x_access: proc "c" (_: ^Vfs, _: cstring, _: i32, _: ^i32) -> i32,
	x_full_pathname: proc "c" (_: ^Vfs, _: cstring, _: i32, _: ^u8) -> i32,
	x_dl_open: proc "c" (_: ^Vfs, _: cstring) -> rawptr,
	x_dl_error: proc "c" (_: ^Vfs, _: i32, _: ^u8),
	x_dl_sym: proc "c" (_: ^Vfs, _: rawptr, _: cstring) -> proc "c" (),
	x_dl_close: proc "c" (_: ^Vfs, _: rawptr),
	x_randomness: proc "c" (_: ^Vfs, _: i32, _: ^u8) -> i32,
	x_sleep: proc "c" (_: ^Vfs, _: i32) -> i32,
	x_current_time: proc "c" (_: ^Vfs, _: ^f64) -> i32,
	x_get_last_error: proc "c" (_: ^Vfs, _: i32, _: ^u8) -> i32,
	x_current_time_int64: proc "c" (_: ^Vfs, _: ^i64) -> i32,
	x_set_system_call: proc "c" (_: ^Vfs, _: cstring, _: Syscall_Ptr) -> i32,
	x_get_system_call: proc "c" (_: ^Vfs, _: cstring) -> Syscall_Ptr,
	x_next_system_call: proc "c" (_: ^Vfs, _: cstring) -> cstring,
}

Syscall_Ptr :: proc "c" ()

Mem_Methods :: struct {
	x_malloc: proc "c" (_: i32) -> rawptr,
	x_free: proc "c" (_: rawptr),
	x_realloc: proc "c" (_: rawptr, _: i32) -> rawptr,
	x_size: proc "c" (_: rawptr) -> i32,
	x_roundup: proc "c" (_: i32) -> i32,
	x_init: proc "c" (_: rawptr) -> i32,
	x_shutdown: proc "c" (_: rawptr),
	p_app_data: rawptr,
}

Va_List_Tag :: struct {
	gp_offset: u32,
	fp_offset: u32,
	overflow_arg_area: rawptr,
	reg_save_area: rawptr,
}

Stmt :: struct {}

Value :: struct {}

Context :: struct {}

Destructor_Type :: proc "c" (_: rawptr)

Vtab :: struct {
	p_module: ^Module,
	n_ref: i32,
	z_err_msg: ^u8,
}

Index_Info :: struct {
	n_constraint: i32,
	a_constraint: ^Index_Constraint,
	n_order_by: i32,
	a_order_by: ^Index_Orderby,
	a_constraint_usage: ^Index_Constraint_Usage,
	idx_num: i32,
	idx_str: ^u8,
	need_to_free_idx_str: i32,
	order_by_consumed: i32,
	estimated_cost: f64,
	estimated_rows: i64,
	idx_flags: i32,
	col_used: u64,
}

Vtab_Cursor :: struct {
	p_vtab: ^Vtab,
}

Module :: struct {
	i_version: i32,
	x_create: proc "c" (_: ^Sqlite3, _: rawptr, _: i32, _: ^cstring, _: ^^Vtab, _: ^^u8) -> i32,
	x_connect: proc "c" (_: ^Sqlite3, _: rawptr, _: i32, _: ^cstring, _: ^^Vtab, _: ^^u8) -> i32,
	x_best_index: proc "c" (_: ^Vtab, _: ^Index_Info) -> i32,
	x_disconnect: proc "c" (_: ^Vtab) -> i32,
	x_destroy: proc "c" (_: ^Vtab) -> i32,
	x_open: proc "c" (_: ^Vtab, _: ^^Vtab_Cursor) -> i32,
	x_close: proc "c" (_: ^Vtab_Cursor) -> i32,
	x_filter: proc "c" (_: ^Vtab_Cursor, _: i32, _: cstring, _: i32, _: ^^Value) -> i32,
	x_next: proc "c" (_: ^Vtab_Cursor) -> i32,
	x_eof: proc "c" (_: ^Vtab_Cursor) -> i32,
	x_column: proc "c" (_: ^Vtab_Cursor, _: ^Context, _: i32) -> i32,
	x_rowid: proc "c" (_: ^Vtab_Cursor, _: ^i64) -> i32,
	x_update: proc "c" (_: ^Vtab, _: i32, _: ^^Value, _: ^i64) -> i32,
	x_begin: proc "c" (_: ^Vtab) -> i32,
	x_sync: proc "c" (_: ^Vtab) -> i32,
	x_commit: proc "c" (_: ^Vtab) -> i32,
	x_rollback: proc "c" (_: ^Vtab) -> i32,
	x_find_function: proc "c" (_: ^Vtab, _: i32, _: cstring, _: ^proc "c" (_: ^Context, _: i32, _: ^^Value), _: ^rawptr) -> i32,
	x_rename: proc "c" (_: ^Vtab, _: cstring) -> i32,
	x_savepoint: proc "c" (_: ^Vtab, _: i32) -> i32,
	x_release: proc "c" (_: ^Vtab, _: i32) -> i32,
	x_rollback_to: proc "c" (_: ^Vtab, _: i32) -> i32,
	x_shadow_name: proc "c" (_: cstring) -> i32,
	x_integrity: proc "c" (_: ^Vtab, _: cstring, _: cstring, _: i32, _: ^^u8) -> i32,
}

Index_Constraint :: struct {
	i_column: i32,
	op: u8,
	usable: u8,
	i_term_offset: i32,
}

Index_Orderby :: struct {
	i_column: i32,
	desc: u8,
}

Index_Constraint_Usage :: struct {
	argv_index: i32,
	omit: u8,
}

Blob :: struct {}

Mutex_Methods :: struct {
	x_mutex_init: proc "c" () -> i32,
	x_mutex_end: proc "c" () -> i32,
	x_mutex_alloc: proc "c" (_: i32) -> ^Mutex,
	x_mutex_free: proc "c" (_: ^Mutex),
	x_mutex_enter: proc "c" (_: ^Mutex),
	x_mutex_try: proc "c" (_: ^Mutex) -> i32,
	x_mutex_leave: proc "c" (_: ^Mutex),
	x_mutex_held: proc "c" (_: ^Mutex) -> i32,
	x_mutex_notheld: proc "c" (_: ^Mutex) -> i32,
}

Str :: struct {}

Pcache :: struct {}

Pcache_Page :: struct {
	p_buf: rawptr,
	p_extra: rawptr,
}

Pcache_Methods2 :: struct {
	i_version: i32,
	p_arg: rawptr,
	x_init: proc "c" (_: rawptr) -> i32,
	x_shutdown: proc "c" (_: rawptr),
	x_create: proc "c" (_: i32, _: i32, _: i32) -> ^Pcache,
	x_cachesize: proc "c" (_: ^Pcache, _: i32),
	x_pagecount: proc "c" (_: ^Pcache) -> i32,
	x_fetch: proc "c" (_: ^Pcache, _: u32, _: i32) -> ^Pcache_Page,
	x_unpin: proc "c" (_: ^Pcache, _: ^Pcache_Page, _: i32),
	x_rekey: proc "c" (_: ^Pcache, _: ^Pcache_Page, _: u32, _: u32),
	x_truncate: proc "c" (_: ^Pcache, _: u32),
	x_destroy: proc "c" (_: ^Pcache),
	x_shrink: proc "c" (_: ^Pcache),
}

Pcache_Methods :: struct {
	p_arg: rawptr,
	x_init: proc "c" (_: rawptr) -> i32,
	x_shutdown: proc "c" (_: rawptr),
	x_create: proc "c" (_: i32, _: i32) -> ^Pcache,
	x_cachesize: proc "c" (_: ^Pcache, _: i32),
	x_pagecount: proc "c" (_: ^Pcache) -> i32,
	x_fetch: proc "c" (_: ^Pcache, _: u32, _: i32) -> rawptr,
	x_unpin: proc "c" (_: ^Pcache, _: rawptr, _: i32),
	x_rekey: proc "c" (_: ^Pcache, _: rawptr, _: u32, _: u32),
	x_truncate: proc "c" (_: ^Pcache, _: u32),
	x_destroy: proc "c" (_: ^Pcache),
}

Backup :: struct {}

Snapshot :: struct {
	hidden: [48]u8,
}

Rtree_Geometry :: struct {
	p_context: rawptr,
	n_param: i32,
	a_param: ^Rtree_Dbl,
	p_user: rawptr,
	x_del_user: proc "c" (_: rawptr),
}

Rtree_Query_Info :: struct {
	p_context: rawptr,
	n_param: i32,
	a_param: ^Rtree_Dbl,
	p_user: rawptr,
	x_del_user: proc "c" (_: rawptr),
	a_coord: ^Rtree_Dbl,
	an_queue: ^u32,
	n_coord: i32,
	i_level: i32,
	mx_level: i32,
	i_rowid: i64,
	r_parent_score: Rtree_Dbl,
	e_parent_within: i32,
	e_within: i32,
	r_score: Rtree_Dbl,
	ap_sql_param: ^^Value,
}

Rtree_Dbl :: f64

Fts5_Extension_Api :: struct {
	i_version: i32,
	x_user_data: proc "c" (_: ^Fts5_Context) -> rawptr,
	x_column_count: proc "c" (_: ^Fts5_Context) -> i32,
	x_row_count: proc "c" (_: ^Fts5_Context, _: ^i64) -> i32,
	x_column_total_size: proc "c" (_: ^Fts5_Context, _: i32, _: ^i64) -> i32,
	x_tokenize: proc "c" (_: ^Fts5_Context, _: cstring, _: i32, _: rawptr, _: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32) -> i32,
	x_phrase_count: proc "c" (_: ^Fts5_Context) -> i32,
	x_phrase_size: proc "c" (_: ^Fts5_Context, _: i32) -> i32,
	x_inst_count: proc "c" (_: ^Fts5_Context, _: ^i32) -> i32,
	x_inst: proc "c" (_: ^Fts5_Context, _: i32, _: ^i32, _: ^i32, _: ^i32) -> i32,
	x_rowid: proc "c" (_: ^Fts5_Context) -> i64,
	x_column_text: proc "c" (_: ^Fts5_Context, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_column_size: proc "c" (_: ^Fts5_Context, _: i32, _: ^i32) -> i32,
	x_query_phrase: proc "c" (_: ^Fts5_Context, _: i32, _: rawptr, _: proc "c" (_: ^Fts5_Extension_Api, _: ^Fts5_Context, _: rawptr) -> i32) -> i32,
	x_set_auxdata: proc "c" (_: ^Fts5_Context, _: rawptr, _: proc "c" (_: rawptr)) -> i32,
	x_get_auxdata: proc "c" (_: ^Fts5_Context, _: i32) -> rawptr,
	x_phrase_first: proc "c" (_: ^Fts5_Context, _: i32, _: ^Fts5_Phrase_Iter, _: ^i32, _: ^i32) -> i32,
	x_phrase_next: proc "c" (_: ^Fts5_Context, _: ^Fts5_Phrase_Iter, _: ^i32, _: ^i32),
	x_phrase_first_column: proc "c" (_: ^Fts5_Context, _: i32, _: ^Fts5_Phrase_Iter, _: ^i32) -> i32,
	x_phrase_next_column: proc "c" (_: ^Fts5_Context, _: ^Fts5_Phrase_Iter, _: ^i32),
	x_query_token: proc "c" (_: ^Fts5_Context, _: i32, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_inst_token: proc "c" (_: ^Fts5_Context, _: i32, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_column_locale: proc "c" (_: ^Fts5_Context, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_tokenize_v2: proc "c" (_: ^Fts5_Context, _: cstring, _: i32, _: cstring, _: i32, _: rawptr, _: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32) -> i32,
}

Fts5_Context :: struct {}

Fts5_Phrase_Iter :: struct {
	a: ^u8,
	b: ^u8,
}

Fts5_Extension_Function :: proc "c" (_: ^Fts5_Extension_Api, _: ^Fts5_Context, _: ^Context, _: i32, _: ^^Value)

Fts5_Tokenizer :: struct {}

Fts5_Tokenizer_V2 :: struct {
	i_version: i32,
	x_create: proc "c" (_: rawptr, _: ^cstring, _: i32, _: ^^Fts5_Tokenizer) -> i32,
	x_delete: proc "c" (_: ^Fts5_Tokenizer),
	x_tokenize: proc "c" (_: ^Fts5_Tokenizer, _: rawptr, _: i32, _: cstring, _: i32, _: cstring, _: i32, _: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32) -> i32,
}

Fts5_Tokenizer_Methods :: struct {
	x_create: proc "c" (_: rawptr, _: ^cstring, _: i32, _: ^^Fts5_Tokenizer) -> i32,
	x_delete: proc "c" (_: ^Fts5_Tokenizer),
	x_tokenize: proc "c" (_: ^Fts5_Tokenizer, _: rawptr, _: i32, _: cstring, _: i32, _: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32) -> i32,
}

Fts5_Api :: struct {
	i_version: i32,
	x_create_tokenizer: proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: ^Fts5_Tokenizer_Methods, _: proc "c" (_: rawptr)) -> i32,
	x_find_tokenizer: proc "c" (_: ^Fts5_Api, _: cstring, _: ^rawptr, _: ^Fts5_Tokenizer_Methods) -> i32,
	x_create_function: proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: Fts5_Extension_Function, _: proc "c" (_: rawptr)) -> i32,
	x_create_tokenizer_v2: proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: ^Fts5_Tokenizer_V2, _: proc "c" (_: rawptr)) -> i32,
	x_find_tokenizer_v2: proc "c" (_: ^Fts5_Api, _: cstring, _: ^rawptr, _: ^^Fts5_Tokenizer_V2) -> i32,
}

Result_Code :: enum i32 {
	Ok = 0,
	Error = 1,
	Internal = 2,
	Perm = 3,
	Abort = 4,
	Busy = 5,
	Locked = 6,
	Nomem = 7,
	Readonly = 8,
	Interrupt = 9,
	Ioerr = 10,
	Corrupt = 11,
	Notfound = 12,
	Full = 13,
	Cantopen = 14,
	Protocol = 15,
	Empty = 16,
	Schema = 17,
	Toobig = 18,
	Constraint = 19,
	Mismatch = 20,
	Misuse = 21,
	Nolfs = 22,
	Auth = 23,
	Format = 24,
	Range = 25,
	Notadb = 26,
	Notice = 27,
	Warning = 28,
	Row = 100,
	Done = 101,
}

Open_Flag :: enum i32 {
	Readonly = 1,
	Readwrite = 2,
	Create = 4,
	Deleteonclose = 8,
	Exclusive = 16,
	Autoproxy = 32,
	Uri = 64,
	Memory = 128,
	Main_Db = 256,
	Temp_Db = 512,
	Transient_Db = 1024,
	Main_Journal = 2048,
	Temp_Journal = 4096,
	Subjournal = 8192,
	Super_Journal = 16384,
	Nomutex = 32768,
	Fullmutex = 65536,
	Sharedcache = 131072,
	Privatecache = 262144,
	Wal = 524288,
	Nofollow = 16777216,
	Exrescode = 33554432,
	Master_Journal = 16384,
}

Io_Capability :: enum i32 {
	Atomic = 1,
	Atomic512 = 2,
	Atomic1_K = 4,
	Atomic2_K = 8,
	Atomic4_K = 16,
	Atomic8_K = 32,
	Atomic16_K = 64,
	Atomic32_K = 128,
	Atomic64_K = 256,
	Safe_Append = 512,
	Sequential = 1024,
	Undeletable_When_Open = 2048,
	Powersafe_Overwrite = 4096,
	Immutable = 8192,
	Batch_Atomic = 16384,
	Subpage_Read = 32768,
}

Lock_Level :: enum i32 {
	None = 0,
	Shared = 1,
	Reserved = 2,
	Pending = 3,
	Exclusive = 4,
}

Sync_Flag :: enum i32 {
	Normal = 2,
	Full = 3,
	Dataonly = 16,
}

Fcntl_Opcode :: enum i32 {
	Lockstate = 1,
	Get_Lockproxyfile = 2,
	Set_Lockproxyfile = 3,
	Last_Errno = 4,
	Size_Hint = 5,
	Chunk_Size = 6,
	File_Pointer = 7,
	Sync_Omitted = 8,
	Win32_Av_Retry = 9,
	Persist_Wal = 10,
	Overwrite = 11,
	Vfsname = 12,
	Powersafe_Overwrite = 13,
	Pragma = 14,
	Busyhandler = 15,
	Tempfilename = 16,
	Mmap_Size = 18,
	Trace = 19,
	Has_Moved = 20,
	Sync = 21,
	Commit_Phasetwo = 22,
	Win32_Set_Handle = 23,
	Wal_Block = 24,
	Zipvfs = 25,
	Rbu = 26,
	Vfs_Pointer = 27,
	Journal_Pointer = 28,
	Win32_Get_Handle = 29,
	Pdb = 30,
	Begin_Atomic_Write = 31,
	Commit_Atomic_Write = 32,
	Rollback_Atomic_Write = 33,
	Lock_Timeout = 34,
	Data_Version = 35,
	Size_Limit = 36,
	Ckpt_Done = 37,
	Reserve_Bytes = 38,
	Ckpt_Start = 39,
	External_Reader = 40,
	Cksm_File = 41,
	Reset_Cache = 42,
	Null_Io = 43,
	Block_On_Connect = 44,
	Filestat = 45,
}

Access_Mode :: enum i32 {
	Exists = 0,
	Readwrite = 1,
	Read = 2,
}

Shm_Flag :: enum i32 {
	Unlock = 1,
	Lock = 2,
	Shared = 4,
	Exclusive = 8,
}

Checkpoint_Mode :: enum i32 {
	Passive = 0,
	Full = 1,
	Restart = 2,
	Truncate = 3,
}

Config_Opcode :: enum i32 {
	Singlethread = 1,
	Multithread = 2,
	Serialized = 3,
	Malloc = 4,
	Getmalloc = 5,
	Scratch = 6,
	Pagecache = 7,
	Heap = 8,
	Memstatus = 9,
	Mutex = 10,
	Getmutex = 11,
	Lookaside = 13,
	Pcache = 14,
	Getpcache = 15,
	Log = 16,
	Uri = 17,
	Pcache2 = 18,
	Getpcache2 = 19,
	Covering_Index_Scan = 20,
	Sqllog = 21,
	Mmap_Size = 22,
	Win32_Heapsize = 23,
	Pcache_Hdrsz = 24,
	Pmasz = 25,
	Stmtjrnl_Spill = 26,
	Small_Malloc = 27,
	Sorterref_Size = 28,
	Memdb_Maxsize = 29,
	Rowid_In_View = 30,
}

Db_Config :: enum i32 {
	Maindbname = 1000,
	Lookaside = 1001,
	Enable_Fkey = 1002,
	Enable_Trigger = 1003,
	Enable_Fts3_Tokenizer = 1004,
	Enable_Load_Extension = 1005,
	No_Ckpt_On_Close = 1006,
	Enable_Qpsg = 1007,
	Trigger_Eqp = 1008,
	Reset_Database = 1009,
	Defensive = 1010,
	Writable_Schema = 1011,
	Legacy_Alter_Table = 1012,
	Dqs_Dml = 1013,
	Dqs_Ddl = 1014,
	Enable_View = 1015,
	Legacy_File_Format = 1016,
	Trusted_Schema = 1017,
	Stmt_Scanstatus = 1018,
	Reverse_Scanorder = 1019,
	Enable_Attach_Create = 1020,
	Enable_Attach_Write = 1021,
	Enable_Comments = 1022,
	Fp_Digits = 1023,
	Max = 1023,
}

Limit :: enum i32 {
	Length = 0,
	Sql_Length = 1,
	Column = 2,
	Expr_Depth = 3,
	Compound_Select = 4,
	Vdbe_Op = 5,
	Function_Arg = 6,
	Attached = 7,
	Like_Pattern_Length = 8,
	Variable_Number = 9,
	Trigger_Depth = 10,
	Worker_Threads = 11,
	Parser_Depth = 12,
}

Status :: enum i32 {
	Memory_Used = 0,
	Pagecache_Used = 1,
	Pagecache_Overflow = 2,
	Scratch_Used = 3,
	Scratch_Overflow = 4,
	Malloc_Size = 5,
	Parser_Stack = 6,
	Pagecache_Size = 7,
	Scratch_Size = 8,
	Malloc_Count = 9,
}

Db_Status :: enum i32 {
	Lookaside_Used = 0,
	Cache_Used = 1,
	Schema_Used = 2,
	Stmt_Used = 3,
	Lookaside_Hit = 4,
	Lookaside_Miss_Size = 5,
	Lookaside_Miss_Full = 6,
	Cache_Hit = 7,
	Cache_Miss = 8,
	Cache_Write = 9,
	Deferred_Fks = 10,
	Cache_Used_Shared = 11,
	Cache_Spill = 12,
	Tempbuf_Spill = 13,
	Max = 13,
}

Stmt_Status :: enum i32 {
	Fullscan_Step = 1,
	Sort = 2,
	Autoindex = 3,
	Vm_Step = 4,
	Reprepare = 5,
	Run = 6,
	Filter_Miss = 7,
	Filter_Hit = 8,
	Memused = 99,
}

Trace_Flag :: enum i32 {
	Stmt = 1,
	Profile = 2,
	Row = 4,
	Close = 8,
}

Prepare_Flag :: enum i32 {
	Persistent = 1,
	Normalize = 2,
	No_Vtab = 4,
	Dont_Log = 16,
	From_Ddl = 32,
}

Txn_State :: enum i32 {
	None = 0,
	Read = 1,
	Write = 2,
}

Serialize_Flag :: enum i32 {
	Nocopy = 1,
}

Deserialize_Flag :: enum i32 {
	Freeonclose = 1,
	Resizeable = 2,
	Readonly = 4,
}

Vtab_Config :: enum i32 {
	Constraint_Support = 1,
	Innocuous = 2,
	Directonly = 3,
	Uses_All_Schemas = 4,
}

Index_Scan :: enum i32 {
	Unique = 1,
	Hex = 2,
}

Index_Constraint_Op :: enum i32 {
	Eq = 2,
	Gt = 4,
	Le = 8,
	Lt = 16,
	Ge = 32,
	Match = 64,
	Like = 65,
	Glob = 66,
	Regexp = 67,
	Ne = 68,
	Isnot = 69,
	Isnotnull = 70,
	Isnull = 71,
	Is = 72,
	Limit = 73,
	Offset = 74,
	Function = 150,
}

Scanstat :: enum i32 {
	Nloop = 0,
	Nvisit = 1,
	Est = 2,
	Name = 3,
	Explain = 4,
	Selectid = 5,
	Parentid = 6,
	Ncycle = 7,
}

Mutex_Type :: enum i32 {
	Fast = 0,
	Recursive = 1,
	Static_Main = 2,
	Static_Mem = 3,
	Static_Mem2 = 4,
	Static_Open = 4,
	Static_Prng = 5,
	Static_Lru = 6,
	Static_Lru2 = 7,
	Static_Pmem = 7,
	Static_App1 = 8,
	Static_App2 = 9,
	Static_App3 = 10,
	Static_Vfs1 = 11,
	Static_Vfs2 = 12,
	Static_Vfs3 = 13,
	Static_Master = 2,
}

Testctrl :: enum i32 {
	First = 5,
	Prng_Save = 5,
	Prng_Restore = 6,
	Prng_Reset = 7,
	Fk_No_Action = 7,
	Bitvec_Test = 8,
	Fault_Install = 9,
	Benign_Malloc_Hooks = 10,
	Pending_Byte = 11,
	Assert = 12,
	Always = 13,
	Reserve = 14,
	Json_Selfcheck = 14,
	Optimizations = 15,
	Iskeyword = 16,
	Getopt = 16,
	Scratchmalloc = 17,
	Internal_Functions = 17,
	Localtime_Fault = 18,
	Explain_Stmt = 19,
	Once_Reset_Threshold = 19,
	Never_Corrupt = 20,
	Vdbe_Coverage = 21,
	Byteorder = 22,
	Isinit = 23,
	Sorter_Mmap = 24,
	Imposter = 25,
	Parser_Coverage = 26,
	Result_Intreal = 27,
	Prng_Seed = 28,
	Extra_Schema_Checks = 29,
	Seek_Count = 30,
	Traceflags = 31,
	Tune = 32,
	Logest = 33,
	Uselongdouble = 34,
	Atof = 34,
	Last = 34,
}

Carray_Type :: enum i32 {
	Int32 = 0,
	Int64 = 1,
	Double = 2,
	Text = 3,
	Blob = 4,
}

Authorizer_Action :: enum i32 {
	Create_Index = 1,
	Create_Table = 2,
	Create_Temp_Index = 3,
	Create_Temp_Table = 4,
	Create_Temp_Trigger = 5,
	Create_Temp_View = 6,
	Create_Trigger = 7,
	Create_View = 8,
	Delete = 9,
	Drop_Index = 10,
	Drop_Table = 11,
	Drop_Temp_Index = 12,
	Drop_Temp_Table = 13,
	Drop_Temp_Trigger = 14,
	Drop_Temp_View = 15,
	Drop_Trigger = 16,
	Drop_View = 17,
	Insert = 18,
	Pragma = 19,
	Read = 20,
	Select = 21,
	Transaction = 22,
	Update = 23,
	Attach = 24,
	Detach = 25,
	Alter_Table = 26,
	Reindex = 27,
	Analyze = 28,
	Create_Vtable = 29,
	Drop_Vtable = 30,
	Function = 31,
	Savepoint = 32,
	Copy = 0,
	Recursive = 33,
}

Authorizer_Result :: enum i32 {
	Deny = 1,
	Ignore = 2,
}

Datatype :: enum i32 {
	Integer = 1,
	Float = 2,
	Blob = 4,
	Null = 5,
	Text = 3,
}

Text_Encoding :: enum i32 {
	Utf8 = 1,
	Utf16_Le = 2,
	Utf16_Be = 3,
	Utf16 = 4,
	Any = 5,
	Utf16_Aligned = 8,
	Utf8_Zt = 16,
}

Conflict_Action :: enum i32 {
	Rollback = 1,
	Fail = 3,
	Replace = 5,
}

@(link_prefix = "sqlite3_")
foreign lib {
	sqlite3_version: [0]u8
	libversion :: proc() -> cstring ---
	sourceid :: proc() -> cstring ---
	libversion_number :: proc() -> i32 ---
	compileoption_used :: proc(zOptName: cstring) -> i32 ---
	compileoption_get :: proc(N: i32) -> cstring ---
	threadsafe :: proc() -> i32 ---
	close :: proc(_: ^Sqlite3) -> i32 ---
	close_v2 :: proc(_: ^Sqlite3) -> i32 ---
	exec :: proc(_: ^Sqlite3, sql: cstring, callback: proc "c" (_: rawptr, _: i32, _: ^^u8, _: ^^u8) -> i32, _: rawptr, errmsg: ^^u8) -> i32 ---
	initialize :: proc() -> i32 ---
	shutdown :: proc() -> i32 ---
	os_init :: proc() -> i32 ---
	os_end :: proc() -> i32 ---
	config :: proc(_: i32, #c_vararg _: ..any) -> i32 ---
	db_config :: proc(_: ^Sqlite3, op: i32, #c_vararg _: ..any) -> i32 ---
	extended_result_codes :: proc(_: ^Sqlite3, onoff: i32) -> i32 ---
	last_insert_rowid :: proc(_: ^Sqlite3) -> i64 ---
	set_last_insert_rowid :: proc(_: ^Sqlite3, _: i64) ---
	changes :: proc(_: ^Sqlite3) -> i32 ---
	changes64 :: proc(_: ^Sqlite3) -> i64 ---
	total_changes :: proc(_: ^Sqlite3) -> i32 ---
	total_changes64 :: proc(_: ^Sqlite3) -> i64 ---
	interrupt :: proc(_: ^Sqlite3) ---
	is_interrupted :: proc(_: ^Sqlite3) -> i32 ---
	complete :: proc(sql: cstring) -> i32 ---
	complete16 :: proc(sql: rawptr) -> i32 ---
	busy_handler :: proc(_: ^Sqlite3, _: proc "c" (_: rawptr, _: i32) -> i32, _: rawptr) -> i32 ---
	busy_timeout :: proc(_: ^Sqlite3, ms: i32) -> i32 ---
	setlk_timeout :: proc(_: ^Sqlite3, ms: i32, flags: i32) -> i32 ---
	get_table :: proc(db: ^Sqlite3, zSql: cstring, pazResult: ^^^u8, pnRow: ^i32, pnColumn: ^i32, pzErrmsg: ^^u8) -> i32 ---
	free_table :: proc(result: ^^u8) ---
	mprintf :: proc(_: cstring, #c_vararg _: ..any) -> ^u8 ---
	vmprintf :: proc(_: cstring, _: ^Va_List_Tag) -> ^u8 ---
	snprintf :: proc(_: i32, _: ^u8, _: cstring, #c_vararg _: ..any) -> ^u8 ---
	vsnprintf :: proc(_: i32, _: ^u8, _: cstring, _: ^Va_List_Tag) -> ^u8 ---
	malloc :: proc(_: i32) -> rawptr ---
	malloc64 :: proc(_: u64) -> rawptr ---
	realloc :: proc(_: rawptr, _: i32) -> rawptr ---
	realloc64 :: proc(_: rawptr, _: u64) -> rawptr ---
	free :: proc(_: rawptr) ---
	msize :: proc(_: rawptr) -> u64 ---
	memory_used :: proc() -> i64 ---
	memory_highwater :: proc(resetFlag: i32) -> i64 ---
	randomness :: proc(N: i32, P: rawptr) ---
	set_authorizer :: proc(_: ^Sqlite3, xAuth: proc "c" (_: rawptr, _: i32, _: cstring, _: cstring, _: cstring, _: cstring) -> i32, pUserData: rawptr) -> i32 ---
	trace :: proc(_: ^Sqlite3, xTrace: proc "c" (_: rawptr, _: cstring), _: rawptr) -> rawptr ---
	profile :: proc(_: ^Sqlite3, xProfile: proc "c" (_: rawptr, _: cstring, _: u64), _: rawptr) -> rawptr ---
	trace_v2 :: proc(_: ^Sqlite3, uMask: u32, xCallback: proc "c" (_: u32, _: rawptr, _: rawptr, _: rawptr) -> i32, pCtx: rawptr) -> i32 ---
	progress_handler :: proc(_: ^Sqlite3, _: i32, _: proc "c" (_: rawptr) -> i32, _: rawptr) ---
	open :: proc(filename: cstring, ppDb: ^^Sqlite3) -> i32 ---
	open16 :: proc(filename: rawptr, ppDb: ^^Sqlite3) -> i32 ---
	open_v2 :: proc(filename: cstring, ppDb: ^^Sqlite3, flags: i32, zVfs: cstring) -> i32 ---
	uri_parameter :: proc(z: Filename, zParam: cstring) -> cstring ---
	uri_boolean :: proc(z: Filename, zParam: cstring, bDefault: i32) -> i32 ---
	uri_int64 :: proc(_: Filename, _: cstring, _: i64) -> i64 ---
	uri_key :: proc(z: Filename, N: i32) -> cstring ---
	filename_database :: proc(_: Filename) -> cstring ---
	filename_journal :: proc(_: Filename) -> cstring ---
	filename_wal :: proc(_: Filename) -> cstring ---
	database_file_object :: proc(_: cstring) -> ^File ---
	create_filename :: proc(zDatabase: cstring, zJournal: cstring, zWal: cstring, nParam: i32, azParam: ^cstring) -> Filename ---
	free_filename :: proc(_: Filename) ---
	errcode :: proc(db: ^Sqlite3) -> i32 ---
	extended_errcode :: proc(db: ^Sqlite3) -> i32 ---
	errmsg :: proc(_: ^Sqlite3) -> cstring ---
	errmsg16 :: proc(_: ^Sqlite3) -> rawptr ---
	errstr :: proc(_: i32) -> cstring ---
	error_offset :: proc(db: ^Sqlite3) -> i32 ---
	set_errmsg :: proc(db: ^Sqlite3, errcode: i32, zErrMsg: cstring) -> i32 ---
	limit :: proc(_: ^Sqlite3, id: i32, newVal: i32) -> i32 ---
	prepare :: proc(db: ^Sqlite3, zSql: cstring, nByte: i32, ppStmt: ^^Stmt, pzTail: ^cstring) -> i32 ---
	prepare_v2 :: proc(db: ^Sqlite3, zSql: cstring, nByte: i32, ppStmt: ^^Stmt, pzTail: ^cstring) -> i32 ---
	prepare_v3 :: proc(db: ^Sqlite3, zSql: cstring, nByte: i32, prepFlags: u32, ppStmt: ^^Stmt, pzTail: ^cstring) -> i32 ---
	prepare16 :: proc(db: ^Sqlite3, zSql: rawptr, nByte: i32, ppStmt: ^^Stmt, pzTail: ^rawptr) -> i32 ---
	prepare16_v2 :: proc(db: ^Sqlite3, zSql: rawptr, nByte: i32, ppStmt: ^^Stmt, pzTail: ^rawptr) -> i32 ---
	prepare16_v3 :: proc(db: ^Sqlite3, zSql: rawptr, nByte: i32, prepFlags: u32, ppStmt: ^^Stmt, pzTail: ^rawptr) -> i32 ---
	sql :: proc(pStmt: ^Stmt) -> cstring ---
	expanded_sql :: proc(pStmt: ^Stmt) -> ^u8 ---
	stmt_readonly :: proc(pStmt: ^Stmt) -> i32 ---
	stmt_isexplain :: proc(pStmt: ^Stmt) -> i32 ---
	stmt_explain :: proc(pStmt: ^Stmt, eMode: i32) -> i32 ---
	stmt_busy :: proc(_: ^Stmt) -> i32 ---
	bind_blob :: proc(_: ^Stmt, _: i32, _: rawptr, n: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_blob64 :: proc(_: ^Stmt, _: i32, _: rawptr, _: u64, _: proc "c" (_: rawptr)) -> i32 ---
	bind_double :: proc(_: ^Stmt, _: i32, _: f64) -> i32 ---
	bind_int :: proc(_: ^Stmt, _: i32, _: i32) -> i32 ---
	bind_int64 :: proc(_: ^Stmt, _: i32, _: i64) -> i32 ---
	bind_null :: proc(_: ^Stmt, _: i32) -> i32 ---
	bind_text :: proc(_: ^Stmt, _: i32, _: cstring, _: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_text16 :: proc(_: ^Stmt, _: i32, _: rawptr, _: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_text64 :: proc(_: ^Stmt, _: i32, _: cstring, _: u64, _: proc "c" (_: rawptr), encoding: u8) -> i32 ---
	bind_value :: proc(_: ^Stmt, _: i32, _: ^Value) -> i32 ---
	bind_pointer :: proc(_: ^Stmt, _: i32, _: rawptr, _: cstring, _: proc "c" (_: rawptr)) -> i32 ---
	bind_zeroblob :: proc(_: ^Stmt, _: i32, n: i32) -> i32 ---
	bind_zeroblob64 :: proc(_: ^Stmt, _: i32, _: u64) -> i32 ---
	bind_parameter_count :: proc(_: ^Stmt) -> i32 ---
	bind_parameter_name :: proc(_: ^Stmt, _: i32) -> cstring ---
	bind_parameter_index :: proc(_: ^Stmt, zName: cstring) -> i32 ---
	clear_bindings :: proc(_: ^Stmt) -> i32 ---
	column_count :: proc(pStmt: ^Stmt) -> i32 ---
	column_name :: proc(_: ^Stmt, N: i32) -> cstring ---
	column_name16 :: proc(_: ^Stmt, N: i32) -> rawptr ---
	column_database_name :: proc(_: ^Stmt, _: i32) -> cstring ---
	column_database_name16 :: proc(_: ^Stmt, _: i32) -> rawptr ---
	column_table_name :: proc(_: ^Stmt, _: i32) -> cstring ---
	column_table_name16 :: proc(_: ^Stmt, _: i32) -> rawptr ---
	column_origin_name :: proc(_: ^Stmt, _: i32) -> cstring ---
	column_origin_name16 :: proc(_: ^Stmt, _: i32) -> rawptr ---
	column_decltype :: proc(_: ^Stmt, _: i32) -> cstring ---
	column_decltype16 :: proc(_: ^Stmt, _: i32) -> rawptr ---
	step :: proc(_: ^Stmt) -> i32 ---
	data_count :: proc(pStmt: ^Stmt) -> i32 ---
	column_blob :: proc(_: ^Stmt, iCol: i32) -> rawptr ---
	column_double :: proc(_: ^Stmt, iCol: i32) -> f64 ---
	column_int :: proc(_: ^Stmt, iCol: i32) -> i32 ---
	column_int64 :: proc(_: ^Stmt, iCol: i32) -> i64 ---
	column_text :: proc(_: ^Stmt, iCol: i32) -> ^u8 ---
	column_text16 :: proc(_: ^Stmt, iCol: i32) -> rawptr ---
	column_value :: proc(_: ^Stmt, iCol: i32) -> ^Value ---
	column_bytes :: proc(_: ^Stmt, iCol: i32) -> i32 ---
	column_bytes16 :: proc(_: ^Stmt, iCol: i32) -> i32 ---
	column_type :: proc(_: ^Stmt, iCol: i32) -> i32 ---
	finalize :: proc(pStmt: ^Stmt) -> i32 ---
	reset :: proc(pStmt: ^Stmt) -> i32 ---
	create_function :: proc(db: ^Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: ^Context, _: i32, _: ^^Value), xStep: proc "c" (_: ^Context, _: i32, _: ^^Value), xFinal: proc "c" (_: ^Context)) -> i32 ---
	create_function16 :: proc(db: ^Sqlite3, zFunctionName: rawptr, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: ^Context, _: i32, _: ^^Value), xStep: proc "c" (_: ^Context, _: i32, _: ^^Value), xFinal: proc "c" (_: ^Context)) -> i32 ---
	create_function_v2 :: proc(db: ^Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: ^Context, _: i32, _: ^^Value), xStep: proc "c" (_: ^Context, _: i32, _: ^^Value), xFinal: proc "c" (_: ^Context), xDestroy: proc "c" (_: rawptr)) -> i32 ---
	create_window_function :: proc(db: ^Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xStep: proc "c" (_: ^Context, _: i32, _: ^^Value), xFinal: proc "c" (_: ^Context), xValue: proc "c" (_: ^Context), xInverse: proc "c" (_: ^Context, _: i32, _: ^^Value), xDestroy: proc "c" (_: rawptr)) -> i32 ---
	aggregate_count :: proc(_: ^Context) -> i32 ---
	expired :: proc(_: ^Stmt) -> i32 ---
	transfer_bindings :: proc(_: ^Stmt, _: ^Stmt) -> i32 ---
	global_recover :: proc() -> i32 ---
	thread_cleanup :: proc() ---
	memory_alarm :: proc(_: proc "c" (_: rawptr, _: i64, _: i32), _: rawptr, _: i64) -> i32 ---
	value_blob :: proc(_: ^Value) -> rawptr ---
	value_double :: proc(_: ^Value) -> f64 ---
	value_int :: proc(_: ^Value) -> i32 ---
	value_int64 :: proc(_: ^Value) -> i64 ---
	value_pointer :: proc(_: ^Value, _: cstring) -> rawptr ---
	value_text :: proc(_: ^Value) -> ^u8 ---
	value_text16 :: proc(_: ^Value) -> rawptr ---
	value_text16le :: proc(_: ^Value) -> rawptr ---
	value_text16be :: proc(_: ^Value) -> rawptr ---
	value_bytes :: proc(_: ^Value) -> i32 ---
	value_bytes16 :: proc(_: ^Value) -> i32 ---
	value_type :: proc(_: ^Value) -> i32 ---
	value_numeric_type :: proc(_: ^Value) -> i32 ---
	value_nochange :: proc(_: ^Value) -> i32 ---
	value_frombind :: proc(_: ^Value) -> i32 ---
	value_encoding :: proc(_: ^Value) -> i32 ---
	value_subtype :: proc(_: ^Value) -> u32 ---
	value_dup :: proc(_: ^Value) -> ^Value ---
	value_free :: proc(_: ^Value) ---
	aggregate_context :: proc(_: ^Context, nBytes: i32) -> rawptr ---
	user_data :: proc(_: ^Context) -> rawptr ---
	context_db_handle :: proc(_: ^Context) -> ^Sqlite3 ---
	get_auxdata :: proc(_: ^Context, N: i32) -> rawptr ---
	set_auxdata :: proc(_: ^Context, N: i32, _: rawptr, _: proc "c" (_: rawptr)) ---
	get_clientdata :: proc(_: ^Sqlite3, _: cstring) -> rawptr ---
	set_clientdata :: proc(_: ^Sqlite3, _: cstring, _: rawptr, _: proc "c" (_: rawptr)) -> i32 ---
	result_blob :: proc(_: ^Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_blob64 :: proc(_: ^Context, _: rawptr, _: u64, _: proc "c" (_: rawptr)) ---
	result_double :: proc(_: ^Context, _: f64) ---
	result_error :: proc(_: ^Context, _: cstring, _: i32) ---
	result_error16 :: proc(_: ^Context, _: rawptr, _: i32) ---
	result_error_toobig :: proc(_: ^Context) ---
	result_error_nomem :: proc(_: ^Context) ---
	result_error_code :: proc(_: ^Context, _: i32) ---
	result_int :: proc(_: ^Context, _: i32) ---
	result_int64 :: proc(_: ^Context, _: i64) ---
	result_null :: proc(_: ^Context) ---
	result_text :: proc(_: ^Context, _: cstring, _: i32, _: proc "c" (_: rawptr)) ---
	result_text64 :: proc(_: ^Context, z: cstring, n: u64, _: proc "c" (_: rawptr), encoding: u8) ---
	result_text16 :: proc(_: ^Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_text16le :: proc(_: ^Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_text16be :: proc(_: ^Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_value :: proc(_: ^Context, _: ^Value) ---
	result_pointer :: proc(_: ^Context, _: rawptr, _: cstring, _: proc "c" (_: rawptr)) ---
	result_zeroblob :: proc(_: ^Context, n: i32) ---
	result_zeroblob64 :: proc(_: ^Context, n: u64) -> i32 ---
	result_subtype :: proc(_: ^Context, _: u32) ---
	create_collation :: proc(_: ^Sqlite3, zName: cstring, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32) -> i32 ---
	create_collation_v2 :: proc(_: ^Sqlite3, zName: cstring, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32, xDestroy: proc "c" (_: rawptr)) -> i32 ---
	create_collation16 :: proc(_: ^Sqlite3, zName: rawptr, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32) -> i32 ---
	collation_needed :: proc(_: ^Sqlite3, _: rawptr, _: proc "c" (_: rawptr, _: ^Sqlite3, _: i32, _: cstring)) -> i32 ---
	collation_needed16 :: proc(_: ^Sqlite3, _: rawptr, _: proc "c" (_: rawptr, _: ^Sqlite3, _: i32, _: rawptr)) -> i32 ---
	sleep :: proc(_: i32) -> i32 ---
	sqlite3_temp_directory: ^u8
	sqlite3_data_directory: ^u8
	win32_set_directory :: proc(type: u64, zValue: rawptr) -> i32 ---
	win32_set_directory8 :: proc(type: u64, zValue: cstring) -> i32 ---
	win32_set_directory16 :: proc(type: u64, zValue: rawptr) -> i32 ---
	get_autocommit :: proc(_: ^Sqlite3) -> i32 ---
	db_handle :: proc(_: ^Stmt) -> ^Sqlite3 ---
	db_name :: proc(db: ^Sqlite3, N: i32) -> cstring ---
	db_filename :: proc(db: ^Sqlite3, zDbName: cstring) -> Filename ---
	db_readonly :: proc(db: ^Sqlite3, zDbName: cstring) -> i32 ---
	txn_state :: proc(_: ^Sqlite3, zSchema: cstring) -> i32 ---
	next_stmt :: proc(pDb: ^Sqlite3, pStmt: ^Stmt) -> ^Stmt ---
	commit_hook :: proc(_: ^Sqlite3, _: proc "c" (_: rawptr) -> i32, _: rawptr) -> rawptr ---
	rollback_hook :: proc(_: ^Sqlite3, _: proc "c" (_: rawptr), _: rawptr) -> rawptr ---
	autovacuum_pages :: proc(db: ^Sqlite3, _: proc "c" (_: rawptr, _: cstring, _: u32, _: u32, _: u32) -> u32, _: rawptr, _: proc "c" (_: rawptr)) -> i32 ---
	update_hook :: proc(_: ^Sqlite3, _: proc "c" (_: rawptr, _: i32, _: cstring, _: cstring, _: i64), _: rawptr) -> rawptr ---
	enable_shared_cache :: proc(_: i32) -> i32 ---
	release_memory :: proc(_: i32) -> i32 ---
	db_release_memory :: proc(_: ^Sqlite3) -> i32 ---
	soft_heap_limit64 :: proc(N: i64) -> i64 ---
	hard_heap_limit64 :: proc(N: i64) -> i64 ---
	soft_heap_limit :: proc(N: i32) ---
	table_column_metadata :: proc(db: ^Sqlite3, zDbName: cstring, zTableName: cstring, zColumnName: cstring, pzDataType: ^cstring, pzCollSeq: ^cstring, pNotNull: ^i32, pPrimaryKey: ^i32, pAutoinc: ^i32) -> i32 ---
	load_extension :: proc(db: ^Sqlite3, zFile: cstring, zProc: cstring, pzErrMsg: ^^u8) -> i32 ---
	enable_load_extension :: proc(db: ^Sqlite3, onoff: i32) -> i32 ---
	auto_extension :: proc(xEntryPoint: proc "c" ()) -> i32 ---
	cancel_auto_extension :: proc(xEntryPoint: proc "c" ()) -> i32 ---
	reset_auto_extension :: proc() ---
	create_module :: proc(db: ^Sqlite3, zName: cstring, p: ^Module, pClientData: rawptr) -> i32 ---
	create_module_v2 :: proc(db: ^Sqlite3, zName: cstring, p: ^Module, pClientData: rawptr, xDestroy: proc "c" (_: rawptr)) -> i32 ---
	drop_modules :: proc(db: ^Sqlite3, azKeep: ^cstring) -> i32 ---
	declare_vtab :: proc(_: ^Sqlite3, zSQL: cstring) -> i32 ---
	overload_function :: proc(_: ^Sqlite3, zFuncName: cstring, nArg: i32) -> i32 ---
	blob_open :: proc(_: ^Sqlite3, zDb: cstring, zTable: cstring, zColumn: cstring, iRow: i64, flags: i32, ppBlob: ^^Blob) -> i32 ---
	blob_reopen :: proc(_: ^Blob, _: i64) -> i32 ---
	blob_close :: proc(_: ^Blob) -> i32 ---
	blob_bytes :: proc(_: ^Blob) -> i32 ---
	blob_read :: proc(_: ^Blob, Z: rawptr, N: i32, iOffset: i32) -> i32 ---
	blob_write :: proc(_: ^Blob, z: rawptr, n: i32, iOffset: i32) -> i32 ---
	vfs_find :: proc(zVfsName: cstring) -> ^Vfs ---
	vfs_register :: proc(_: ^Vfs, makeDflt: i32) -> i32 ---
	vfs_unregister :: proc(_: ^Vfs) -> i32 ---
	mutex_alloc :: proc(_: i32) -> ^Mutex ---
	mutex_free :: proc(_: ^Mutex) ---
	mutex_enter :: proc(_: ^Mutex) ---
	mutex_try :: proc(_: ^Mutex) -> i32 ---
	mutex_leave :: proc(_: ^Mutex) ---
	mutex_held :: proc(_: ^Mutex) -> i32 ---
	mutex_notheld :: proc(_: ^Mutex) -> i32 ---
	db_mutex :: proc(_: ^Sqlite3) -> ^Mutex ---
	file_control :: proc(_: ^Sqlite3, zDbName: cstring, op: i32, _: rawptr) -> i32 ---
	test_control :: proc(op: i32, #c_vararg _: ..any) -> i32 ---
	keyword_count :: proc() -> i32 ---
	keyword_name :: proc(_: i32, _: ^cstring, _: ^i32) -> i32 ---
	keyword_check :: proc(_: cstring, _: i32) -> i32 ---
	str_new :: proc(_: ^Sqlite3) -> ^Str ---
	str_finish :: proc(_: ^Str) -> ^u8 ---
	str_free :: proc(_: ^Str) ---
	str_appendf :: proc(_: ^Str, zFormat: cstring, #c_vararg _: ..any) ---
	str_vappendf :: proc(_: ^Str, zFormat: cstring, _: ^Va_List_Tag) ---
	str_append :: proc(_: ^Str, zIn: cstring, N: i32) ---
	str_appendall :: proc(_: ^Str, zIn: cstring) ---
	str_appendchar :: proc(_: ^Str, N: i32, C: u8) ---
	str_reset :: proc(_: ^Str) ---
	str_truncate :: proc(_: ^Str, N: i32) ---
	str_errcode :: proc(_: ^Str) -> i32 ---
	str_length :: proc(_: ^Str) -> i32 ---
	str_value :: proc(_: ^Str) -> ^u8 ---
	status :: proc(op: i32, pCurrent: ^i32, pHighwater: ^i32, resetFlag: i32) -> i32 ---
	status64 :: proc(op: i32, pCurrent: ^i64, pHighwater: ^i64, resetFlag: i32) -> i32 ---
	db_status :: proc(_: ^Sqlite3, op: i32, pCur: ^i32, pHiwtr: ^i32, resetFlg: i32) -> i32 ---
	db_status64 :: proc(_: ^Sqlite3, _: i32, _: ^i64, _: ^i64, _: i32) -> i32 ---
	stmt_status :: proc(_: ^Stmt, op: i32, resetFlg: i32) -> i32 ---
	backup_init :: proc(pDest: ^Sqlite3, zDestName: cstring, pSource: ^Sqlite3, zSourceName: cstring) -> ^Backup ---
	backup_step :: proc(p: ^Backup, nPage: i32) -> i32 ---
	backup_finish :: proc(p: ^Backup) -> i32 ---
	backup_remaining :: proc(p: ^Backup) -> i32 ---
	backup_pagecount :: proc(p: ^Backup) -> i32 ---
	unlock_notify :: proc(pBlocked: ^Sqlite3, xNotify: proc "c" (_: ^rawptr, _: i32), pNotifyArg: rawptr) -> i32 ---
	stricmp :: proc(_: cstring, _: cstring) -> i32 ---
	strnicmp :: proc(_: cstring, _: cstring, _: i32) -> i32 ---
	strglob :: proc(zGlob: cstring, zStr: cstring) -> i32 ---
	strlike :: proc(zGlob: cstring, zStr: cstring, cEsc: u32) -> i32 ---
	log :: proc(iErrCode: i32, zFormat: cstring, #c_vararg _: ..any) ---
	wal_hook :: proc(_: ^Sqlite3, _: proc "c" (_: rawptr, _: ^Sqlite3, _: cstring, _: i32) -> i32, _: rawptr) -> rawptr ---
	wal_autocheckpoint :: proc(db: ^Sqlite3, N: i32) -> i32 ---
	wal_checkpoint :: proc(db: ^Sqlite3, zDb: cstring) -> i32 ---
	wal_checkpoint_v2 :: proc(db: ^Sqlite3, zDb: cstring, eMode: i32, pnLog: ^i32, pnCkpt: ^i32) -> i32 ---
	vtab_config :: proc(_: ^Sqlite3, op: i32, #c_vararg _: ..any) -> i32 ---
	vtab_on_conflict :: proc(_: ^Sqlite3) -> i32 ---
	vtab_nochange :: proc(_: ^Context) -> i32 ---
	vtab_collation :: proc(_: ^Index_Info, _: i32) -> cstring ---
	vtab_distinct :: proc(_: ^Index_Info) -> i32 ---
	vtab_in :: proc(_: ^Index_Info, iCons: i32, bHandle: i32) -> i32 ---
	vtab_in_first :: proc(pVal: ^Value, ppOut: ^^Value) -> i32 ---
	vtab_in_next :: proc(pVal: ^Value, ppOut: ^^Value) -> i32 ---
	vtab_rhs_value :: proc(_: ^Index_Info, _: i32, ppVal: ^^Value) -> i32 ---
	stmt_scanstatus :: proc(pStmt: ^Stmt, idx: i32, iScanStatusOp: i32, pOut: rawptr) -> i32 ---
	stmt_scanstatus_v2 :: proc(pStmt: ^Stmt, idx: i32, iScanStatusOp: i32, flags: i32, pOut: rawptr) -> i32 ---
	stmt_scanstatus_reset :: proc(_: ^Stmt) ---
	db_cacheflush :: proc(_: ^Sqlite3) -> i32 ---
	system_errno :: proc(_: ^Sqlite3) -> i32 ---
	snapshot_get :: proc(db: ^Sqlite3, zSchema: cstring, ppSnapshot: ^^Snapshot) -> i32 ---
	snapshot_open :: proc(db: ^Sqlite3, zSchema: cstring, pSnapshot: ^Snapshot) -> i32 ---
	snapshot_free :: proc(_: ^Snapshot) ---
	snapshot_cmp :: proc(p1: ^Snapshot, p2: ^Snapshot) -> i32 ---
	snapshot_recover :: proc(db: ^Sqlite3, zDb: cstring) -> i32 ---
	serialize :: proc(db: ^Sqlite3, zSchema: cstring, piSize: ^i64, mFlags: u32) -> ^u8 ---
	deserialize :: proc(db: ^Sqlite3, zSchema: cstring, pData: ^u8, szDb: i64, szBuf: i64, mFlags: u32) -> i32 ---
	carray_bind_v2 :: proc(pStmt: ^Stmt, i: i32, aData: rawptr, nData: i32, mFlags: i32, xDel: proc "c" (_: rawptr), pDel: rawptr) -> i32 ---
	carray_bind :: proc(pStmt: ^Stmt, i: i32, aData: rawptr, nData: i32, mFlags: i32, xDel: proc "c" (_: rawptr)) -> i32 ---
	rtree_geometry_callback :: proc(db: ^Sqlite3, zGeom: cstring, xGeom: proc "c" (_: ^Rtree_Geometry, _: i32, _: ^Rtree_Dbl, _: ^i32) -> i32, pContext: rawptr) -> i32 ---
	rtree_query_callback :: proc(db: ^Sqlite3, zQueryFunc: cstring, xQueryFunc: proc "c" (_: ^Rtree_Query_Info) -> i32, pContext: rawptr, xDestructor: proc "c" (_: rawptr)) -> i32 ---
}
