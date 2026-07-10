-- Filtering: true drops a declaration (remove.where polarity).
local h2o = require "h2odin"

local config = h2o.config()
config.symbols.remove.where = function(sym)
	return h2o.str.has_prefix(sym.name, "internal_")
end
config.inputs = { "../filtering.h" }
return config
