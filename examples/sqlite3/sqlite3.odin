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
Sqlite3 :: distinct rawptr

Callback :: proc "c" (_: rawptr, _: i32, _: ^^u8, _: ^^u8) -> i32

File :: struct {
	p_methods: ^Io_Methods,
}

Io_Methods :: struct {
	i_version:                i32,
	x_close:                  proc "c" (_: ^File) -> i32,
	x_read:                   proc "c" (_: ^File, _: rawptr, _: i32, _: i64) -> i32,
	x_write:                  proc "c" (_: ^File, _: rawptr, _: i32, _: i64) -> i32,
	x_truncate:               proc "c" (_: ^File, _: i64) -> i32,
	x_sync:                   proc "c" (_: ^File, _: i32) -> i32,
	x_file_size:              proc "c" (_: ^File, _: ^i64) -> i32,
	x_lock:                   proc "c" (_: ^File, _: i32) -> i32,
	x_unlock:                 proc "c" (_: ^File, _: i32) -> i32,
	x_check_reserved_lock:    proc "c" (_: ^File, _: ^i32) -> i32,
	x_file_control:           proc "c" (_: ^File, _: i32, _: rawptr) -> i32,
	x_sector_size:            proc "c" (_: ^File) -> i32,
	x_device_characteristics: proc "c" (_: ^File) -> i32,
	x_shm_map:                proc "c" (_: ^File, _: i32, _: i32, _: i32, _: ^rawptr) -> i32,
	x_shm_lock:               proc "c" (_: ^File, _: i32, _: i32, _: i32) -> i32,
	x_shm_barrier:            proc "c" (_: ^File),
	x_shm_unmap:              proc "c" (_: ^File, _: i32) -> i32,
	x_fetch:                  proc "c" (_: ^File, _: i64, _: i32, _: ^rawptr) -> i32,
	x_unfetch:                proc "c" (_: ^File, _: i64, _: rawptr) -> i32,
}

Mutex :: distinct rawptr

Api_Routines :: distinct rawptr

Filename :: cstring

Vfs :: struct {
	i_version:            i32,
	sz_os_file:           i32,
	mx_pathname:          i32,
	p_next:               ^Vfs,
	z_name:               cstring,
	p_app_data:           rawptr,
	x_open:               proc "c" (_: ^Vfs, _: Filename, _: ^File, _: i32, _: ^i32) -> i32,
	x_delete:             proc "c" (_: ^Vfs, _: cstring, _: i32) -> i32,
	x_access:             proc "c" (_: ^Vfs, _: cstring, _: i32, _: ^i32) -> i32,
	x_full_pathname:      proc "c" (_: ^Vfs, _: cstring, _: i32, _: ^u8) -> i32,
	x_dl_open:            proc "c" (_: ^Vfs, _: cstring) -> rawptr,
	x_dl_error:           proc "c" (_: ^Vfs, _: i32, _: ^u8),
	x_dl_sym:             proc "c" (_: ^Vfs, _: rawptr, _: cstring) -> proc "c" (),
	x_dl_close:           proc "c" (_: ^Vfs, _: rawptr),
	x_randomness:         proc "c" (_: ^Vfs, _: i32, _: ^u8) -> i32,
	x_sleep:              proc "c" (_: ^Vfs, _: i32) -> i32,
	x_current_time:       proc "c" (_: ^Vfs, _: ^f64) -> i32,
	x_get_last_error:     proc "c" (_: ^Vfs, _: i32, _: ^u8) -> i32,
	x_current_time_int64: proc "c" (_: ^Vfs, _: ^i64) -> i32,
	x_set_system_call:    proc "c" (_: ^Vfs, _: cstring, _: Syscall_Ptr) -> i32,
	x_get_system_call:    proc "c" (_: ^Vfs, _: cstring) -> Syscall_Ptr,
	x_next_system_call:   proc "c" (_: ^Vfs, _: cstring) -> cstring,
}

Syscall_Ptr :: proc "c" ()

Mem_Methods :: struct {
	x_malloc:   proc "c" (_: i32) -> rawptr,
	x_free:     proc "c" (_: rawptr),
	x_realloc:  proc "c" (_: rawptr, _: i32) -> rawptr,
	x_size:     proc "c" (_: rawptr) -> i32,
	x_roundup:  proc "c" (_: i32) -> i32,
	x_init:     proc "c" (_: rawptr) -> i32,
	x_shutdown: proc "c" (_: rawptr),
	p_app_data: rawptr,
}

Va_List_Tag :: struct {
	gp_offset:         u32,
	fp_offset:         u32,
	overflow_arg_area: rawptr,
	reg_save_area:     rawptr,
}

Stmt :: distinct rawptr

Value :: distinct rawptr

Context :: distinct rawptr

Destructor_Type :: proc "c" (_: rawptr)

Vtab :: struct {
	p_module:  ^Module,
	n_ref:     i32,
	z_err_msg: ^u8,
}

Index_Info :: struct {
	n_constraint:         i32,
	a_constraint:         ^Index_Constraint,
	n_order_by:           i32,
	a_order_by:           ^Index_Orderby,
	a_constraint_usage:   ^Index_Constraint_Usage,
	idx_num:              i32,
	idx_str:              ^u8,
	need_to_free_idx_str: i32,
	order_by_consumed:    i32,
	estimated_cost:       f64,
	estimated_rows:       i64,
	idx_flags:            i32,
	col_used:             u64,
}

Vtab_Cursor :: struct {
	p_vtab: ^Vtab,
}

Module :: struct {
	i_version:       i32,
	x_create:        proc "c" (_: Sqlite3, _: rawptr, _: i32, _: ^cstring, _: ^^Vtab, _: ^^u8) -> i32,
	x_connect:       proc "c" (_: Sqlite3, _: rawptr, _: i32, _: ^cstring, _: ^^Vtab, _: ^^u8) -> i32,
	x_best_index:    proc "c" (_: ^Vtab, _: ^Index_Info) -> i32,
	x_disconnect:    proc "c" (_: ^Vtab) -> i32,
	x_destroy:       proc "c" (_: ^Vtab) -> i32,
	x_open:          proc "c" (_: ^Vtab, _: ^^Vtab_Cursor) -> i32,
	x_close:         proc "c" (_: ^Vtab_Cursor) -> i32,
	x_filter:        proc "c" (_: ^Vtab_Cursor, _: i32, _: cstring, _: i32, _: ^Value) -> i32,
	x_next:          proc "c" (_: ^Vtab_Cursor) -> i32,
	x_eof:           proc "c" (_: ^Vtab_Cursor) -> i32,
	x_column:        proc "c" (_: ^Vtab_Cursor, _: Context, _: i32) -> i32,
	x_rowid:         proc "c" (_: ^Vtab_Cursor, _: ^i64) -> i32,
	x_update:        proc "c" (_: ^Vtab, _: i32, _: ^Value, _: ^i64) -> i32,
	x_begin:         proc "c" (_: ^Vtab) -> i32,
	x_sync:          proc "c" (_: ^Vtab) -> i32,
	x_commit:        proc "c" (_: ^Vtab) -> i32,
	x_rollback:      proc "c" (_: ^Vtab) -> i32,
	x_find_function: proc "c" (_: ^Vtab, _: i32, _: cstring, _: ^proc "c" (_: Context, _: i32, _: ^Value), _: ^rawptr) -> i32,
	x_rename:        proc "c" (_: ^Vtab, _: cstring) -> i32,
	x_savepoint:     proc "c" (_: ^Vtab, _: i32) -> i32,
	x_release:       proc "c" (_: ^Vtab, _: i32) -> i32,
	x_rollback_to:   proc "c" (_: ^Vtab, _: i32) -> i32,
	x_shadow_name:   proc "c" (_: cstring) -> i32,
	x_integrity:     proc "c" (_: ^Vtab, _: cstring, _: cstring, _: i32, _: ^^u8) -> i32,
}

Index_Constraint :: struct {
	i_column:      i32,
	op:            u8,
	usable:        u8,
	i_term_offset: i32,
}

Index_Orderby :: struct {
	i_column: i32,
	desc:     u8,
}

Index_Constraint_Usage :: struct {
	argv_index: i32,
	omit:       u8,
}

Blob :: distinct rawptr

Mutex_Methods :: struct {
	x_mutex_init:    proc "c" () -> i32,
	x_mutex_end:     proc "c" () -> i32,
	x_mutex_alloc:   proc "c" (_: i32) -> Mutex,
	x_mutex_free:    proc "c" (_: Mutex),
	x_mutex_enter:   proc "c" (_: Mutex),
	x_mutex_try:     proc "c" (_: Mutex) -> i32,
	x_mutex_leave:   proc "c" (_: Mutex),
	x_mutex_held:    proc "c" (_: Mutex) -> i32,
	x_mutex_notheld: proc "c" (_: Mutex) -> i32,
}

Str :: distinct rawptr

Pcache :: distinct rawptr

Pcache_Page :: struct {
	p_buf:   rawptr,
	p_extra: rawptr,
}

Pcache_Methods2 :: struct {
	i_version:   i32,
	p_arg:       rawptr,
	x_init:      proc "c" (_: rawptr) -> i32,
	x_shutdown:  proc "c" (_: rawptr),
	x_create:    proc "c" (_: i32, _: i32, _: i32) -> Pcache,
	x_cachesize: proc "c" (_: Pcache, _: i32),
	x_pagecount: proc "c" (_: Pcache) -> i32,
	x_fetch:     proc "c" (_: Pcache, _: u32, _: i32) -> ^Pcache_Page,
	x_unpin:     proc "c" (_: Pcache, _: ^Pcache_Page, _: i32),
	x_rekey:     proc "c" (_: Pcache, _: ^Pcache_Page, _: u32, _: u32),
	x_truncate:  proc "c" (_: Pcache, _: u32),
	x_destroy:   proc "c" (_: Pcache),
	x_shrink:    proc "c" (_: Pcache),
}

Pcache_Methods :: struct {
	p_arg:       rawptr,
	x_init:      proc "c" (_: rawptr) -> i32,
	x_shutdown:  proc "c" (_: rawptr),
	x_create:    proc "c" (_: i32, _: i32) -> Pcache,
	x_cachesize: proc "c" (_: Pcache, _: i32),
	x_pagecount: proc "c" (_: Pcache) -> i32,
	x_fetch:     proc "c" (_: Pcache, _: u32, _: i32) -> rawptr,
	x_unpin:     proc "c" (_: Pcache, _: rawptr, _: i32),
	x_rekey:     proc "c" (_: Pcache, _: rawptr, _: u32, _: u32),
	x_truncate:  proc "c" (_: Pcache, _: u32),
	x_destroy:   proc "c" (_: Pcache),
}

Backup :: distinct rawptr

Snapshot :: struct {
	hidden: [48]u8,
}

Rtree_Geometry :: struct {
	p_context:  rawptr,
	n_param:    i32,
	a_param:    ^Rtree_Dbl,
	p_user:     rawptr,
	x_del_user: proc "c" (_: rawptr),
}

Rtree_Query_Info :: struct {
	p_context:       rawptr,
	n_param:         i32,
	a_param:         ^Rtree_Dbl,
	p_user:          rawptr,
	x_del_user:      proc "c" (_: rawptr),
	a_coord:         ^Rtree_Dbl,
	an_queue:        ^u32,
	n_coord:         i32,
	i_level:         i32,
	mx_level:        i32,
	i_rowid:         i64,
	r_parent_score:  Rtree_Dbl,
	e_parent_within: i32,
	e_within:        i32,
	r_score:         Rtree_Dbl,
	ap_sql_param:    ^Value,
}

Rtree_Dbl :: f64

Fts5_Extension_Api :: struct {
	i_version:             i32,
	x_user_data:           proc "c" (_: Fts5_Context) -> rawptr,
	x_column_count:        proc "c" (_: Fts5_Context) -> i32,
	x_row_count:           proc "c" (_: Fts5_Context, _: ^i64) -> i32,
	x_column_total_size:   proc "c" (_: Fts5_Context, _: i32, _: ^i64) -> i32,
	x_tokenize:            proc "c" (
		_: Fts5_Context,
		_: cstring,
		_: i32,
		_: rawptr,
		_: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32,
	) -> i32,
	x_phrase_count:        proc "c" (_: Fts5_Context) -> i32,
	x_phrase_size:         proc "c" (_: Fts5_Context, _: i32) -> i32,
	x_inst_count:          proc "c" (_: Fts5_Context, _: ^i32) -> i32,
	x_inst:                proc "c" (_: Fts5_Context, _: i32, _: ^i32, _: ^i32, _: ^i32) -> i32,
	x_rowid:               proc "c" (_: Fts5_Context) -> i64,
	x_column_text:         proc "c" (_: Fts5_Context, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_column_size:         proc "c" (_: Fts5_Context, _: i32, _: ^i32) -> i32,
	x_query_phrase:        proc "c" (_: Fts5_Context, _: i32, _: rawptr, _: proc "c" (_: ^Fts5_Extension_Api, _: Fts5_Context, _: rawptr) -> i32) -> i32,
	x_set_auxdata:         proc "c" (_: Fts5_Context, _: rawptr, _: proc "c" (_: rawptr)) -> i32,
	x_get_auxdata:         proc "c" (_: Fts5_Context, _: i32) -> rawptr,
	x_phrase_first:        proc "c" (_: Fts5_Context, _: i32, _: ^Fts5_Phrase_Iter, _: ^i32, _: ^i32) -> i32,
	x_phrase_next:         proc "c" (_: Fts5_Context, _: ^Fts5_Phrase_Iter, _: ^i32, _: ^i32),
	x_phrase_first_column: proc "c" (_: Fts5_Context, _: i32, _: ^Fts5_Phrase_Iter, _: ^i32) -> i32,
	x_phrase_next_column:  proc "c" (_: Fts5_Context, _: ^Fts5_Phrase_Iter, _: ^i32),
	x_query_token:         proc "c" (_: Fts5_Context, _: i32, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_inst_token:          proc "c" (_: Fts5_Context, _: i32, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_column_locale:       proc "c" (_: Fts5_Context, _: i32, _: ^cstring, _: ^i32) -> i32,
	x_tokenize_v2:         proc "c" (
		_: Fts5_Context,
		_: cstring,
		_: i32,
		_: cstring,
		_: i32,
		_: rawptr,
		_: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32,
	) -> i32,
}

Fts5_Context :: distinct rawptr

Fts5_Phrase_Iter :: struct {
	a: ^u8,
	b: ^u8,
}

Fts5_Extension_Function :: proc "c" (_: ^Fts5_Extension_Api, _: Fts5_Context, _: Context, _: i32, _: ^Value)

Fts5_Tokenizer :: distinct rawptr

Fts5_Tokenizer_V2 :: struct {
	i_version:  i32,
	x_create:   proc "c" (_: rawptr, _: ^cstring, _: i32, _: ^Fts5_Tokenizer) -> i32,
	x_delete:   proc "c" (_: Fts5_Tokenizer),
	x_tokenize: proc "c" (
		_: Fts5_Tokenizer,
		_: rawptr,
		_: i32,
		_: cstring,
		_: i32,
		_: cstring,
		_: i32,
		_: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32,
	) -> i32,
}

Fts5_Tokenizer_Methods :: struct {
	x_create:   proc "c" (_: rawptr, _: ^cstring, _: i32, _: ^Fts5_Tokenizer) -> i32,
	x_delete:   proc "c" (_: Fts5_Tokenizer),
	x_tokenize: proc "c" (
		_: Fts5_Tokenizer,
		_: rawptr,
		_: i32,
		_: cstring,
		_: i32,
		_: proc "c" (_: rawptr, _: i32, _: cstring, _: i32, _: i32, _: i32) -> i32,
	) -> i32,
}

Fts5_Api :: struct {
	i_version:             i32,
	x_create_tokenizer:    proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: ^Fts5_Tokenizer_Methods, _: proc "c" (_: rawptr)) -> i32,
	x_find_tokenizer:      proc "c" (_: ^Fts5_Api, _: cstring, _: ^rawptr, _: ^Fts5_Tokenizer_Methods) -> i32,
	x_create_function:     proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: Fts5_Extension_Function, _: proc "c" (_: rawptr)) -> i32,
	x_create_tokenizer_v2: proc "c" (_: ^Fts5_Api, _: cstring, _: rawptr, _: ^Fts5_Tokenizer_V2, _: proc "c" (_: rawptr)) -> i32,
	x_find_tokenizer_v2:   proc "c" (_: ^Fts5_Api, _: cstring, _: ^rawptr, _: ^^Fts5_Tokenizer_V2) -> i32,
}

Result_Code :: enum i32 {
	Ok,
	Error,
	Internal,
	Perm,
	Abort,
	Busy,
	Locked,
	Nomem,
	Readonly,
	Interrupt,
	Ioerr,
	Corrupt,
	Notfound,
	Full,
	Cantopen,
	Protocol,
	Empty,
	Schema,
	Toobig,
	Constraint,
	Mismatch,
	Misuse,
	Nolfs,
	Auth,
	Format,
	Range,
	Notadb,
	Notice,
	Warning,
	Row = 100,
	Done,
}

Open_Flag :: enum i32 {
	Readonly = 1,
	Readwrite,
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
	Atomic512,
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
	None,
	Shared,
	Reserved,
	Pending,
	Exclusive,
}

Sync_Flag :: enum i32 {
	Normal = 2,
	Full,
	Dataonly = 16,
}

Fcntl_Opcode :: enum i32 {
	Lockstate = 1,
	Get_Lockproxyfile,
	Set_Lockproxyfile,
	Last_Errno,
	Size_Hint,
	Chunk_Size,
	File_Pointer,
	Sync_Omitted,
	Win32_Av_Retry,
	Persist_Wal,
	Overwrite,
	Vfsname,
	Powersafe_Overwrite,
	Pragma,
	Busyhandler,
	Tempfilename,
	Mmap_Size = 18,
	Trace,
	Has_Moved,
	Sync,
	Commit_Phasetwo,
	Win32_Set_Handle,
	Wal_Block,
	Zipvfs,
	Rbu,
	Vfs_Pointer,
	Journal_Pointer,
	Win32_Get_Handle,
	Pdb,
	Begin_Atomic_Write,
	Commit_Atomic_Write,
	Rollback_Atomic_Write,
	Lock_Timeout,
	Data_Version,
	Size_Limit,
	Ckpt_Done,
	Reserve_Bytes,
	Ckpt_Start,
	External_Reader,
	Cksm_File,
	Reset_Cache,
	Null_Io,
	Block_On_Connect,
	Filestat,
}

Access_Mode :: enum i32 {
	Exists,
	Readwrite,
	Read,
}

Shm_Flag :: enum i32 {
	Unlock = 1,
	Lock,
	Shared = 4,
	Exclusive = 8,
}

Checkpoint_Mode :: enum i32 {
	Passive,
	Full,
	Restart,
	Truncate,
}

Config_Opcode :: enum i32 {
	Singlethread = 1,
	Multithread,
	Serialized,
	Malloc,
	Getmalloc,
	Scratch,
	Pagecache,
	Heap,
	Memstatus,
	Mutex,
	Getmutex,
	Lookaside = 13,
	Pcache,
	Getpcache,
	Log,
	Uri,
	Pcache2,
	Getpcache2,
	Covering_Index_Scan,
	Sqllog,
	Mmap_Size,
	Win32_Heapsize,
	Pcache_Hdrsz,
	Pmasz,
	Stmtjrnl_Spill,
	Small_Malloc,
	Sorterref_Size,
	Memdb_Maxsize,
	Rowid_In_View,
}

Db_Config :: enum i32 {
	Maindbname = 1000,
	Lookaside,
	Enable_Fkey,
	Enable_Trigger,
	Enable_Fts3_Tokenizer,
	Enable_Load_Extension,
	No_Ckpt_On_Close,
	Enable_Qpsg,
	Trigger_Eqp,
	Reset_Database,
	Defensive,
	Writable_Schema,
	Legacy_Alter_Table,
	Dqs_Dml,
	Dqs_Ddl,
	Enable_View,
	Legacy_File_Format,
	Trusted_Schema,
	Stmt_Scanstatus,
	Reverse_Scanorder,
	Enable_Attach_Create,
	Enable_Attach_Write,
	Enable_Comments,
	Fp_Digits,
	Max = 1023,
}

Limit :: enum i32 {
	Length,
	Sql_Length,
	Column,
	Expr_Depth,
	Compound_Select,
	Vdbe_Op,
	Function_Arg,
	Attached,
	Like_Pattern_Length,
	Variable_Number,
	Trigger_Depth,
	Worker_Threads,
	Parser_Depth,
}

Status :: enum i32 {
	Memory_Used,
	Pagecache_Used,
	Pagecache_Overflow,
	Scratch_Used,
	Scratch_Overflow,
	Malloc_Size,
	Parser_Stack,
	Pagecache_Size,
	Scratch_Size,
	Malloc_Count,
}

Db_Status :: enum i32 {
	Lookaside_Used,
	Cache_Used,
	Schema_Used,
	Stmt_Used,
	Lookaside_Hit,
	Lookaside_Miss_Size,
	Lookaside_Miss_Full,
	Cache_Hit,
	Cache_Miss,
	Cache_Write,
	Deferred_Fks,
	Cache_Used_Shared,
	Cache_Spill,
	Tempbuf_Spill,
	Max = 13,
}

Stmt_Status :: enum i32 {
	Fullscan_Step = 1,
	Sort,
	Autoindex,
	Vm_Step,
	Reprepare,
	Run,
	Filter_Miss,
	Filter_Hit,
	Memused = 99,
}

Trace_Flag :: enum i32 {
	Stmt = 1,
	Profile,
	Row = 4,
	Close = 8,
}

Prepare_Flag :: enum i32 {
	Persistent = 1,
	Normalize,
	No_Vtab = 4,
	Dont_Log = 16,
	From_Ddl = 32,
}

Txn_State :: enum i32 {
	None,
	Read,
	Write,
}

Serialize_Flag :: enum i32 {
	Nocopy = 1,
}

Deserialize_Flag :: enum i32 {
	Freeonclose = 1,
	Resizeable,
	Readonly = 4,
}

Vtab_Config :: enum i32 {
	Constraint_Support = 1,
	Innocuous,
	Directonly,
	Uses_All_Schemas,
}

Index_Scan :: enum i32 {
	Unique = 1,
	Hex,
}

Index_Constraint_Op :: enum i32 {
	Eq = 2,
	Gt = 4,
	Le = 8,
	Lt = 16,
	Ge = 32,
	Match = 64,
	Like,
	Glob,
	Regexp,
	Ne,
	Isnot,
	Isnotnull,
	Isnull,
	Is,
	Limit,
	Offset,
	Function = 150,
}

Scanstat :: enum i32 {
	Nloop,
	Nvisit,
	Est,
	Name,
	Explain,
	Selectid,
	Parentid,
	Ncycle,
}

Mutex_Type :: enum i32 {
	Fast,
	Recursive,
	Static_Main,
	Static_Mem,
	Static_Mem2,
	Static_Open = 4,
	Static_Prng,
	Static_Lru,
	Static_Lru2,
	Static_Pmem = 7,
	Static_App1,
	Static_App2,
	Static_App3,
	Static_Vfs1,
	Static_Vfs2,
	Static_Vfs3,
	Static_Master = 2,
}

Testctrl :: enum i32 {
	First = 5,
	Prng_Save = 5,
	Prng_Restore,
	Prng_Reset,
	Fk_No_Action = 7,
	Bitvec_Test,
	Fault_Install,
	Benign_Malloc_Hooks,
	Pending_Byte,
	Assert,
	Always,
	Reserve,
	Json_Selfcheck = 14,
	Optimizations,
	Iskeyword,
	Getopt = 16,
	Scratchmalloc,
	Internal_Functions = 17,
	Localtime_Fault,
	Explain_Stmt,
	Once_Reset_Threshold = 19,
	Never_Corrupt,
	Vdbe_Coverage,
	Byteorder,
	Isinit,
	Sorter_Mmap,
	Imposter,
	Parser_Coverage,
	Result_Intreal,
	Prng_Seed,
	Extra_Schema_Checks,
	Seek_Count,
	Traceflags,
	Tune,
	Logest,
	Uselongdouble,
	Atof = 34,
	Last = 34,
}

Carray_Type :: enum i32 {
	Int32,
	Int64,
	Double,
	Text,
	Blob,
}

Authorizer_Action :: enum i32 {
	Create_Index = 1,
	Create_Table,
	Create_Temp_Index,
	Create_Temp_Table,
	Create_Temp_Trigger,
	Create_Temp_View,
	Create_Trigger,
	Create_View,
	Delete,
	Drop_Index,
	Drop_Table,
	Drop_Temp_Index,
	Drop_Temp_Table,
	Drop_Temp_Trigger,
	Drop_Temp_View,
	Drop_Trigger,
	Drop_View,
	Insert,
	Pragma,
	Read,
	Select,
	Transaction,
	Update,
	Attach,
	Detach,
	Alter_Table,
	Reindex,
	Analyze,
	Create_Vtable,
	Drop_Vtable,
	Function,
	Savepoint,
	Copy = 0,
	Recursive = 33,
}

Authorizer_Result :: enum i32 {
	Deny = 1,
	Ignore,
}

Datatype :: enum i32 {
	Integer = 1,
	Float,
	Blob = 4,
	Null,
	Text = 3,
}

Text_Encoding :: enum i32 {
	Utf8 = 1,
	Utf16_Le,
	Utf16_Be,
	Utf16,
	Any,
	Utf16_Aligned = 8,
	Utf8_Zt = 16,
}

Conflict_Action :: enum i32 {
	Rollback = 1,
	Fail     = 3,
	Replace  = 5,
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
	close :: proc(_: Sqlite3) -> i32 ---
	close_v2 :: proc(_: Sqlite3) -> i32 ---
	exec :: proc(_: Sqlite3, sql: cstring, callback: proc "c" (_: rawptr, _: i32, _: ^^u8, _: ^^u8) -> i32, _: rawptr, errmsg: ^^u8) -> i32 ---
	initialize :: proc() -> i32 ---
	shutdown :: proc() -> i32 ---
	os_init :: proc() -> i32 ---
	os_end :: proc() -> i32 ---
	config :: proc(_: i32, #c_vararg _: ..any) -> i32 ---
	db_config :: proc(_: Sqlite3, op: i32, #c_vararg _: ..any) -> i32 ---
	extended_result_codes :: proc(_: Sqlite3, onoff: i32) -> i32 ---
	last_insert_rowid :: proc(_: Sqlite3) -> i64 ---
	set_last_insert_rowid :: proc(_: Sqlite3, _: i64) ---
	changes :: proc(_: Sqlite3) -> i32 ---
	changes64 :: proc(_: Sqlite3) -> i64 ---
	total_changes :: proc(_: Sqlite3) -> i32 ---
	total_changes64 :: proc(_: Sqlite3) -> i64 ---
	interrupt :: proc(_: Sqlite3) ---
	is_interrupted :: proc(_: Sqlite3) -> i32 ---
	complete :: proc(sql: cstring) -> i32 ---
	complete16 :: proc(sql: rawptr) -> i32 ---
	busy_handler :: proc(_: Sqlite3, _: proc "c" (_: rawptr, _: i32) -> i32, _: rawptr) -> i32 ---
	busy_timeout :: proc(_: Sqlite3, ms: i32) -> i32 ---
	setlk_timeout :: proc(_: Sqlite3, ms: i32, flags: i32) -> i32 ---
	get_table :: proc(db: Sqlite3, zSql: cstring, pazResult: ^^^u8, pnRow: ^i32, pnColumn: ^i32, pzErrmsg: ^^u8) -> i32 ---
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
	set_authorizer :: proc(_: Sqlite3, xAuth: proc "c" (_: rawptr, _: i32, _: cstring, _: cstring, _: cstring, _: cstring) -> i32, pUserData: rawptr) -> i32 ---
	trace :: proc(_: Sqlite3, xTrace: proc "c" (_: rawptr, _: cstring), _: rawptr) -> rawptr ---
	profile :: proc(_: Sqlite3, xProfile: proc "c" (_: rawptr, _: cstring, _: u64), _: rawptr) -> rawptr ---
	trace_v2 :: proc(_: Sqlite3, uMask: u32, xCallback: proc "c" (_: u32, _: rawptr, _: rawptr, _: rawptr) -> i32, pCtx: rawptr) -> i32 ---
	progress_handler :: proc(_: Sqlite3, _: i32, _: proc "c" (_: rawptr) -> i32, _: rawptr) ---
	open :: proc(filename: cstring, ppDb: ^Sqlite3) -> i32 ---
	open16 :: proc(filename: rawptr, ppDb: ^Sqlite3) -> i32 ---
	open_v2 :: proc(filename: cstring, ppDb: ^Sqlite3, flags: i32, zVfs: cstring) -> i32 ---
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
	errcode :: proc(db: Sqlite3) -> i32 ---
	extended_errcode :: proc(db: Sqlite3) -> i32 ---
	errmsg :: proc(_: Sqlite3) -> cstring ---
	errmsg16 :: proc(_: Sqlite3) -> rawptr ---
	errstr :: proc(_: i32) -> cstring ---
	error_offset :: proc(db: Sqlite3) -> i32 ---
	set_errmsg :: proc(db: Sqlite3, errcode: i32, zErrMsg: cstring) -> i32 ---
	limit :: proc(_: Sqlite3, id: i32, newVal: i32) -> i32 ---
	prepare :: proc(db: Sqlite3, zSql: cstring, nByte: i32, ppStmt: ^Stmt, pzTail: ^cstring) -> i32 ---
	prepare_v2 :: proc(db: Sqlite3, zSql: cstring, nByte: i32, ppStmt: ^Stmt, pzTail: ^cstring) -> i32 ---
	prepare_v3 :: proc(db: Sqlite3, zSql: cstring, nByte: i32, prepFlags: u32, ppStmt: ^Stmt, pzTail: ^cstring) -> i32 ---
	prepare16 :: proc(db: Sqlite3, zSql: rawptr, nByte: i32, ppStmt: ^Stmt, pzTail: ^rawptr) -> i32 ---
	prepare16_v2 :: proc(db: Sqlite3, zSql: rawptr, nByte: i32, ppStmt: ^Stmt, pzTail: ^rawptr) -> i32 ---
	prepare16_v3 :: proc(db: Sqlite3, zSql: rawptr, nByte: i32, prepFlags: u32, ppStmt: ^Stmt, pzTail: ^rawptr) -> i32 ---
	sql :: proc(pStmt: Stmt) -> cstring ---
	expanded_sql :: proc(pStmt: Stmt) -> ^u8 ---
	stmt_readonly :: proc(pStmt: Stmt) -> i32 ---
	stmt_isexplain :: proc(pStmt: Stmt) -> i32 ---
	stmt_explain :: proc(pStmt: Stmt, eMode: i32) -> i32 ---
	stmt_busy :: proc(_: Stmt) -> i32 ---
	bind_blob :: proc(_: Stmt, _: i32, _: rawptr, n: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_blob64 :: proc(_: Stmt, _: i32, _: rawptr, _: u64, _: proc "c" (_: rawptr)) -> i32 ---
	bind_double :: proc(_: Stmt, _: i32, _: f64) -> i32 ---
	bind_int :: proc(_: Stmt, _: i32, _: i32) -> i32 ---
	bind_int64 :: proc(_: Stmt, _: i32, _: i64) -> i32 ---
	bind_null :: proc(_: Stmt, _: i32) -> i32 ---
	bind_text :: proc(_: Stmt, _: i32, _: cstring, _: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_text16 :: proc(_: Stmt, _: i32, _: rawptr, _: i32, _: proc "c" (_: rawptr)) -> i32 ---
	bind_text64 :: proc(_: Stmt, _: i32, _: cstring, _: u64, _: proc "c" (_: rawptr), encoding: u8) -> i32 ---
	bind_value :: proc(_: Stmt, _: i32, _: Value) -> i32 ---
	bind_pointer :: proc(_: Stmt, _: i32, _: rawptr, _: cstring, _: proc "c" (_: rawptr)) -> i32 ---
	bind_zeroblob :: proc(_: Stmt, _: i32, n: i32) -> i32 ---
	bind_zeroblob64 :: proc(_: Stmt, _: i32, _: u64) -> i32 ---
	bind_parameter_count :: proc(_: Stmt) -> i32 ---
	bind_parameter_name :: proc(_: Stmt, _: i32) -> cstring ---
	bind_parameter_index :: proc(_: Stmt, zName: cstring) -> i32 ---
	clear_bindings :: proc(_: Stmt) -> i32 ---
	column_count :: proc(pStmt: Stmt) -> i32 ---
	column_name :: proc(_: Stmt, N: i32) -> cstring ---
	column_name16 :: proc(_: Stmt, N: i32) -> rawptr ---
	column_database_name :: proc(_: Stmt, _: i32) -> cstring ---
	column_database_name16 :: proc(_: Stmt, _: i32) -> rawptr ---
	column_table_name :: proc(_: Stmt, _: i32) -> cstring ---
	column_table_name16 :: proc(_: Stmt, _: i32) -> rawptr ---
	column_origin_name :: proc(_: Stmt, _: i32) -> cstring ---
	column_origin_name16 :: proc(_: Stmt, _: i32) -> rawptr ---
	column_decltype :: proc(_: Stmt, _: i32) -> cstring ---
	column_decltype16 :: proc(_: Stmt, _: i32) -> rawptr ---
	step :: proc(_: Stmt) -> i32 ---
	data_count :: proc(pStmt: Stmt) -> i32 ---
	column_blob :: proc(_: Stmt, iCol: i32) -> rawptr ---
	column_double :: proc(_: Stmt, iCol: i32) -> f64 ---
	column_int :: proc(_: Stmt, iCol: i32) -> i32 ---
	column_int64 :: proc(_: Stmt, iCol: i32) -> i64 ---
	column_text :: proc(_: Stmt, iCol: i32) -> ^u8 ---
	column_text16 :: proc(_: Stmt, iCol: i32) -> rawptr ---
	column_value :: proc(_: Stmt, iCol: i32) -> Value ---
	column_bytes :: proc(_: Stmt, iCol: i32) -> i32 ---
	column_bytes16 :: proc(_: Stmt, iCol: i32) -> i32 ---
	column_type :: proc(_: Stmt, iCol: i32) -> i32 ---
	finalize :: proc(pStmt: Stmt) -> i32 ---
	reset :: proc(pStmt: Stmt) -> i32 ---
	create_function :: proc(db: Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: Context, _: i32, _: ^Value), xStep: proc "c" (_: Context, _: i32, _: ^Value), xFinal: proc "c" (_: Context)) -> i32 ---
	create_function16 :: proc(db: Sqlite3, zFunctionName: rawptr, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: Context, _: i32, _: ^Value), xStep: proc "c" (_: Context, _: i32, _: ^Value), xFinal: proc "c" (_: Context)) -> i32 ---
	create_function_v2 :: proc(db: Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xFunc: proc "c" (_: Context, _: i32, _: ^Value), xStep: proc "c" (_: Context, _: i32, _: ^Value), xFinal: proc "c" (_: Context), xDestroy: proc "c" (_: rawptr)) -> i32 ---
	create_window_function :: proc(db: Sqlite3, zFunctionName: cstring, nArg: i32, eTextRep: i32, pApp: rawptr, xStep: proc "c" (_: Context, _: i32, _: ^Value), xFinal: proc "c" (_: Context), xValue: proc "c" (_: Context), xInverse: proc "c" (_: Context, _: i32, _: ^Value), xDestroy: proc "c" (_: rawptr)) -> i32 ---
	aggregate_count :: proc(_: Context) -> i32 ---
	expired :: proc(_: Stmt) -> i32 ---
	transfer_bindings :: proc(_: Stmt, _: Stmt) -> i32 ---
	global_recover :: proc() -> i32 ---
	thread_cleanup :: proc() ---
	memory_alarm :: proc(_: proc "c" (_: rawptr, _: i64, _: i32), _: rawptr, _: i64) -> i32 ---
	value_blob :: proc(_: Value) -> rawptr ---
	value_double :: proc(_: Value) -> f64 ---
	value_int :: proc(_: Value) -> i32 ---
	value_int64 :: proc(_: Value) -> i64 ---
	value_pointer :: proc(_: Value, _: cstring) -> rawptr ---
	value_text :: proc(_: Value) -> ^u8 ---
	value_text16 :: proc(_: Value) -> rawptr ---
	value_text16le :: proc(_: Value) -> rawptr ---
	value_text16be :: proc(_: Value) -> rawptr ---
	value_bytes :: proc(_: Value) -> i32 ---
	value_bytes16 :: proc(_: Value) -> i32 ---
	value_type :: proc(_: Value) -> i32 ---
	value_numeric_type :: proc(_: Value) -> i32 ---
	value_nochange :: proc(_: Value) -> i32 ---
	value_frombind :: proc(_: Value) -> i32 ---
	value_encoding :: proc(_: Value) -> i32 ---
	value_subtype :: proc(_: Value) -> u32 ---
	value_dup :: proc(_: Value) -> Value ---
	value_free :: proc(_: Value) ---
	aggregate_context :: proc(_: Context, nBytes: i32) -> rawptr ---
	user_data :: proc(_: Context) -> rawptr ---
	context_db_handle :: proc(_: Context) -> Sqlite3 ---
	get_auxdata :: proc(_: Context, N: i32) -> rawptr ---
	set_auxdata :: proc(_: Context, N: i32, _: rawptr, _: proc "c" (_: rawptr)) ---
	get_clientdata :: proc(_: Sqlite3, _: cstring) -> rawptr ---
	set_clientdata :: proc(_: Sqlite3, _: cstring, _: rawptr, _: proc "c" (_: rawptr)) -> i32 ---
	result_blob :: proc(_: Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_blob64 :: proc(_: Context, _: rawptr, _: u64, _: proc "c" (_: rawptr)) ---
	result_double :: proc(_: Context, _: f64) ---
	result_error :: proc(_: Context, _: cstring, _: i32) ---
	result_error16 :: proc(_: Context, _: rawptr, _: i32) ---
	result_error_toobig :: proc(_: Context) ---
	result_error_nomem :: proc(_: Context) ---
	result_error_code :: proc(_: Context, _: i32) ---
	result_int :: proc(_: Context, _: i32) ---
	result_int64 :: proc(_: Context, _: i64) ---
	result_null :: proc(_: Context) ---
	result_text :: proc(_: Context, _: cstring, _: i32, _: proc "c" (_: rawptr)) ---
	result_text64 :: proc(_: Context, z: cstring, n: u64, _: proc "c" (_: rawptr), encoding: u8) ---
	result_text16 :: proc(_: Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_text16le :: proc(_: Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_text16be :: proc(_: Context, _: rawptr, _: i32, _: proc "c" (_: rawptr)) ---
	result_value :: proc(_: Context, _: Value) ---
	result_pointer :: proc(_: Context, _: rawptr, _: cstring, _: proc "c" (_: rawptr)) ---
	result_zeroblob :: proc(_: Context, n: i32) ---
	result_zeroblob64 :: proc(_: Context, n: u64) -> i32 ---
	result_subtype :: proc(_: Context, _: u32) ---
	create_collation :: proc(_: Sqlite3, zName: cstring, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32) -> i32 ---
	create_collation_v2 :: proc(_: Sqlite3, zName: cstring, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32, xDestroy: proc "c" (_: rawptr)) -> i32 ---
	create_collation16 :: proc(_: Sqlite3, zName: rawptr, eTextRep: i32, pArg: rawptr, xCompare: proc "c" (_: rawptr, _: i32, _: rawptr, _: i32, _: rawptr) -> i32) -> i32 ---
	collation_needed :: proc(_: Sqlite3, _: rawptr, _: proc "c" (_: rawptr, _: Sqlite3, _: i32, _: cstring)) -> i32 ---
	collation_needed16 :: proc(_: Sqlite3, _: rawptr, _: proc "c" (_: rawptr, _: Sqlite3, _: i32, _: rawptr)) -> i32 ---
	sleep :: proc(_: i32) -> i32 ---
	sqlite3_temp_directory: ^u8
	sqlite3_data_directory: ^u8
	win32_set_directory :: proc(type: u64, zValue: rawptr) -> i32 ---
	win32_set_directory8 :: proc(type: u64, zValue: cstring) -> i32 ---
	win32_set_directory16 :: proc(type: u64, zValue: rawptr) -> i32 ---
	get_autocommit :: proc(_: Sqlite3) -> i32 ---
	db_handle :: proc(_: Stmt) -> Sqlite3 ---
	db_name :: proc(db: Sqlite3, N: i32) -> cstring ---
	db_filename :: proc(db: Sqlite3, zDbName: cstring) -> Filename ---
	db_readonly :: proc(db: Sqlite3, zDbName: cstring) -> i32 ---
	txn_state :: proc(_: Sqlite3, zSchema: cstring) -> i32 ---
	next_stmt :: proc(pDb: Sqlite3, pStmt: Stmt) -> Stmt ---
	commit_hook :: proc(_: Sqlite3, _: proc "c" (_: rawptr) -> i32, _: rawptr) -> rawptr ---
	rollback_hook :: proc(_: Sqlite3, _: proc "c" (_: rawptr), _: rawptr) -> rawptr ---
	autovacuum_pages :: proc(db: Sqlite3, _: proc "c" (_: rawptr, _: cstring, _: u32, _: u32, _: u32) -> u32, _: rawptr, _: proc "c" (_: rawptr)) -> i32 ---
	update_hook :: proc(_: Sqlite3, _: proc "c" (_: rawptr, _: i32, _: cstring, _: cstring, _: i64), _: rawptr) -> rawptr ---
	enable_shared_cache :: proc(_: i32) -> i32 ---
	release_memory :: proc(_: i32) -> i32 ---
	db_release_memory :: proc(_: Sqlite3) -> i32 ---
	soft_heap_limit64 :: proc(N: i64) -> i64 ---
	hard_heap_limit64 :: proc(N: i64) -> i64 ---
	soft_heap_limit :: proc(N: i32) ---
	table_column_metadata :: proc(db: Sqlite3, zDbName: cstring, zTableName: cstring, zColumnName: cstring, pzDataType: ^cstring, pzCollSeq: ^cstring, pNotNull: ^i32, pPrimaryKey: ^i32, pAutoinc: ^i32) -> i32 ---
	load_extension :: proc(db: Sqlite3, zFile: cstring, zProc: cstring, pzErrMsg: ^^u8) -> i32 ---
	enable_load_extension :: proc(db: Sqlite3, onoff: i32) -> i32 ---
	auto_extension :: proc(xEntryPoint: proc "c" ()) -> i32 ---
	cancel_auto_extension :: proc(xEntryPoint: proc "c" ()) -> i32 ---
	reset_auto_extension :: proc() ---
	create_module :: proc(db: Sqlite3, zName: cstring, p: ^Module, pClientData: rawptr) -> i32 ---
	create_module_v2 :: proc(db: Sqlite3, zName: cstring, p: ^Module, pClientData: rawptr, xDestroy: proc "c" (_: rawptr)) -> i32 ---
	drop_modules :: proc(db: Sqlite3, azKeep: ^cstring) -> i32 ---
	declare_vtab :: proc(_: Sqlite3, zSQL: cstring) -> i32 ---
	overload_function :: proc(_: Sqlite3, zFuncName: cstring, nArg: i32) -> i32 ---
	blob_open :: proc(_: Sqlite3, zDb: cstring, zTable: cstring, zColumn: cstring, iRow: i64, flags: i32, ppBlob: ^Blob) -> i32 ---
	blob_reopen :: proc(_: Blob, _: i64) -> i32 ---
	blob_close :: proc(_: Blob) -> i32 ---
	blob_bytes :: proc(_: Blob) -> i32 ---
	blob_read :: proc(_: Blob, Z: rawptr, N: i32, iOffset: i32) -> i32 ---
	blob_write :: proc(_: Blob, z: rawptr, n: i32, iOffset: i32) -> i32 ---
	vfs_find :: proc(zVfsName: cstring) -> ^Vfs ---
	vfs_register :: proc(_: ^Vfs, makeDflt: i32) -> i32 ---
	vfs_unregister :: proc(_: ^Vfs) -> i32 ---
	mutex_alloc :: proc(_: i32) -> Mutex ---
	mutex_free :: proc(_: Mutex) ---
	mutex_enter :: proc(_: Mutex) ---
	mutex_try :: proc(_: Mutex) -> i32 ---
	mutex_leave :: proc(_: Mutex) ---
	mutex_held :: proc(_: Mutex) -> i32 ---
	mutex_notheld :: proc(_: Mutex) -> i32 ---
	db_mutex :: proc(_: Sqlite3) -> Mutex ---
	file_control :: proc(_: Sqlite3, zDbName: cstring, op: i32, _: rawptr) -> i32 ---
	test_control :: proc(op: i32, #c_vararg _: ..any) -> i32 ---
	keyword_count :: proc() -> i32 ---
	keyword_name :: proc(_: i32, _: ^cstring, _: ^i32) -> i32 ---
	keyword_check :: proc(_: cstring, _: i32) -> i32 ---
	str_new :: proc(_: Sqlite3) -> Str ---
	str_finish :: proc(_: Str) -> ^u8 ---
	str_free :: proc(_: Str) ---
	str_appendf :: proc(_: Str, zFormat: cstring, #c_vararg _: ..any) ---
	str_vappendf :: proc(_: Str, zFormat: cstring, _: ^Va_List_Tag) ---
	str_append :: proc(_: Str, zIn: cstring, N: i32) ---
	str_appendall :: proc(_: Str, zIn: cstring) ---
	str_appendchar :: proc(_: Str, N: i32, C: u8) ---
	str_reset :: proc(_: Str) ---
	str_truncate :: proc(_: Str, N: i32) ---
	str_errcode :: proc(_: Str) -> i32 ---
	str_length :: proc(_: Str) -> i32 ---
	str_value :: proc(_: Str) -> ^u8 ---
	status :: proc(op: i32, pCurrent: ^i32, pHighwater: ^i32, resetFlag: i32) -> i32 ---
	status64 :: proc(op: i32, pCurrent: ^i64, pHighwater: ^i64, resetFlag: i32) -> i32 ---
	db_status :: proc(_: Sqlite3, op: i32, pCur: ^i32, pHiwtr: ^i32, resetFlg: i32) -> i32 ---
	db_status64 :: proc(_: Sqlite3, _: i32, _: ^i64, _: ^i64, _: i32) -> i32 ---
	stmt_status :: proc(_: Stmt, op: i32, resetFlg: i32) -> i32 ---
	backup_init :: proc(pDest: Sqlite3, zDestName: cstring, pSource: Sqlite3, zSourceName: cstring) -> Backup ---
	backup_step :: proc(p: Backup, nPage: i32) -> i32 ---
	backup_finish :: proc(p: Backup) -> i32 ---
	backup_remaining :: proc(p: Backup) -> i32 ---
	backup_pagecount :: proc(p: Backup) -> i32 ---
	unlock_notify :: proc(pBlocked: Sqlite3, xNotify: proc "c" (_: ^rawptr, _: i32), pNotifyArg: rawptr) -> i32 ---
	stricmp :: proc(_: cstring, _: cstring) -> i32 ---
	strnicmp :: proc(_: cstring, _: cstring, _: i32) -> i32 ---
	strglob :: proc(zGlob: cstring, zStr: cstring) -> i32 ---
	strlike :: proc(zGlob: cstring, zStr: cstring, cEsc: u32) -> i32 ---
	log :: proc(iErrCode: i32, zFormat: cstring, #c_vararg _: ..any) ---
	wal_hook :: proc(_: Sqlite3, _: proc "c" (_: rawptr, _: Sqlite3, _: cstring, _: i32) -> i32, _: rawptr) -> rawptr ---
	wal_autocheckpoint :: proc(db: Sqlite3, N: i32) -> i32 ---
	wal_checkpoint :: proc(db: Sqlite3, zDb: cstring) -> i32 ---
	wal_checkpoint_v2 :: proc(db: Sqlite3, zDb: cstring, eMode: i32, pnLog: ^i32, pnCkpt: ^i32) -> i32 ---
	vtab_config :: proc(_: Sqlite3, op: i32, #c_vararg _: ..any) -> i32 ---
	vtab_on_conflict :: proc(_: Sqlite3) -> i32 ---
	vtab_nochange :: proc(_: Context) -> i32 ---
	vtab_collation :: proc(_: ^Index_Info, _: i32) -> cstring ---
	vtab_distinct :: proc(_: ^Index_Info) -> i32 ---
	vtab_in :: proc(_: ^Index_Info, iCons: i32, bHandle: i32) -> i32 ---
	vtab_in_first :: proc(pVal: Value, ppOut: ^Value) -> i32 ---
	vtab_in_next :: proc(pVal: Value, ppOut: ^Value) -> i32 ---
	vtab_rhs_value :: proc(_: ^Index_Info, _: i32, ppVal: ^Value) -> i32 ---
	stmt_scanstatus :: proc(pStmt: Stmt, idx: i32, iScanStatusOp: i32, pOut: rawptr) -> i32 ---
	stmt_scanstatus_v2 :: proc(pStmt: Stmt, idx: i32, iScanStatusOp: i32, flags: i32, pOut: rawptr) -> i32 ---
	stmt_scanstatus_reset :: proc(_: Stmt) ---
	db_cacheflush :: proc(_: Sqlite3) -> i32 ---
	system_errno :: proc(_: Sqlite3) -> i32 ---
	snapshot_get :: proc(db: Sqlite3, zSchema: cstring, ppSnapshot: ^^Snapshot) -> i32 ---
	snapshot_open :: proc(db: Sqlite3, zSchema: cstring, pSnapshot: ^Snapshot) -> i32 ---
	snapshot_free :: proc(_: ^Snapshot) ---
	snapshot_cmp :: proc(p1: ^Snapshot, p2: ^Snapshot) -> i32 ---
	snapshot_recover :: proc(db: Sqlite3, zDb: cstring) -> i32 ---
	serialize :: proc(db: Sqlite3, zSchema: cstring, piSize: ^i64, mFlags: u32) -> ^u8 ---
	deserialize :: proc(db: Sqlite3, zSchema: cstring, pData: ^u8, szDb: i64, szBuf: i64, mFlags: u32) -> i32 ---
	carray_bind_v2 :: proc(pStmt: Stmt, i: i32, aData: rawptr, nData: i32, mFlags: i32, xDel: proc "c" (_: rawptr), pDel: rawptr) -> i32 ---
	carray_bind :: proc(pStmt: Stmt, i: i32, aData: rawptr, nData: i32, mFlags: i32, xDel: proc "c" (_: rawptr)) -> i32 ---
	rtree_geometry_callback :: proc(db: Sqlite3, zGeom: cstring, xGeom: proc "c" (_: ^Rtree_Geometry, _: i32, _: ^Rtree_Dbl, _: ^i32) -> i32, pContext: rawptr) -> i32 ---
	rtree_query_callback :: proc(db: Sqlite3, zQueryFunc: cstring, xQueryFunc: proc "c" (_: ^Rtree_Query_Info) -> i32, pContext: rawptr, xDestructor: proc "c" (_: rawptr)) -> i32 ---
}
