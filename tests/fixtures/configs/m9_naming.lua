local h2o = require "h2odin"

local config = h2o.config()
config.package = "m9_naming"
config.foreign.import_lib = "m9_naming"

config.naming = h2o.naming.odin {
	strip_prefixes = { proc = "lib_" },
	strip_suffixes = { type = "_t" },
	known_tokens = {
		SQLite3 = "sqlite3",
	},
	overrides = {
		lib_widget = "Widget",
	},
	override = function(sym)
		if sym.kind == "proc" and h2o.str.has_prefix(sym.name, "lib_special_") then
			return h2o.naming.snake_case(h2o.str.strip_prefix(sym.name, "lib_special_"))
		end
		return nil
	end,
}

config.symbols.remove.names = { "lib_internal" }
config.symbols.remove.patterns = { "*_COUNT" }

config.inputs = { "../m9_naming.h" }
return config
