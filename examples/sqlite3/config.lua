-- Example config for sqlite3.h.
--
-- Odin naming (examples wiki): Ada_Case types and enum values, snake_case
-- procs/fields, SCREAMING_SNAKE constants. Library prefixes are stripped so
-- the package carries the namespace (sqlite3_stmt → Stmt, sqlite3_open → open).
-- The bare handle `sqlite3` cannot strip to empty, so it stays Sqlite3.
-- foreign.link_prefix + proc strip omit per-decl link_name when
-- C name == prefix + Odin name. types.map rewrites 64-bit typedefs at use
-- sites; those typedef decls are removed as pure aliases. A macro group
-- turns core result codes into Result_Code.

local h2o = require "h2odin"

local sqlite_non_result_prefixes = {
	"SQLITE_OPEN_", "SQLITE_CONFIG_", "SQLITE_DBCONFIG_",
	"SQLITE_LIMIT_", "SQLITE_STATUS_", "SQLITE_DBSTATUS_",
	"SQLITE_STMTSTATUS_", "SQLITE_IOCAP_", "SQLITE_LOCK_",
	"SQLITE_SYNC_", "SQLITE_TRACE_", "SQLITE_FCNTL_",
	"SQLITE_ACCESS_", "SQLITE_SHM_", "SQLITE_CHECKPOINT_",
	"SQLITE_VTAB_", "SQLITE_INDEX_", "SQLITE_CONSTRAINT_",
	"SQLITE_SCANSTAT_", "SQLITE_SERIALIZE_", "SQLITE_DESERIALIZE_",
	"SQLITE_PREPARE_", "SQLITE_DETERMINISTIC", "SQLITE_DIRECTONLY",
	"SQLITE_SUBTYPE", "SQLITE_INNOCUOUS", "SQLITE_RESULT_SUBTYPE",
	"SQLITE_SELFORDER1", "SQLITE_WIN32_DATA_DIRECTORY_TYPE",
	"SQLITE_WIN32_TEMP_DIRECTORY_TYPE", "SQLITE_TXN_",
	"SQLITE_NOTICE_", "SQLITE_WARNING_", "SQLITE_ERROR_",
	"SQLITE_IOERR_", "SQLITE_LOCKED_", "SQLITE_BUSY_",
	"SQLITE_CANTOPEN_", "SQLITE_CORRUPT_", "SQLITE_READONLY_",
	"SQLITE_ABORT_", "SQLITE_CONSTRAINT_",
}

local config = h2o.config()
config.package = "sqlite3"
config.type_mode = "idiomatic"
config.comments = false

-- Paths are relative to this config file's directory.
config.inputs = { "sqlite3.h" }
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
		-- const: keep C SCREAMING_SNAKE (including SQLITE_ prefix on flags, etc.)
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
}

config.macros.groups = {
	h2o.macro_group.enum {
		id = "result_code",
		name = "Result_Code",
		base_type = "c.int",
		prefix = "SQLITE_",
		exclude_prefixes = sqlite_non_result_prefixes,
		include = function(m)
			return m:is_integer()
				and (m.value <= 100 or m.name == "SQLITE_ROW" or m.name == "SQLITE_DONE")
		end,
		member_strip_prefix = "SQLITE_",
		emit_original_consts = false,
	},
}

return config
