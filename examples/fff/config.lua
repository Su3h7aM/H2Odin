-- Example config for fff.h.
--
-- This keeps the generated package idiomatic enough for normal Odin use:
-- fixed-width-safe C leaves become Odin leaves, and const char * lowers to
-- cstring without authored conversion code.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "fff"
config.foreign.import_lib = "fff"
config.type_mode = "idiomatic"

config.naming = h2o.naming.odin {
	strip_prefixes = {
		proc = "fff_",
		const = "FFF_",
	},
}

return config
