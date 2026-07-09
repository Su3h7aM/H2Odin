-- Example config for fff.h.
--
-- Demonstrates idiomatic leaves plus Milestone 10 foreign.link_prefix: strip
-- the fff_ procedure prefix for Odin names while the foreign block still
-- resolves the original C symbols. Constants keep the FFF_ prefix stripped
-- at the const naming tier.

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
		const = "FFF_",
	},
}

return config
