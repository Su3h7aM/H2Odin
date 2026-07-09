-- Example config for sqlite3.h.
--
-- SQLite has a large, prefix-heavy C API. This strips the common function
-- prefix while leaving constants and typedef names conservative: bare
-- sqlite3 is an established public type name, and over-stripping every type
-- or every SQLITE_* constant can create less recognizable names or collisions.

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

local config = h2o.config()
config.package = "sqlite3"
config.foreign.import_lib = "sqlite3"
config.type_mode = "idiomatic"

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

return config
