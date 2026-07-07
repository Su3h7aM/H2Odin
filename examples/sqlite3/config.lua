-- Example config for /tmp/sqlite3.h.
--
-- SQLite has a large, prefix-heavy C API. This strips the common function
-- prefix while leaving constants and typedef names conservative: bare
-- sqlite3 is an established public type name, and over-stripping every type
-- or every SQLITE_* constant can create less recognizable names or collisions.

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

return {
	package = "sqlite3",
	foreign_lib = "sqlite3",

	type_mode = "idiomatic",

	strip_prefixes = {
		func = "sqlite3_",
	},

	rename = function(sym)
		if sym.kind == "type" and keep_sqlite_name[sym.name] then
			return sym.name
		end
		return sym.default
	end,
}
