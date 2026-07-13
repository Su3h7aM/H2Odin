-- Example config for sqlite3.h.
--
-- Odin naming (examples wiki): Ada_Case types and enum values, snake_case
-- procs/fields, SCREAMING_SNAKE constants. Library prefixes are stripped so
-- the package carries the namespace (sqlite3_stmt → Stmt, sqlite3_open → open).
-- The bare handle `sqlite3` cannot strip to empty, so it stays Sqlite3.
-- foreign.link_prefix + proc strip omit per-decl link_name when
-- C name == prefix + Odin name. types.map rewrites 64-bit typedefs at use
-- sites; those typedef decls are removed as pure aliases.
--
-- type_mode = idiomatic: incomplete tag handles (sqlite3, stmt, value, …)
-- become distinct rawptr with collapsed pointers. Complete
-- records (file, vfs, …) stay as structs. Override a name with
-- types.opaque = { sqlite3_stmt = false } if you need the faithful shape.
--
-- macros.groups turns related SQLITE_* integer macros into explicit-valued
-- enums (Result_Code, Open_Flag, …). emit_original_consts = false drops the
-- consumed macros so each value appears once.

local h2o = require "h2odin"

-- Primary result codes only (see https://www.sqlite.org/rescode.html).
-- Value filters alone are not enough: authorizer actions, datatypes, mutex
-- kinds, etc. share the same small integers under the SQLITE_ prefix.
local RESULT_CODES = {
	SQLITE_OK = true,
	SQLITE_ERROR = true,
	SQLITE_INTERNAL = true,
	SQLITE_PERM = true,
	SQLITE_ABORT = true,
	SQLITE_BUSY = true,
	SQLITE_LOCKED = true,
	SQLITE_NOMEM = true,
	SQLITE_READONLY = true,
	SQLITE_INTERRUPT = true,
	SQLITE_IOERR = true,
	SQLITE_CORRUPT = true,
	SQLITE_NOTFOUND = true,
	SQLITE_FULL = true,
	SQLITE_CANTOPEN = true,
	SQLITE_PROTOCOL = true,
	SQLITE_EMPTY = true,
	SQLITE_SCHEMA = true,
	SQLITE_TOOBIG = true,
	SQLITE_CONSTRAINT = true,
	SQLITE_MISMATCH = true,
	SQLITE_MISUSE = true,
	SQLITE_NOLFS = true,
	SQLITE_AUTH = true,
	SQLITE_FORMAT = true,
	SQLITE_RANGE = true,
	SQLITE_NOTADB = true,
	SQLITE_NOTICE = true,
	SQLITE_WARNING = true,
	SQLITE_ROW = true,
	SQLITE_DONE = true,
}

-- Authorizer action codes (sqlite3_set_authorizer callback).
local AUTHORIZER_ACTIONS = {
	SQLITE_CREATE_INDEX = true,
	SQLITE_CREATE_TABLE = true,
	SQLITE_CREATE_TEMP_INDEX = true,
	SQLITE_CREATE_TEMP_TABLE = true,
	SQLITE_CREATE_TEMP_TRIGGER = true,
	SQLITE_CREATE_TEMP_VIEW = true,
	SQLITE_CREATE_TRIGGER = true,
	SQLITE_CREATE_VIEW = true,
	SQLITE_DELETE = true,
	SQLITE_DROP_INDEX = true,
	SQLITE_DROP_TABLE = true,
	SQLITE_DROP_TEMP_INDEX = true,
	SQLITE_DROP_TEMP_TABLE = true,
	SQLITE_DROP_TEMP_TRIGGER = true,
	SQLITE_DROP_TEMP_VIEW = true,
	SQLITE_DROP_TRIGGER = true,
	SQLITE_DROP_VIEW = true,
	SQLITE_INSERT = true,
	SQLITE_PRAGMA = true,
	SQLITE_READ = true,
	SQLITE_SELECT = true,
	SQLITE_TRANSACTION = true,
	SQLITE_UPDATE = true,
	SQLITE_ATTACH = true,
	SQLITE_DETACH = true,
	SQLITE_ALTER_TABLE = true,
	SQLITE_REINDEX = true,
	SQLITE_ANALYZE = true,
	SQLITE_CREATE_VTABLE = true,
	SQLITE_DROP_VTABLE = true,
	SQLITE_FUNCTION = true,
	SQLITE_SAVEPOINT = true,
	SQLITE_COPY = true,
	SQLITE_RECURSIVE = true,
}

local AUTHORIZER_RESULTS = {
	SQLITE_DENY = true,
	SQLITE_IGNORE = true,
}

local DATATYPES = {
	SQLITE_INTEGER = true,
	SQLITE_FLOAT = true,
	SQLITE_TEXT = true,
	SQLITE_BLOB = true,
	SQLITE_NULL = true,
}

local TEXT_ENCODINGS = {
	SQLITE_UTF8 = true,
	SQLITE_UTF16LE = true,
	SQLITE_UTF16BE = true,
	SQLITE_UTF16 = true,
	SQLITE_ANY = true,
	SQLITE_UTF16_ALIGNED = true,
	SQLITE_UTF8_ZT = true,
}

-- Conflict-resolution codes used by e.g. ON CONFLICT (ABORT/IGNORE shared
-- with result/authorizer enums and claimed there first).
local CONFLICT_ACTIONS = {
	SQLITE_ROLLBACK = true,
	SQLITE_FAIL = true,
	SQLITE_REPLACE = true,
}

local function set_include(set)
	return function(m)
		return set[m.name] == true
	end
end

-- Prefix-scoped integer macros → named enum. member_strip_prefix defaults to
-- the same prefix so Open_Flag.Readonly rather than Open_Flag.Open_Readonly.
local function prefix_enum(id, name, prefix, opts)
	opts = opts or {}
	return h2o.macro_group.enum {
		id = id,
		name = name,
		base_type = "c.int",
		prefix = prefix,
		member_strip_prefix = opts.strip or prefix,
		emit_original_consts = false,
		include = opts.include,
	}
end

local config = h2o.config()
config.package = "sqlite3"
config.type_mode = "idiomatic"
config.comments = false

-- Paths are relative to this config file's directory.
config.inputs = { "sqlite3.h" }
config.output_folder = "."
config.foreign.import_lib = "sqlite3"
config.foreign.link_prefix = "sqlite3_"

config.naming = h2o.naming.odin {
	-- Longer / more specific prefixes first (first match wins).
	strip_prefixes = {
		proc = "sqlite3_",
		type = { "sqlite3_", "sqlite3", "sqlite_" },
	},
	-- Fts5Tokenizer (opaque instance) and fts5_tokenizer (method table) both
	-- become Fts5_Tokenizer under Ada_Case; keep the vtable distinct.
	overrides = {
		fts5_tokenizer = "Fts5_Tokenizer_Methods",
	},
	-- https://github.com/odin-lang/examples/wiki/Naming-and-style-convention
	override = function(sym)
		if sym.kind == "proc" or sym.kind == "var" or sym.kind == "field" then
			return h2o.naming.snake_case(sym.default)
		end
		if sym.kind == "type" or sym.kind == "enum_value" then
			return h2o.naming.ada_case(sym.default)
		end
		-- const: keep C SCREAMING_SNAKE (including SQLITE_ prefix on leftovers)
		return nil
	end,
}

-- Use sites become native i64/u64; drop the C typedef aliases so stripped
-- names (Int64 / Uint64) do not collide across sqlite_int64 vs sqlite3_int64.
config.types.map = {
	sqlite_int64  = "i64",
	sqlite3_int64 = "i64",
	sqlite_uint64 = "u64",
	sqlite3_uint64 = "u64",
}
config.symbols.remove.names = {
	"sqlite_int64", "sqlite3_int64", "sqlite_uint64", "sqlite3_uint64",
	-- Unprefixed aliases of SQLITE_CARRAY_* (same values; enum is Carray_Type).
	"CARRAY_INT32", "CARRAY_INT64", "CARRAY_DOUBLE", "CARRAY_TEXT", "CARRAY_BLOB",
}

-- First-match claims a macro; order matters when names could fit more than one
-- group (Result_Code whitelist before prefix families is enough in practice).
config.macros.groups = {
	h2o.macro_group.enum {
		id = "result_code",
		name = "Result_Code",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(RESULT_CODES),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},

	-- Open flags, lock levels, I/O caps, sync, fcntl opcodes, …
	prefix_enum("open_flag", "Open_Flag", "SQLITE_OPEN_"),
	prefix_enum("iocap", "Io_Capability", "SQLITE_IOCAP_"),
	prefix_enum("lock", "Lock_Level", "SQLITE_LOCK_"),
	prefix_enum("sync", "Sync_Flag", "SQLITE_SYNC_"),
	prefix_enum("fcntl", "Fcntl_Opcode", "SQLITE_FCNTL_"),
	prefix_enum("access", "Access_Mode", "SQLITE_ACCESS_"),
	prefix_enum("shm", "Shm_Flag", "SQLITE_SHM_", {
		-- NLOCK is a count of lock bytes, not a flag bit.
		include = function(m) return m.name ~= "SQLITE_SHM_NLOCK" end,
	}),
	prefix_enum("checkpoint", "Checkpoint_Mode", "SQLITE_CHECKPOINT_"),
	prefix_enum("config", "Config_Opcode", "SQLITE_CONFIG_"),
	prefix_enum("dbconfig", "Db_Config", "SQLITE_DBCONFIG_"),
	prefix_enum("limit", "Limit", "SQLITE_LIMIT_"),
	prefix_enum("status", "Status", "SQLITE_STATUS_"),
	prefix_enum("dbstatus", "Db_Status", "SQLITE_DBSTATUS_"),
	prefix_enum("stmtstatus", "Stmt_Status", "SQLITE_STMTSTATUS_"),
	prefix_enum("trace", "Trace_Flag", "SQLITE_TRACE_"),
	prefix_enum("prepare", "Prepare_Flag", "SQLITE_PREPARE_"),
	prefix_enum("txn", "Txn_State", "SQLITE_TXN_"),
	prefix_enum("serialize", "Serialize_Flag", "SQLITE_SERIALIZE_"),
	prefix_enum("deserialize", "Deserialize_Flag", "SQLITE_DESERIALIZE_"),
	prefix_enum("vtab", "Vtab_Config", "SQLITE_VTAB_"),
	prefix_enum("index_scan", "Index_Scan", "SQLITE_INDEX_SCAN_"),
	-- Not Index_Constraint: that name is already the xBestIndex constraint struct.
	prefix_enum("index_constraint_op", "Index_Constraint_Op", "SQLITE_INDEX_CONSTRAINT_"),
	prefix_enum("scanstat", "Scanstat", "SQLITE_SCANSTAT_", {
		-- COMPLEX is a flags bit for sqlite3_stmt_scanstatus_v2, not an index.
		include = function(m) return m.name ~= "SQLITE_SCANSTAT_COMPLEX" end,
	}),
	-- Not Mutex: that name is the opaque sqlite3_mutex handle type.
	prefix_enum("mutex_type", "Mutex_Type", "SQLITE_MUTEX_"),
	prefix_enum("testctrl", "Testctrl", "SQLITE_TESTCTRL_"),
	prefix_enum("carray", "Carray_Type", "SQLITE_CARRAY_"),

	h2o.macro_group.enum {
		id = "authorizer_action",
		name = "Authorizer_Action",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(AUTHORIZER_ACTIONS),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
	h2o.macro_group.enum {
		id = "authorizer_result",
		name = "Authorizer_Result",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(AUTHORIZER_RESULTS),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
	h2o.macro_group.enum {
		id = "datatype",
		name = "Datatype",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(DATATYPES),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
	h2o.macro_group.enum {
		id = "text_encoding",
		name = "Text_Encoding",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(TEXT_ENCODINGS),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
	h2o.macro_group.enum {
		id = "conflict_action",
		name = "Conflict_Action",
		base_type = "c.int",
		prefix = "SQLITE_",
		include = set_include(CONFLICT_ACTIONS),
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
}

return config
