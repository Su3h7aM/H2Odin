package fff

foreign import lib "system:fff"

CREATE_OPTIONS_VERSION :: 1
/**
 * Result envelope returned by all `fff_*` functions.
 *
 * Heap-allocated. The caller must free it with `fff_free_result`. Calling `fff_free_result`
 * **does not** deallocate the underlying `handle` pointer. It needs to be cleaned separately.
 * see (`fff_destroy`, `fff_free_search_result`, `fff_free_grep_result`, `fff_free_string`, etc.).
 *
 * Depending on the function, the payload is delivered through different fields:
 *
 * | Function                   | Payload field | Type                          |
 * |----------------------------|---------------|-------------------------------|
 * | `fff_create_instance`      | `handle`      | opaque instance pointer       |
 * | `fff_search`               | `handle`      | `*mut FffSearchResult`        |
 * | `fff_live_grep`            | `handle`      | `*mut FffGrepResult`          |
 * | `fff_multi_grep`           | `handle`      | `*mut FffGrepResult`          |
 * | `fff_get_scan_progress`    | `handle`      | `*mut FffScanProgress`        |
 * | `fff_health_check`         | `handle`      | `*mut c_char` (JSON string)   |
 * | `fff_get_historical_query` | `handle`      | `*mut c_char` (string or null)|
 * | `fff_wait_for_scan`        | `int_value`   | 1 = completed, 0 = timed out  |
 * | `fff_track_query`          | `int_value`   | 1 = success, 0 = failure      |
 * | `fff_refresh_git_status`   | `int_value`   | number of files updated       |
 * | `fff_scan_files`           | (none)        | success flag only             |
 * | `fff_restart_index`        | (none)        | success flag only             |
 *
 * On failure, `success` is false and `error` contains the message.
 */
FffResult :: struct {
	/**
	   * Whether the operation succeeded.
	   */
	success: bool,
	/**
	   * Error message on failure. Null on success.
	   */
	error: ^u8,
	/**
	   * Opaque pointer payload. May be null.
	   */
	handle: rawptr,
	/**
	   * Integer payload for simple return values (bool as 0/1, counts, etc.).
	   */
	int_value: i64,
}

/**
 * Options for `fff_create_instance_with`.
 *
 * Versioned struct: you populate the struct at your call level, we guarantee that
 * the version is stable across the version changes, new fields only appended!
 */
FffCreateOptions :: struct {
	/**
	   * Set to [`FFF_CREATE_OPTIONS_VERSION`] when allocating. Used by the
	   * library to determine which trailing fields are populated.
	   */
	version: u32,
	/**
	   * Directory to index (required, non-NULL).
	   */
	base_path: cstring,
	/**
	   * Frecency LMDB database path. NULL/empty to skip frecency tracking.
	   */
	frecency_db_path: cstring,
	/**
	   * Query history LMDB database path. NULL/empty to skip query tracking.
	   */
	history_db_path: cstring,
	/**
	   * Pre-populate mmap caches for top-frecency files after the initial scan.
	   */
	enable_mmap_cache: bool,
	/**
	   * Build content index after the initial scan for faster grep.
	   */
	enable_content_indexing: bool,
	/**
	   * Start a background file-system watcher for live updates.
	   */
	watch: bool,
	/**
	   * Enable AI-agent optimizations.
	   */
	ai_mode: bool,
	/**
	   * Path-shape hint for the per-session log file. Each call writes a fresh
	   * sibling file `<stem>+<UTC-timestamp>+<pid>.<ext>` next to this path.
	   * The literal path is never written to, so concurrent processes get
	   * unique per-pid files. NULL/empty to skip log init.
	   */
	log_file_path: cstring,
	/**
	   * Log level: `"trace" | "debug" | "info" | "warn" | "error"`.
	   * NULL/empty defaults to `"info"`. Ignored when `log_file_path` is unset.
	   */
	log_level: cstring,
	/**
	   * Content cache file-count cap. 0 = auto.
	   */
	cache_budget_max_files: u64,
	/**
	   * Content cache byte cap. 0 = auto.
	   */
	cache_budget_max_bytes: u64,
	/**
	   * Per-file byte cap inside the content cache. 0 = auto.
	   */
	cache_budget_max_file_size: u64,
	/**
	   * Allow indexing the filesystem root (`/`). Off by default — root is
	   * rarely the intended target and floods the watcher with churn.
	   */
	enable_fs_root_scanning: bool,
	/**
	   * Allow indexing the user's home directory. Same trade-off as
	   * `enable_fs_root_scanning`.
	   */
	enable_home_dir_scanning: bool,
}

/**
 * A file item returned by `fff_search`.
 *
 * All string fields are heap-allocated and owned by the parent `FffSearchResult`.
 * Free the entire result with `fff_free_search_result`.
 */
FffFileItem :: struct {
	relative_path: ^u8,
	file_name: ^u8,
	git_status: ^u8,
	size: u64,
	modified: u64,
	access_frecency_score: i64,
	modification_frecency_score: i64,
	total_frecency_score: i64,
	is_binary: bool,
}

/**
 * Score breakdown for a search result.
 */
FffScore :: struct {
	total: i32,
	base_score: i32,
	filename_bonus: i32,
	special_filename_bonus: i32,
	frecency_boost: i32,
	distance_penalty: i32,
	current_file_penalty: i32,
	combo_match_boost: i32,
	path_alignment_bonus: i32,
	exact_match: bool,
	match_type: ^u8,
}

/**
 * Location parsed from a query string (e.g. `"file.ts:42:10"`).
 *
 * `tag` encodes the variant:
 *   0 = no location,
 *   1 = line only (`line` is set),
 *   2 = position (`line` + `col`),
 *   3 = range (`line`/`col` = start, `end_line`/`end_col` = end).
 */
FffLocation :: struct {
	tag: u8,
	line: i32,
	col: i32,
	end_line: i32,
	end_col: i32,
}

/**
 * Search result returned by `fff_search`.
 *
 * The caller must free this with `fff_free_search_result`.
 */
FffSearchResult :: struct {
	/**
	   * Pointer to a heap-allocated array of `FffFileItem` (length = `count`).
	   */
	items: ^FffFileItem,
	/**
	   * Pointer to a heap-allocated array of `FffScore` (length = `count`).
	   */
	scores: ^FffScore,
	/**
	   * Number of items/scores in the arrays.
	   */
	count: u32,
	/**
	   * Total number of files that matched the query.
	   */
	total_matched: u32,
	/**
	   * Total number of indexed files.
	   */
	total_files: u32,
	/**
	   * Location parsed from the query string.
	   */
	location: FffLocation,
}

/**
 * A byte range within a matched line, used for highlighting.
 */
FffMatchRange :: struct {
	start: u32,
	end: u32,
}

/**
 * A single grep match with file and line information.
 *
 * All string fields and arrays are heap-allocated. Free the parent
 * `FffGrepResult` with `fff_free_grep_result` to release everything.
 */
FffGrepMatch :: struct {
	relative_path: ^u8,
	file_name: ^u8,
	git_status: ^u8,
	line_content: ^u8,
	match_ranges: ^FffMatchRange,
	context_before: ^^u8,
	context_after: ^^u8,
	size: u64,
	modified: u64,
	total_frecency_score: i64,
	access_frecency_score: i64,
	modification_frecency_score: i64,
	line_number: u64,
	byte_offset: u64,
	col: u32,
	match_ranges_count: u32,
	context_before_count: u32,
	context_after_count: u32,
	fuzzy_score: u16,
	has_fuzzy_score: bool,
	is_binary: bool,
	is_definition: bool,
}

/**
 * Grep result returned by `fff_live_grep` and `fff_multi_grep`.
 *
 * The caller must free this with `fff_free_grep_result`.
 */
FffGrepResult :: struct {
	/**
	   * Pointer to a heap-allocated array of `FffGrepMatch` (length = `count`).
	   */
	items: ^FffGrepMatch,
	/**
	   * Number of matches in the `items` array.
	   */
	count: u32,
	/**
	   * Total number of matches (always equal to `count`).
	   */
	total_matched: u32,
	/**
	   * Number of files actually opened and searched in this call.
	   */
	total_files_searched: u32,
	/**
	   * Total number of indexed files (before any filtering).
	   */
	total_files: u32,
	/**
	   * Number of files eligible for search after filtering.
	   */
	filtered_file_count: u32,
	/**
	   * File offset for the next page. 0 if all files have been searched.
	   */
	next_file_offset: u32,
	/**
	   * Regex compilation error when falling back to literal matching. Null if none.
	   */
	regex_fallback_error: ^u8,
}

/**
 * Scan progress returned by `fff_get_scan_progress`.
 * The caller must free this with `fff_free_scan_progress`.
 */
FffScanProgress :: struct {
	scanned_files_count: u64,
	is_scanning: bool,
	is_watcher_ready: bool,
	is_warmup_complete: bool,
}

/**
 * A directory item returned by `fff_search_directories`.
 *
 * All string fields are heap-allocated and owned by the parent `FffDirSearchResult`.
 * Free the entire result with `fff_free_dir_search_result`.
 */
FffDirItem :: struct {
	relative_path: ^u8,
	dir_name: ^u8,
	max_access_frecency: i32,
}

/**
 * Directory search result returned by `fff_search_directories`.
 *
 * The caller must free this with `fff_free_dir_search_result`.
 */
FffDirSearchResult :: struct {
	/**
	   * Pointer to a heap-allocated array of `FffDirItem` (length = `count`).
	   */
	items: ^FffDirItem,
	/**
	   * Pointer to a heap-allocated array of `FffScore` (length = `count`).
	   */
	scores: ^FffScore,
	/**
	   * Number of items/scores in the arrays.
	   */
	count: u32,
	/**
	   * Total number of directories that matched the query.
	   */
	total_matched: u32,
	/**
	   * Total number of indexed directories.
	   */
	total_dirs: u32,
}

/**
 * A single item in a mixed (files + directories) search result.
 *
 * `item_type`: 0 = file, 1 = directory.
 * All string fields are heap-allocated and owned by the parent `FffMixedSearchResult`.
 */
FffMixedItem :: struct {
	/**
	   * 0 = file, 1 = directory.
	   */
	item_type: u8,
	relative_path: ^u8,
	/**
	   * Filename for files, last directory segment for directories.
	   */
	display_name: ^u8,
	git_status: ^u8,
	size: u64,
	modified: u64,
	/**
	   * The access frecency score for files, or max access frecency among all the immediate
	   * children for directories.
	   */
	access_frecency_score: i64,
	/**
	   * Always 0 for directories
	   */
	modification_frecency_score: i64,
	/**
	   * Always 0 for directories
	   */
	total_frecency_score: i64,
	/**
	   * Always 0 for directories
	   */
	is_binary: bool,
}

/**
 * Mixed search result returned by `fff_search_mixed`.
 *
 * The caller must free this with `fff_free_mixed_search_result`.
 */
FffMixedSearchResult :: struct {
	/**
	   * Pointer to a heap-allocated array of `FffMixedItem` (length = `count`).
	   */
	items: ^FffMixedItem,
	/**
	   * Pointer to a heap-allocated array of `FffScore` (length = `count`).
	   */
	scores: ^FffScore,
	/**
	   * Number of items/scores in the arrays.
	   */
	count: u32,
	/**
	   * Total number of items (files + dirs) that matched the query.
	   */
	total_matched: u32,
	/**
	   * Total number of indexed files.
	   */
	total_files: u32,
	/**
	   * Total number of indexed directories.
	   */
	total_dirs: u32,
	/**
	   * Location parsed from the query string.
	   */
	location: FffLocation,
}

foreign lib {
	/**
	 * Create a new file finder instance (legacy 8-arg positional signature).
	 *
	 * @deprecated Use [`fff_create_instance_with`] (or
	 * [`fff_create_instance_with_value`] for FFI bindings) — both take the
	 * versioned [`FffCreateOptions`] struct that evolves without ABI breaks.
	 * This function delegates to `fff_create_instance_with` internally; the
	 * `use_unsafe_no_lock` parameter is deprecated and ignored.
	 *
	 * ## Safety
	 * See `fff_create_instance_with`.
	 */
	@(link_name = "fff_create_instance")
	create_instance :: proc(base_path: cstring, frecency_db_path: cstring, history_db_path: cstring, _use_unsafe_no_lock: bool, enable_mmap_cache: bool, enable_content_indexing: bool, watch: bool, ai_mode: bool) -> ^FffResult ---
	/**
	 * Create a new file finder instance (legacy 13-arg positional signature).
	 *
	 * @deprecated Use [`fff_create_instance_with`] (or
	 * [`fff_create_instance_with_value`] for FFI bindings) — both take the
	 * versioned [`FffCreateOptions`] struct that evolves without ABI breaks.
	 * The `use_unsafe_no_lock` parameter is deprecated and ignored.
	 *
	 * ## Safety
	 * See `fff_create_instance_with`.
	 */
	@(link_name = "fff_create_instance2")
	create_instance2 :: proc(base_path: cstring, frecency_db_path: cstring, history_db_path: cstring, _use_unsafe_no_lock: bool, enable_mmap_cache: bool, enable_content_indexing: bool, watch: bool, ai_mode: bool, log_file_path: cstring, log_level: cstring, cache_budget_max_files: u64, cache_budget_max_bytes: u64, cache_budget_max_file_size: u64) -> ^FffResult ---
	/**
	 * Create a new file finder instance from an [`FffCreateOptions`] struct.
	 *
	 * **Direct C consumers** populate the struct (designated initializers
	 * recommended), set `version` to [`FFF_CREATE_OPTIONS_VERSION`], and pass
	 * it by pointer. New fields are appended in future versions; old callers
	 * passing `version = 1` keep working forever.
	 *
	 * **FFI consumers** that prefer struct-by-value semantics (e.g. ffi-rs's
	 * `paramsType: [structDef]`) should use [`fff_create_instance_with_value`]
	 * instead — it's a thin calling-convention adapter that delegates here.
	 *
	 * Required: `opts.base_path` must be non-NULL and non-empty.
	 *
	 * When all three `cache_budget_*` values are 0 the budget is auto-computed
	 * from repo size after the initial scan. Otherwise an explicit budget is
	 * used: any field left at 0 falls back to its `unlimited()` default.
	 *
	 * ## Safety
	 * * `opts` must be a valid pointer to an `FffCreateOptions` whose `version`
	 *   is in the range `1..=FFF_CREATE_OPTIONS_VERSION`.
	 * * All string pointers inside `opts` must be valid null-terminated UTF-8
	 *   or NULL.
	 */
	@(link_name = "fff_create_instance_with")
	create_instance_with :: proc(opts: ^FffCreateOptions) -> ^FffResult ---
	/**
	 * Calling-convention adapter for [`fff_create_instance_with`].
	 *
	 * Same logic, but takes the [`FffCreateOptions`] struct **by value**. This
	 * makes the function callable from FFI libraries whose native struct
	 * support passes structs by value on the wire (e.g. Node's `ffi-rs` with
	 * `paramsType: [structDef]`).
	 *
	 * This is **not** a versioned wrapper — when new fields are appended to
	 * `FffCreateOptions`, both this function and `fff_create_instance_with`
	 * pick them up automatically with no signature change.
	 *
	 * ## Safety
	 * All `*const c_char` fields inside `opts` must be valid null-terminated
	 * UTF-8 or NULL. The struct itself is consumed by value.
	 */
	@(link_name = "fff_create_instance_with_value")
	create_instance_with_value :: proc(opts: FffCreateOptions) -> ^FffResult ---
	/**
	 * Destroy a file finder instance and free all its resources.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid pointer returned by `fff_create_instance`, or null (no-op).
	 */
	@(link_name = "fff_destroy")
	destroy :: proc(fff_handle: rawptr) ---
	/**
	 * Perform fuzzy search on indexed files.
	 *
	 * # Parameters
	 *
	 * * `fff_handle`              – instance from `fff_create_instance`
	 * * `query`                   – search query string
	 * * `current_file`            – path of the currently open file for deprioritization (NULL/empty to skip)
	 * * `max_threads`             – maximum worker threads (0 = auto-detect)
	 * * `page_index`              – pagination offset (0 = first page)
	 * * `page_size`               – results per page (0 = default 100)
	 * * `combo_boost_multiplier`  – score multiplier for combo matches (0 = default 100)
	 * * `min_combo_count`         – minimum combo count before boost applies (0 = default 3)
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `query` and `current_file` must be valid null-terminated UTF-8 strings or NULL.
	 */
	@(link_name = "fff_search")
	search :: proc(fff_handle: rawptr, query: cstring, current_file: cstring, max_threads: u32, page_index: u32, page_size: u32, combo_boost_multiplier: i32, min_combo_count: u32) -> ^FffResult ---
	/**
	 * Glob-only search: filter indexed files by a single glob pattern, rank by
	 * frecency, and paginate. Bypasses the regular query parser entirely.
	 *
	 * Use this when you already have a literal glob pattern (e.g. `*.rs`, a
	 * recursive `**` match, or `src/components` prefix) and want neither fuzzy
	 * matching nor multi-token constraint parsing. Ranking falls back to
	 * frecency because there is no fuzzy score to combine with.
	 *
	 * # Parameters
	 *
	 * * `fff_handle`   - instance from `fff_create_instance`
	 * * `pattern`      - glob pattern (required, no parsing - passed through verbatim)
	 * * `current_file` - path of the currently open file for deprioritization (NULL/empty to skip)
	 * * `max_threads`  - maximum worker threads (0 = auto-detect)
	 * * `page_index`   - pagination offset (0 = first page)
	 * * `page_size`    - results per page (0 = default 100)
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `pattern` and `current_file` must be valid null-terminated UTF-8 strings or NULL.
	 */
	@(link_name = "fff_glob")
	glob :: proc(fff_handle: rawptr, pattern: cstring, current_file: cstring, max_threads: u32, page_index: u32, page_size: u32) -> ^FffResult ---
	/**
	 * Perform fuzzy search on indexed directories.
	 *
	 * # Parameters
	 *
	 * * `fff_handle`   – instance from `fff_create_instance`
	 * * `query`        – search query string
	 * * `current_file` – path of the currently open file for distance scoring (NULL/empty to skip)
	 * * `max_threads`  – maximum worker threads (0 = auto-detect)
	 * * `page_index`   – pagination offset (0 = first page)
	 * * `page_size`    – results per page (0 = default 100)
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `query` and `current_file` must be valid null-terminated UTF-8 strings or NULL.
	 */
	@(link_name = "fff_search_directories")
	search_directories :: proc(fff_handle: rawptr, query: cstring, current_file: cstring, max_threads: u32, page_index: u32, page_size: u32) -> ^FffResult ---
	/**
	 * Perform a mixed fuzzy search across both files and directories.
	 *
	 * Returns a single flat list where files and directories are interleaved
	 * by total score in descending order. Each item has an `item_type` field
	 * (0 = file, 1 = directory).
	 *
	 * # Parameters
	 *
	 * * `fff_handle`              – instance from `fff_create_instance`
	 * * `query`                   – search query string
	 * * `current_file`            – path of the currently open file (NULL/empty to skip)
	 * * `max_threads`             – maximum worker threads (0 = auto-detect)
	 * * `page_index`              – pagination offset (0 = first page)
	 * * `page_size`               – results per page (0 = default 100)
	 * * `combo_boost_multiplier`  – score multiplier for combo matches (0 = default 100)
	 * * `min_combo_count`         – minimum combo count before boost applies (0 = default 3)
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `query` and `current_file` must be valid null-terminated UTF-8 strings or NULL.
	 */
	@(link_name = "fff_search_mixed")
	search_mixed :: proc(fff_handle: rawptr, query: cstring, current_file: cstring, max_threads: u32, page_index: u32, page_size: u32, combo_boost_multiplier: i32, min_combo_count: u32) -> ^FffResult ---
	/**
	 * Perform content search (grep) across indexed files.
	 *
	 * # Parameters
	 *
	 * * `fff_handle`            – instance from `fff_create_instance`
	 * * `query`                 – search query (supports constraint syntax like `*.rs pattern`)
	 * * `mode`                  – 0 = plain text (SIMD), 1 = regex, 2 = fuzzy
	 * * `max_file_size`         – skip files larger than this in bytes (0 = default 10 MB)
	 * * `max_matches_per_file`  – max matches per file (0 = unlimited)
	 * * `smart_case`            – case-insensitive when query is all lowercase
	 * * `file_offset`           – file-based pagination offset (0 = start)
	 * * `page_limit`            – max matches to return (0 = default 50)
	 * * `time_budget_ms`        – wall-clock budget in ms (0 = unlimited)
	 * * `before_context`        – context lines before each match
	 * * `after_context`         – context lines after each match
	 * * `classify_definitions`  – tag matches that are code definitions
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `query` must be a valid null-terminated UTF-8 string.
	 */
	@(link_name = "fff_live_grep")
	live_grep :: proc(fff_handle: rawptr, query: cstring, mode: u8, max_file_size: u64, max_matches_per_file: u32, smart_case: bool, file_offset: u32, page_limit: u32, time_budget_ms: u64, before_context: u32, after_context: u32, classify_definitions: bool) -> ^FffResult ---
	/**
	 * Perform multi-pattern OR search (Aho-Corasick) across indexed files.
	 *
	 * Searches for lines matching ANY of the provided patterns using
	 * SIMD-accelerated multi-needle matching.
	 *
	 * # Parameters
	 *
	 * * `fff_handle`              – instance from `fff_create_instance`
	 * * `patterns_joined`         – patterns separated by `\n` (e.g. `"foo\nbar\nbaz"`)
	 * * `constraints`             – file filter like `"*.rs"` or `"/src/"` (NULL/empty to skip)
	 * * `max_file_size`           – skip files larger than this in bytes (0 = default 10 MB)
	 * * `max_matches_per_file`    – max matches per file (0 = unlimited)
	 * * `smart_case`              – case-insensitive when all patterns are lowercase
	 * * `file_offset`             – file-based pagination offset (0 = start)
	 * * `page_limit`              – max matches to return (0 = default 50)
	 * * `time_budget_ms`          – wall-clock budget in ms (0 = unlimited)
	 * * `before_context`          – context lines before each match
	 * * `after_context`           – context lines after each match
	 * * `classify_definitions`    – tag matches that are code definitions
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `patterns_joined` and `constraints` must be valid null-terminated UTF-8 or NULL.
	 */
	@(link_name = "fff_multi_grep")
	multi_grep :: proc(fff_handle: rawptr, patterns_joined: cstring, constraints: cstring, max_file_size: u64, max_matches_per_file: u32, smart_case: bool, file_offset: u32, page_limit: u32, time_budget_ms: u64, before_context: u32, after_context: u32, classify_definitions: bool) -> ^FffResult ---
	/**
	 * Trigger a rescan of the file index.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_scan_files")
	scan_files :: proc(fff_handle: rawptr) -> ^FffResult ---
	/**
	 * Check if a scan is currently in progress.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_is_scanning")
	is_scanning :: proc(fff_handle: rawptr) -> bool ---
	/**
	 * Get the base path of the file picker.
	 *
	 * Returns an `FffResult` with a heap-allocated C string in the `handle`
	 * field. Free the string with `fff_free_string` after reading it.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_get_base_path")
	get_base_path :: proc(fff_handle: rawptr) -> ^FffResult ---
	/**
	 * Get scan progress information.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_get_scan_progress")
	get_scan_progress :: proc(fff_handle: rawptr) -> ^FffResult ---
	/**
	 * Wait for initial scan to complete.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_wait_for_scan")
	wait_for_scan :: proc(fff_handle: rawptr, timeout_ms: u64) -> ^FffResult ---
	/**
	 * Wait for the background file watcher to be ready.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_wait_for_watcher")
	wait_for_watcher :: proc(fff_handle: rawptr, timeout_ms: u64) -> ^FffResult ---
	/**
	 * Restart indexing in a new directory.
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `new_path` must be a valid null-terminated UTF-8 string.
	 */
	@(link_name = "fff_restart_index")
	restart_index :: proc(fff_handle: rawptr, new_path: cstring) -> ^FffResult ---
	/**
	 * Refresh git status cache.
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_refresh_git_status")
	refresh_git_status :: proc(fff_handle: rawptr) -> ^FffResult ---
	/**
	 * Track query completion for smart suggestions.
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 * * `query` and `file_path` must be valid null-terminated UTF-8 strings.
	 */
	@(link_name = "fff_track_query")
	track_query :: proc(fff_handle: rawptr, query: cstring, file_path: cstring) -> ^FffResult ---
	/**
	 * Get historical query by offset (0 = most recent).
	 *
	 * ## Safety
	 * `fff_handle` must be a valid instance pointer from `fff_create_instance`.
	 */
	@(link_name = "fff_get_historical_query")
	get_historical_query :: proc(fff_handle: rawptr, offset: u64) -> ^FffResult ---
	/**
	 * Get health check information.
	 *
	 * ## Safety
	 * * `fff_handle` must be a valid instance pointer from `fff_create_instance`, or null for
	 *   a limited health check (version + git only).
	 * * `test_path` can be null or a valid null-terminated UTF-8 string.
	 */
	@(link_name = "fff_health_check")
	health_check :: proc(fff_handle: rawptr, test_path: cstring) -> ^FffResult ---
	/**
	 * Free a search result returned by `fff_search`.
	 *
	 * This frees the `FffSearchResult` struct, its `items` and `scores` arrays,
	 * and all heap-allocated strings within each item and score.
	 *
	 * ## Safety
	 * `result` must be a valid pointer previously returned via `FffResult.handle`
	 * from `fff_search`, or null (no-op).
	 */
	@(link_name = "fff_free_search_result")
	free_search_result :: proc(result: ^FffSearchResult) ---
	/**
	 * Get a pointer to the `index`-th `FffFileItem` in a search result.
	 *
	 * Returns null if `result` is null or `index >= result->count`.
	 * The returned pointer is valid until the search result is freed.
	 *
	 * ## Safety
	 * `result` must be a valid `FffSearchResult` pointer from `fff_search`.
	 */
	@(link_name = "fff_search_result_get_item")
	search_result_get_item :: proc(result: ^FffSearchResult, index: u32) -> ^FffFileItem ---
	/**
	 * Get a pointer to the `index`-th `FffScore` in a search result.
	 *
	 * Returns null if `result` is null or `index >= result->count`.
	 * The returned pointer is valid until the search result is freed.
	 *
	 * ## Safety
	 * `result` must be a valid `FffSearchResult` pointer from `fff_search`.
	 */
	@(link_name = "fff_search_result_get_score")
	search_result_get_score :: proc(result: ^FffSearchResult, index: u32) -> ^FffScore ---
	/**
	 * Free a grep result returned by `fff_live_grep` or `fff_multi_grep`.
	 *
	 * This frees the `FffGrepResult` struct, its `items` array, and all
	 * heap-allocated strings, match ranges, and context arrays within each match.
	 *
	 * ## Safety
	 * `result` must be a valid pointer previously returned via `FffResult.handle`
	 * from `fff_live_grep` or `fff_multi_grep`, or null (no-op).
	 */
	@(link_name = "fff_free_grep_result")
	free_grep_result :: proc(result: ^FffGrepResult) ---
	/**
	 * Get a pointer to the `index`-th `FffGrepMatch` in a grep result.
	 *
	 * Returns null if `result` is null or `index >= result->count`.
	 * The returned pointer is valid until the grep result is freed.
	 *
	 * ## Safety
	 * `result` must be a valid `FffGrepResult` pointer from `fff_live_grep` or `fff_multi_grep`.
	 */
	@(link_name = "fff_grep_result_get_match")
	grep_result_get_match :: proc(result: ^FffGrepResult, index: u32) -> ^FffGrepMatch ---
	/**
	 * Free a scan progress result returned by `fff_get_scan_progress`.
	 *
	 * ## Safety
	 * `result` must be a valid pointer previously returned via `FffResult.handle`
	 * from `fff_get_scan_progress`, or null (no-op).
	 */
	@(link_name = "fff_free_scan_progress")
	free_scan_progress :: proc(result: ^FffScanProgress) ---
	/**
	 * Offset a pointer by `byte_offset` bytes.
	 *
	 * General-purpose utility for FFI consumers that need pointer arithmetic
	 * (e.g. iterating over arrays). Returns null if `base` is null.
	 *
	 * ## Safety
	 * The resulting pointer must be within the bounds of the original allocation.
	 */
	@(link_name = "fff_ptr_offset")
	ptr_offset :: proc(base: rawptr, byte_offset: uintptr) -> rawptr ---
	/**
	 * Free a result returned by any `fff_*` function.
	 * **IMPORTANT:** this doesn't clean the the internal handle, so it is safe to call right after
	 * you handle the error case.
	 *
	 * Note: Many non-libffi implementations are not supporting struct-by-value returns, so it's more
	 * convenient to have pointer returned at most of the time, though allocating result for every call
	 * is annoying, so we just rely on the fact that our allocator is good enough.
	 *
	 * ## Safety
	 * `result_ptr` must be a valid pointer returned by a `fff_*` function.
	 */
	@(link_name = "fff_free_result")
	free_result :: proc(result_ptr: ^FffResult) ---
	/**
	 * Free a string returned by `fff_*` functions.
	 *
	 * ## Safety
	 * `s` must be a valid C string allocated by this library.
	 */
	@(link_name = "fff_free_string")
	free_string :: proc(s: ^u8) ---
	/**
	 * Free a directory search result returned by `fff_search_directories`.
	 *
	 * ## Safety
	 * `result` must be a valid pointer previously returned via `FffResult.handle`
	 * from `fff_search_directories`, or null (no-op).
	 */
	@(link_name = "fff_free_dir_search_result")
	free_dir_search_result :: proc(result: ^FffDirSearchResult) ---
	/**
	 * Get a pointer to the `index`-th `FffDirItem` in a directory search result.
	 *
	 * ## Safety
	 * `result` must be a valid `FffDirSearchResult` pointer from `fff_search_directories`.
	 */
	@(link_name = "fff_dir_search_result_get_item")
	dir_search_result_get_item :: proc(result: ^FffDirSearchResult, index: u32) -> ^FffDirItem ---
	/**
	 * Get a pointer to the `index`-th `FffScore` in a directory search result.
	 *
	 * ## Safety
	 * `result` must be a valid `FffDirSearchResult` pointer from `fff_search_directories`.
	 */
	@(link_name = "fff_dir_search_result_get_score")
	dir_search_result_get_score :: proc(result: ^FffDirSearchResult, index: u32) -> ^FffScore ---
	/**
	 * Free a mixed search result returned by `fff_search_mixed`.
	 *
	 * ## Safety
	 * `result` must be a valid pointer previously returned via `FffResult.handle`
	 * from `fff_search_mixed`, or null (no-op).
	 */
	@(link_name = "fff_free_mixed_search_result")
	free_mixed_search_result :: proc(result: ^FffMixedSearchResult) ---
	/**
	 * Get a pointer to the `index`-th `FffMixedItem` in a mixed search result.
	 *
	 * ## Safety
	 * `result` must be a valid `FffMixedSearchResult` pointer from `fff_search_mixed`.
	 */
	@(link_name = "fff_mixed_search_result_get_item")
	mixed_search_result_get_item :: proc(result: ^FffMixedSearchResult, index: u32) -> ^FffMixedItem ---
	/**
	 * Get a pointer to the `index`-th `FffScore` in a mixed search result.
	 *
	 * ## Safety
	 * `result` must be a valid `FffMixedSearchResult` pointer from `fff_search_mixed`.
	 */
	@(link_name = "fff_mixed_search_result_get_score")
	mixed_search_result_get_score :: proc(result: ^FffMixedSearchResult, index: u32) -> ^FffScore ---
	/**
	 * Returns the relative path of a file item (e.g. `"src/main.rs"`).
	 *
	 * Returns null if `item` is null. The returned pointer is valid for the
	 * lifetime of the owning `FffSearchResult`; do not free it directly.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_relative_path")
	file_item_get_relative_path :: proc(item: ^FffFileItem) -> cstring ---
	/**
	 * Returns the file-name component of a file item (e.g. `"main.rs"`).
	 *
	 * Returns null if `item` is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_file_name")
	file_item_get_file_name :: proc(item: ^FffFileItem) -> cstring ---
	/**
	 * Returns the git status string for a file item (e.g. `"M "`, `"??"`)
	 * or null if git is unavailable, the file is untracked, or `item` is null.
	 *
	 * Do not free the returned pointer.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_git_status")
	file_item_get_git_status :: proc(item: ^FffFileItem) -> cstring ---
	/**
	 * Returns the file size in bytes. Returns `0` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_size")
	file_item_get_size :: proc(item: ^FffFileItem) -> u64 ---
	/**
	 * Returns the last-modified time as seconds since the UNIX epoch.
	 * Returns `0` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_modified")
	file_item_get_modified :: proc(item: ^FffFileItem) -> u64 ---
	/**
	 * Returns the combined frecency score. Returns `0` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_total_frecency_score")
	file_item_get_total_frecency_score :: proc(item: ^FffFileItem) -> i64 ---
	/**
	 * Returns the access-based frecency score. Returns `0` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_access_frecency_score")
	file_item_get_access_frecency_score :: proc(item: ^FffFileItem) -> i64 ---
	/**
	 * Returns the modification-based frecency score. Returns `0` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_modification_frecency_score")
	file_item_get_modification_frecency_score :: proc(item: ^FffFileItem) -> i64 ---
	/**
	 * Returns `true` if the file was detected as binary. Returns `false` if `item` is null.
	 *
	 * ## Safety
	 * `item` must be a valid `FffFileItem` pointer or null.
	 */
	@(link_name = "fff_file_item_get_is_binary")
	file_item_get_is_binary :: proc(item: ^FffFileItem) -> bool ---
	/**
	 * Returns the relative path of the file containing this grep match.
	 *
	 * Returns null if `m` is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_relative_path")
	grep_match_get_relative_path :: proc(m: ^FffGrepMatch) -> cstring ---
	/**
	 * Returns the file-name component of the file containing this grep match.
	 *
	 * Returns null if `m` is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_file_name")
	grep_match_get_file_name :: proc(m: ^FffGrepMatch) -> cstring ---
	/**
	 * Returns the git status string for the matched file (e.g. `"M "`, `"??"`)
	 * or null if git is unavailable, the file is untracked, or `m` is null.
	 *
	 * Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_git_status")
	grep_match_get_git_status :: proc(m: ^FffGrepMatch) -> cstring ---
	/**
	 * Returns the full text content of the matched line.
	 *
	 * Returns null if `m` is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_line_content")
	grep_match_get_line_content :: proc(m: ^FffGrepMatch) -> cstring ---
	/**
	 * Returns the 1-based line number of the match within its file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_line_number")
	grep_match_get_line_number :: proc(m: ^FffGrepMatch) -> u64 ---
	/**
	 * Returns the 0-based column of the match start within its line.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_col")
	grep_match_get_col :: proc(m: ^FffGrepMatch) -> u32 ---
	/**
	 * Returns the byte offset of the match start from the beginning of the file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_byte_offset")
	grep_match_get_byte_offset :: proc(m: ^FffGrepMatch) -> u64 ---
	/**
	 * Returns the file size in bytes for the matched file. Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_size")
	grep_match_get_size :: proc(m: ^FffGrepMatch) -> u64 ---
	/**
	 * Returns the combined frecency score for the matched file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_total_frecency_score")
	grep_match_get_total_frecency_score :: proc(m: ^FffGrepMatch) -> i64 ---
	/**
	 * Returns the access-based frecency score for the matched file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_access_frecency_score")
	grep_match_get_access_frecency_score :: proc(m: ^FffGrepMatch) -> i64 ---
	/**
	 * Returns the modification-based frecency score for the matched file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_modification_frecency_score")
	grep_match_get_modification_frecency_score :: proc(m: ^FffGrepMatch) -> i64 ---
	/**
	 * Returns the last-modified time as seconds since the UNIX epoch for the matched file.
	 * Returns `0` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_modified")
	grep_match_get_modified :: proc(m: ^FffGrepMatch) -> u64 ---
	/**
	 * Returns the number of highlight ranges in this match. Returns `0` if `m` is null.
	 *
	 * Use with [`fff_grep_match_get_match_range`] to iterate the highlight spans.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_match_ranges_count")
	grep_match_get_match_ranges_count :: proc(m: ^FffGrepMatch) -> u32 ---
	/**
	 * Returns a pointer to the `index`-th [`FffMatchRange`] highlight span.
	 *
	 * Returns null if `m` is null, `index >= match_ranges_count`, or the
	 * ranges array is null. The returned pointer is valid until the owning
	 * `FffGrepResult` is freed; do not free it directly.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_match_range")
	grep_match_get_match_range :: proc(m: ^FffGrepMatch, index: u32) -> ^FffMatchRange ---
	/**
	 * Returns the number of context lines captured before the match.
	 * Returns `0` if `m` is null.
	 *
	 * Use with [`fff_grep_match_get_context_before`] to read each line.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_context_before_count")
	grep_match_get_context_before_count :: proc(m: ^FffGrepMatch) -> u32 ---
	/**
	 * Returns the `index`-th context line before the match.
	 *
	 * Returns null if `m` is null, `index >= context_before_count`, or the
	 * context array is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_context_before")
	grep_match_get_context_before :: proc(m: ^FffGrepMatch, index: u32) -> cstring ---
	/**
	 * Returns the number of context lines captured after the match.
	 * Returns `0` if `m` is null.
	 *
	 * Use with [`fff_grep_match_get_context_after`] to read each line.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_context_after_count")
	grep_match_get_context_after_count :: proc(m: ^FffGrepMatch) -> u32 ---
	/**
	 * Returns the `index`-th context line after the match.
	 *
	 * Returns null if `m` is null, `index >= context_after_count`, or the
	 * context array is null. Do not free the returned pointer.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_context_after")
	grep_match_get_context_after :: proc(m: ^FffGrepMatch, index: u32) -> cstring ---
	/**
	 * Returns the fuzzy match score. Returns `0` if `m` is null or no fuzzy
	 * score is present.
	 *
	 * Always check [`fff_grep_match_get_has_fuzzy_score`] first; `0` is
	 * ambiguous without that flag.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_fuzzy_score")
	grep_match_get_fuzzy_score :: proc(m: ^FffGrepMatch) -> u16 ---
	/**
	 * Returns `true` if this match carries a valid fuzzy score.
	 * Returns `false` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_has_fuzzy_score")
	grep_match_get_has_fuzzy_score :: proc(m: ^FffGrepMatch) -> bool ---
	/**
	 * Returns `true` if the match was identified as a symbol definition.
	 * Returns `false` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_is_definition")
	grep_match_get_is_definition :: proc(m: ^FffGrepMatch) -> bool ---
	/**
	 * Returns `true` if the matched file was detected as binary.
	 * Returns `false` if `m` is null.
	 *
	 * ## Safety
	 * `m` must be a valid `FffGrepMatch` pointer or null.
	 */
	@(link_name = "fff_grep_match_get_is_binary")
	grep_match_get_is_binary :: proc(m: ^FffGrepMatch) -> bool ---
	/**
	 * Returns the number of items in the result. Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffSearchResult` pointer or null.
	 */
	@(link_name = "fff_search_result_get_count")
	search_result_get_count :: proc(r: ^FffSearchResult) -> u32 ---
	/**
	 * Returns the total number of files that matched before the result was
	 * truncated to the page size. Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffSearchResult` pointer or null.
	 */
	@(link_name = "fff_search_result_get_total_matched")
	search_result_get_total_matched :: proc(r: ^FffSearchResult) -> u32 ---
	/**
	 * Returns the total number of indexed files considered during search.
	 * Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffSearchResult` pointer or null.
	 */
	@(link_name = "fff_search_result_get_total_files")
	search_result_get_total_files :: proc(r: ^FffSearchResult) -> u32 ---
	/**
	 * Returns the number of matches in the result. Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_count")
	grep_result_get_count :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the total number of matches found across all pages.
	 * Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_total_matched")
	grep_result_get_total_matched :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the number of files actually opened and searched in this call.
	 * Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_total_files_searched")
	grep_result_get_total_files_searched :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the total number of indexed files before any filtering.
	 * Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_total_files")
	grep_result_get_total_files :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the number of files eligible for search after path/type filtering.
	 * Returns `0` if `r` is null.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_filtered_file_count")
	grep_result_get_filtered_file_count :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the file offset for the next page, or `0` if all files have been
	 * searched or `r` is null. Pass this value as `file_offset` to a subsequent
	 * `fff_live_grep` or `fff_multi_grep` call to continue pagination.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_next_file_offset")
	grep_result_get_next_file_offset :: proc(r: ^FffGrepResult) -> u32 ---
	/**
	 * Returns the regex compilation error string if the engine fell back to
	 * literal matching, or null if there was no error or `r` is null.
	 *
	 * Do not free the returned pointer.
	 *
	 * ## Safety
	 * `r` must be a valid `FffGrepResult` pointer or null.
	 */
	@(link_name = "fff_grep_result_get_regex_fallback_error")
	grep_result_get_regex_fallback_error :: proc(r: ^FffGrepResult) -> cstring ---
}
