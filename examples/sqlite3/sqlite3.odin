package sqlite3

foreign import lib "system:sqlite3"

SQLITE_VERSION :: "3.53.2"
SQLITE_VERSION_NUMBER :: 3053002
SQLITE_SOURCE_ID :: "2026-06-03 19:12:13 d6e03d8c777cfa2d35e3b60d8ec3e0187f3e9f99d8e2ee9cac695fd6fcdfalt1"
SQLITE_SCM_BRANCH :: "branch-3.53"
SQLITE_SCM_TAGS :: "release version-3.53.2"
SQLITE_SCM_DATETIME :: "2026-06-03T19:12:13.350Z"
SQLITE_OPEN_READONLY :: 0x00000001
SQLITE_OPEN_READWRITE :: 0x00000002
SQLITE_OPEN_CREATE :: 0x00000004
SQLITE_OPEN_DELETEONCLOSE :: 0x00000008
SQLITE_OPEN_EXCLUSIVE :: 0x00000010
SQLITE_OPEN_AUTOPROXY :: 0x00000020
SQLITE_OPEN_URI :: 0x00000040
SQLITE_OPEN_MEMORY :: 0x00000080
SQLITE_OPEN_MAIN_DB :: 0x00000100
SQLITE_OPEN_TEMP_DB :: 0x00000200
SQLITE_OPEN_TRANSIENT_DB :: 0x00000400
SQLITE_OPEN_MAIN_JOURNAL :: 0x00000800
SQLITE_OPEN_TEMP_JOURNAL :: 0x00001000
SQLITE_OPEN_SUBJOURNAL :: 0x00002000
SQLITE_OPEN_SUPER_JOURNAL :: 0x00004000
SQLITE_OPEN_NOMUTEX :: 0x00008000
SQLITE_OPEN_FULLMUTEX :: 0x00010000
SQLITE_OPEN_SHAREDCACHE :: 0x00020000
SQLITE_OPEN_PRIVATECACHE :: 0x00040000
SQLITE_OPEN_WAL :: 0x00080000
SQLITE_OPEN_NOFOLLOW :: 0x01000000
SQLITE_OPEN_EXRESCODE :: 0x02000000
SQLITE_OPEN_MASTER_JOURNAL :: 0x00004000
SQLITE_IOCAP_ATOMIC :: 0x00000001
SQLITE_IOCAP_ATOMIC512 :: 0x00000002
SQLITE_IOCAP_ATOMIC1K :: 0x00000004
SQLITE_IOCAP_ATOMIC2K :: 0x00000008
SQLITE_IOCAP_ATOMIC4K :: 0x00000010
SQLITE_IOCAP_ATOMIC8K :: 0x00000020
SQLITE_IOCAP_ATOMIC16K :: 0x00000040
SQLITE_IOCAP_ATOMIC32K :: 0x00000080
SQLITE_IOCAP_ATOMIC64K :: 0x00000100
SQLITE_IOCAP_SAFE_APPEND :: 0x00000200
SQLITE_IOCAP_SEQUENTIAL :: 0x00000400
SQLITE_IOCAP_UNDELETABLE_WHEN_OPEN :: 0x00000800
SQLITE_IOCAP_POWERSAFE_OVERWRITE :: 0x00001000
SQLITE_IOCAP_IMMUTABLE :: 0x00002000
SQLITE_IOCAP_BATCH_ATOMIC :: 0x00004000
SQLITE_IOCAP_SUBPAGE_READ :: 0x00008000
SQLITE_LOCK_NONE :: 0
SQLITE_LOCK_SHARED :: 1
SQLITE_LOCK_RESERVED :: 2
SQLITE_LOCK_PENDING :: 3
SQLITE_LOCK_EXCLUSIVE :: 4
SQLITE_SYNC_NORMAL :: 0x00002
SQLITE_SYNC_FULL :: 0x00003
SQLITE_SYNC_DATAONLY :: 0x00010
SQLITE_FCNTL_LOCKSTATE :: 1
SQLITE_FCNTL_GET_LOCKPROXYFILE :: 2
SQLITE_FCNTL_SET_LOCKPROXYFILE :: 3
SQLITE_FCNTL_LAST_ERRNO :: 4
SQLITE_FCNTL_SIZE_HINT :: 5
SQLITE_FCNTL_CHUNK_SIZE :: 6
SQLITE_FCNTL_FILE_POINTER :: 7
SQLITE_FCNTL_SYNC_OMITTED :: 8
SQLITE_FCNTL_WIN32_AV_RETRY :: 9
SQLITE_FCNTL_PERSIST_WAL :: 10
SQLITE_FCNTL_OVERWRITE :: 11
SQLITE_FCNTL_VFSNAME :: 12
SQLITE_FCNTL_POWERSAFE_OVERWRITE :: 13
SQLITE_FCNTL_PRAGMA :: 14
SQLITE_FCNTL_BUSYHANDLER :: 15
SQLITE_FCNTL_TEMPFILENAME :: 16
SQLITE_FCNTL_MMAP_SIZE :: 18
SQLITE_FCNTL_TRACE :: 19
SQLITE_FCNTL_HAS_MOVED :: 20
SQLITE_FCNTL_SYNC :: 21
SQLITE_FCNTL_COMMIT_PHASETWO :: 22
SQLITE_FCNTL_WIN32_SET_HANDLE :: 23
SQLITE_FCNTL_WAL_BLOCK :: 24
SQLITE_FCNTL_ZIPVFS :: 25
SQLITE_FCNTL_RBU :: 26
SQLITE_FCNTL_VFS_POINTER :: 27
SQLITE_FCNTL_JOURNAL_POINTER :: 28
SQLITE_FCNTL_WIN32_GET_HANDLE :: 29
SQLITE_FCNTL_PDB :: 30
SQLITE_FCNTL_BEGIN_ATOMIC_WRITE :: 31
SQLITE_FCNTL_COMMIT_ATOMIC_WRITE :: 32
SQLITE_FCNTL_ROLLBACK_ATOMIC_WRITE :: 33
SQLITE_FCNTL_LOCK_TIMEOUT :: 34
SQLITE_FCNTL_DATA_VERSION :: 35
SQLITE_FCNTL_SIZE_LIMIT :: 36
SQLITE_FCNTL_CKPT_DONE :: 37
SQLITE_FCNTL_RESERVE_BYTES :: 38
SQLITE_FCNTL_CKPT_START :: 39
SQLITE_FCNTL_EXTERNAL_READER :: 40
SQLITE_FCNTL_CKSM_FILE :: 41
SQLITE_FCNTL_RESET_CACHE :: 42
SQLITE_FCNTL_NULL_IO :: 43
SQLITE_FCNTL_BLOCK_ON_CONNECT :: 44
SQLITE_FCNTL_FILESTAT :: 45
SQLITE_ACCESS_EXISTS :: 0
SQLITE_ACCESS_READWRITE :: 1
SQLITE_ACCESS_READ :: 2
SQLITE_SHM_UNLOCK :: 1
SQLITE_SHM_LOCK :: 2
SQLITE_SHM_SHARED :: 4
SQLITE_SHM_EXCLUSIVE :: 8
SQLITE_SHM_NLOCK :: 8
SQLITE_CONFIG_SINGLETHREAD :: 1
SQLITE_CONFIG_MULTITHREAD :: 2
SQLITE_CONFIG_SERIALIZED :: 3
SQLITE_CONFIG_MALLOC :: 4
SQLITE_CONFIG_GETMALLOC :: 5
SQLITE_CONFIG_SCRATCH :: 6
SQLITE_CONFIG_PAGECACHE :: 7
SQLITE_CONFIG_HEAP :: 8
SQLITE_CONFIG_MEMSTATUS :: 9
SQLITE_CONFIG_MUTEX :: 10
SQLITE_CONFIG_GETMUTEX :: 11
SQLITE_CONFIG_LOOKASIDE :: 13
SQLITE_CONFIG_PCACHE :: 14
SQLITE_CONFIG_GETPCACHE :: 15
SQLITE_CONFIG_LOG :: 16
SQLITE_CONFIG_URI :: 17
SQLITE_CONFIG_PCACHE2 :: 18
SQLITE_CONFIG_GETPCACHE2 :: 19
SQLITE_CONFIG_COVERING_INDEX_SCAN :: 20
SQLITE_CONFIG_SQLLOG :: 21
SQLITE_CONFIG_MMAP_SIZE :: 22
SQLITE_CONFIG_WIN32_HEAPSIZE :: 23
SQLITE_CONFIG_PCACHE_HDRSZ :: 24
SQLITE_CONFIG_PMASZ :: 25
SQLITE_CONFIG_STMTJRNL_SPILL :: 26
SQLITE_CONFIG_SMALL_MALLOC :: 27
SQLITE_CONFIG_SORTERREF_SIZE :: 28
SQLITE_CONFIG_MEMDB_MAXSIZE :: 29
SQLITE_CONFIG_ROWID_IN_VIEW :: 30
SQLITE_DBCONFIG_MAINDBNAME :: 1000
SQLITE_DBCONFIG_LOOKASIDE :: 1001
SQLITE_DBCONFIG_ENABLE_FKEY :: 1002
SQLITE_DBCONFIG_ENABLE_TRIGGER :: 1003
SQLITE_DBCONFIG_ENABLE_FTS3_TOKENIZER :: 1004
SQLITE_DBCONFIG_ENABLE_LOAD_EXTENSION :: 1005
SQLITE_DBCONFIG_NO_CKPT_ON_CLOSE :: 1006
SQLITE_DBCONFIG_ENABLE_QPSG :: 1007
SQLITE_DBCONFIG_TRIGGER_EQP :: 1008
SQLITE_DBCONFIG_RESET_DATABASE :: 1009
SQLITE_DBCONFIG_DEFENSIVE :: 1010
SQLITE_DBCONFIG_WRITABLE_SCHEMA :: 1011
SQLITE_DBCONFIG_LEGACY_ALTER_TABLE :: 1012
SQLITE_DBCONFIG_DQS_DML :: 1013
SQLITE_DBCONFIG_DQS_DDL :: 1014
SQLITE_DBCONFIG_ENABLE_VIEW :: 1015
SQLITE_DBCONFIG_LEGACY_FILE_FORMAT :: 1016
SQLITE_DBCONFIG_TRUSTED_SCHEMA :: 1017
SQLITE_DBCONFIG_STMT_SCANSTATUS :: 1018
SQLITE_DBCONFIG_REVERSE_SCANORDER :: 1019
SQLITE_DBCONFIG_ENABLE_ATTACH_CREATE :: 1020
SQLITE_DBCONFIG_ENABLE_ATTACH_WRITE :: 1021
SQLITE_DBCONFIG_ENABLE_COMMENTS :: 1022
SQLITE_DBCONFIG_FP_DIGITS :: 1023
SQLITE_DBCONFIG_MAX :: 1023
SQLITE_TRACE_STMT :: 0x01
SQLITE_TRACE_PROFILE :: 0x02
SQLITE_TRACE_ROW :: 0x04
SQLITE_TRACE_CLOSE :: 0x08
SQLITE_LIMIT_LENGTH :: 0
SQLITE_LIMIT_SQL_LENGTH :: 1
SQLITE_LIMIT_COLUMN :: 2
SQLITE_LIMIT_EXPR_DEPTH :: 3
SQLITE_LIMIT_COMPOUND_SELECT :: 4
SQLITE_LIMIT_VDBE_OP :: 5
SQLITE_LIMIT_FUNCTION_ARG :: 6
SQLITE_LIMIT_ATTACHED :: 7
SQLITE_LIMIT_LIKE_PATTERN_LENGTH :: 8
SQLITE_LIMIT_VARIABLE_NUMBER :: 9
SQLITE_LIMIT_TRIGGER_DEPTH :: 10
SQLITE_LIMIT_WORKER_THREADS :: 11
SQLITE_LIMIT_PARSER_DEPTH :: 12
SQLITE_PREPARE_PERSISTENT :: 0x01
SQLITE_PREPARE_NORMALIZE :: 0x02
SQLITE_PREPARE_NO_VTAB :: 0x04
SQLITE_PREPARE_DONT_LOG :: 0x10
SQLITE_PREPARE_FROM_DDL :: 0x20
SQLITE3_TEXT :: 3
SQLITE_DETERMINISTIC :: 0x000000800
SQLITE_DIRECTONLY :: 0x000080000
SQLITE_SUBTYPE :: 0x000100000
SQLITE_INNOCUOUS :: 0x000200000
SQLITE_RESULT_SUBTYPE :: 0x001000000
SQLITE_SELFORDER1 :: 0x002000000
SQLITE_WIN32_DATA_DIRECTORY_TYPE :: 1
SQLITE_WIN32_TEMP_DIRECTORY_TYPE :: 2
SQLITE_TXN_NONE :: 0
SQLITE_TXN_READ :: 1
SQLITE_TXN_WRITE :: 2
SQLITE_INDEX_SCAN_UNIQUE :: 0x00000001
SQLITE_INDEX_SCAN_HEX :: 0x00000002
SQLITE_INDEX_CONSTRAINT_EQ :: 2
SQLITE_INDEX_CONSTRAINT_GT :: 4
SQLITE_INDEX_CONSTRAINT_LE :: 8
SQLITE_INDEX_CONSTRAINT_LT :: 16
SQLITE_INDEX_CONSTRAINT_GE :: 32
SQLITE_INDEX_CONSTRAINT_MATCH :: 64
SQLITE_INDEX_CONSTRAINT_LIKE :: 65
SQLITE_INDEX_CONSTRAINT_GLOB :: 66
SQLITE_INDEX_CONSTRAINT_REGEXP :: 67
SQLITE_INDEX_CONSTRAINT_NE :: 68
SQLITE_INDEX_CONSTRAINT_ISNOT :: 69
SQLITE_INDEX_CONSTRAINT_ISNOTNULL :: 70
SQLITE_INDEX_CONSTRAINT_ISNULL :: 71
SQLITE_INDEX_CONSTRAINT_IS :: 72
SQLITE_INDEX_CONSTRAINT_LIMIT :: 73
SQLITE_INDEX_CONSTRAINT_OFFSET :: 74
SQLITE_INDEX_CONSTRAINT_FUNCTION :: 150
SQLITE_STATUS_MEMORY_USED :: 0
SQLITE_STATUS_PAGECACHE_USED :: 1
SQLITE_STATUS_PAGECACHE_OVERFLOW :: 2
SQLITE_STATUS_SCRATCH_USED :: 3
SQLITE_STATUS_SCRATCH_OVERFLOW :: 4
SQLITE_STATUS_MALLOC_SIZE :: 5
SQLITE_STATUS_PARSER_STACK :: 6
SQLITE_STATUS_PAGECACHE_SIZE :: 7
SQLITE_STATUS_SCRATCH_SIZE :: 8
SQLITE_STATUS_MALLOC_COUNT :: 9
SQLITE_DBSTATUS_LOOKASIDE_USED :: 0
SQLITE_DBSTATUS_CACHE_USED :: 1
SQLITE_DBSTATUS_SCHEMA_USED :: 2
SQLITE_DBSTATUS_STMT_USED :: 3
SQLITE_DBSTATUS_LOOKASIDE_HIT :: 4
SQLITE_DBSTATUS_LOOKASIDE_MISS_SIZE :: 5
SQLITE_DBSTATUS_LOOKASIDE_MISS_FULL :: 6
SQLITE_DBSTATUS_CACHE_HIT :: 7
SQLITE_DBSTATUS_CACHE_MISS :: 8
SQLITE_DBSTATUS_CACHE_WRITE :: 9
SQLITE_DBSTATUS_DEFERRED_FKS :: 10
SQLITE_DBSTATUS_CACHE_USED_SHARED :: 11
SQLITE_DBSTATUS_CACHE_SPILL :: 12
SQLITE_DBSTATUS_TEMPBUF_SPILL :: 13
SQLITE_DBSTATUS_MAX :: 13
SQLITE_STMTSTATUS_FULLSCAN_STEP :: 1
SQLITE_STMTSTATUS_SORT :: 2
SQLITE_STMTSTATUS_AUTOINDEX :: 3
SQLITE_STMTSTATUS_VM_STEP :: 4
SQLITE_STMTSTATUS_REPREPARE :: 5
SQLITE_STMTSTATUS_RUN :: 6
SQLITE_STMTSTATUS_FILTER_MISS :: 7
SQLITE_STMTSTATUS_FILTER_HIT :: 8
SQLITE_STMTSTATUS_MEMUSED :: 99
SQLITE_CHECKPOINT_PASSIVE :: 0
SQLITE_CHECKPOINT_FULL :: 1
SQLITE_CHECKPOINT_RESTART :: 2
SQLITE_CHECKPOINT_TRUNCATE :: 3
SQLITE_VTAB_CONSTRAINT_SUPPORT :: 1
SQLITE_VTAB_INNOCUOUS :: 2
SQLITE_VTAB_DIRECTONLY :: 3
SQLITE_VTAB_USES_ALL_SCHEMAS :: 4
SQLITE_SCANSTAT_NLOOP :: 0
SQLITE_SCANSTAT_NVISIT :: 1
SQLITE_SCANSTAT_EST :: 2
SQLITE_SCANSTAT_NAME :: 3
SQLITE_SCANSTAT_EXPLAIN :: 4
SQLITE_SCANSTAT_SELECTID :: 5
SQLITE_SCANSTAT_PARENTID :: 6
SQLITE_SCANSTAT_NCYCLE :: 7
SQLITE_SCANSTAT_COMPLEX :: 0x0001
SQLITE_SERIALIZE_NOCOPY :: 0x001
SQLITE_DESERIALIZE_FREEONCLOSE :: 1
SQLITE_DESERIALIZE_RESIZEABLE :: 2
SQLITE_DESERIALIZE_READONLY :: 4
CARRAY_INT32 :: 0
CARRAY_INT64 :: 1
CARRAY_DOUBLE :: 2
CARRAY_TEXT :: 3
CARRAY_BLOB :: 4
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
	Setlk_Block_On_Connect = 1,
	Deny = 1,
	Ignore = 2,
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
	Integer = 1,
	Float = 2,
	Blob = 4,
	Null = 5,
	Text = 3,
	Utf8 = 1,
	Utf16_Le = 2,
	Utf16_Be = 3,
	Utf16 = 4,
	Any = 5,
	Utf16_Aligned = 8,
	Utf8_Zt = 16,
	Mutex_Fast = 0,
	Mutex_Recursive = 1,
	Mutex_Static_Main = 2,
	Mutex_Static_Mem = 3,
	Mutex_Static_Mem2 = 4,
	Mutex_Static_Open = 4,
	Mutex_Static_Prng = 5,
	Mutex_Static_Lru = 6,
	Mutex_Static_Lru2 = 7,
	Mutex_Static_Pmem = 7,
	Mutex_Static_App1 = 8,
	Mutex_Static_App2 = 9,
	Mutex_Static_App3 = 10,
	Mutex_Static_Vfs1 = 11,
	Mutex_Static_Vfs2 = 12,
	Mutex_Static_Vfs3 = 13,
	Mutex_Static_Master = 2,
	Testctrl_First = 5,
	Testctrl_Prng_Save = 5,
	Testctrl_Prng_Restore = 6,
	Testctrl_Prng_Reset = 7,
	Testctrl_Fk_No_Action = 7,
	Testctrl_Bitvec_Test = 8,
	Testctrl_Fault_Install = 9,
	Testctrl_Benign_Malloc_Hooks = 10,
	Testctrl_Pending_Byte = 11,
	Testctrl_Assert = 12,
	Testctrl_Always = 13,
	Testctrl_Reserve = 14,
	Testctrl_Json_Selfcheck = 14,
	Testctrl_Optimizations = 15,
	Testctrl_Iskeyword = 16,
	Testctrl_Getopt = 16,
	Testctrl_Scratchmalloc = 17,
	Testctrl_Internal_Functions = 17,
	Testctrl_Localtime_Fault = 18,
	Testctrl_Explain_Stmt = 19,
	Testctrl_Once_Reset_Threshold = 19,
	Testctrl_Never_Corrupt = 20,
	Testctrl_Vdbe_Coverage = 21,
	Testctrl_Byteorder = 22,
	Testctrl_Isinit = 23,
	Testctrl_Sorter_Mmap = 24,
	Testctrl_Imposter = 25,
	Testctrl_Parser_Coverage = 26,
	Testctrl_Result_Intreal = 27,
	Testctrl_Prng_Seed = 28,
	Testctrl_Extra_Schema_Checks = 29,
	Testctrl_Seek_Count = 30,
	Testctrl_Traceflags = 31,
	Testctrl_Tune = 32,
	Testctrl_Logest = 33,
	Testctrl_Uselongdouble = 34,
	Testctrl_Atof = 34,
	Testctrl_Last = 34,
	Rollback = 1,
	Fail = 3,
	Replace = 5,
	Carray_Int32 = 0,
	Carray_Int64 = 1,
	Carray_Double = 2,
	Carray_Text = 3,
	Carray_Blob = 4,
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
