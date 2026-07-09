-- Example config for sqlite3.h.
--
-- Demonstrates Milestone 8–10 config surface on a large, prefix-heavy C API:
-- foreign.link_prefix pairs with naming.strip_prefixes so stripped proc names
-- still resolve to the original C symbols without per-decl @(link_name);
-- types.map rewrites the well-known 64-bit typedefs at use sites; a macro
-- group turns the core result codes into an explicit-valued enum.

local h2o = require "h2odin"

local keep_sqlite_name = {
	sqlite3 = true,
	sqlite3_stmt = true,
	sqlite3_value = true,
	sqlite3_context = true,
	sqlite3_vfs = true,
	sqlite3_file = true,
	sqlite3_blob = true,
	sqlite3_backup = true,
	sqlite3_snapshot = true,
}

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

-- Paths are relative to this config file's directory.
config.inputs = { "sqlite3.h" }
config.foreign.import_lib = "sqlite3"
config.foreign.link_prefix = "sqlite3_"

config.naming = h2o.naming.odin {
	strip_prefixes = {
		proc = "sqlite3_",
	},
	override = function(sym)
		if sym.kind == "type" and keep_sqlite_name[sym.name] then
			return sym.name
		end
		return sym.default
	end,
}

-- Reference rewrites only (the typedef decls stay out of the way as opaque
-- C names if present; map changes every use site to a native spelling).
config.types.map = {
	sqlite_int64  = "i64",
	sqlite3_int64 = "i64",
	sqlite_uint64 = "u64",
	sqlite3_uint64 = "u64",
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
