-- Example config for fff.h.
--
-- Odin naming (examples wiki): Ada_Case types, snake_case procs/fields,
-- SCREAMING_SNAKE constants. Library prefixes are stripped so the package
-- name carries the namespace (FffResult → Result, fff_search → search,
-- FFF_CREATE_OPTIONS_VERSION → CREATE_OPTIONS_VERSION). foreign.link_prefix
-- keeps C symbols resolving without per-decl link_name.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "fff"
config.type_mode = "idiomatic"

-- Paths are relative to this config file's directory.
config.inputs = { "fff.h" }
config.output_folder = "."
config.foreign.import_lib = "fff"
config.foreign.link_prefix = "fff_"

config.naming = h2o.naming.odin {
	strip_prefixes = {
		proc = "fff_",
		type = "Fff",
		const = "FFF_",
	},
	-- https://github.com/odin-lang/examples/wiki/Naming-and-style-convention
	override = function(sym)
		if sym.kind == "proc" or sym.kind == "var" or sym.kind == "field" then
			return h2o.naming.snake_case(sym.default)
		end
		if sym.kind == "type" or sym.kind == "enum_value" then
			return h2o.naming.ada_case(sym.default)
		end
		-- const: leave stripped C form (already SCREAMING_SNAKE for these macros)
		return nil
	end,
}

-- cbindgen uses mutable `char *` for owned strings. The header documents
-- these fields as strings (and the context fields as arrays of strings), so
-- their NUL-terminated meaning is known even though constness cannot prove it.
config.structs.fields = {
	["FffResult.error"] = { type = "cstring" },
	["FffFileItem.relative_path"] = { type = "cstring" },
	["FffFileItem.file_name"] = { type = "cstring" },
	["FffFileItem.git_status"] = { type = "cstring" },
	["FffScore.match_type"] = { type = "cstring" },
	["FffGrepMatch.relative_path"] = { type = "cstring" },
	["FffGrepMatch.file_name"] = { type = "cstring" },
	["FffGrepMatch.git_status"] = { type = "cstring" },
	["FffGrepMatch.line_content"] = { type = "cstring" },
	["FffGrepMatch.context_before"] = { type = "[^]cstring" },
	["FffGrepMatch.context_after"] = { type = "[^]cstring" },
	["FffGrepResult.regex_fallback_error"] = { type = "cstring" },
	["FffDirItem.relative_path"] = { type = "cstring" },
	["FffDirItem.dir_name"] = { type = "cstring" },
	["FffMixedItem.relative_path"] = { type = "cstring" },
	["FffMixedItem.display_name"] = { type = "cstring" },
	["FffMixedItem.git_status"] = { type = "cstring" },
}

-- The parameter is documented as a C string allocated by this library.
config.procs.params = {
	["fff_free_string.s"] = { type = "cstring" },
}

return config
