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

config.inputs = { "fff.h" }
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

return config
