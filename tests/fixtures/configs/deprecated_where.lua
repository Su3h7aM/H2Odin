-- Spec 0009: sym.deprecated in a where predicate.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "deprecated"
config.foreign.import_lib = "deprecated"
config.inputs = { "../deprecated.h" }
config.symbols.remove.where = function(sym)
	return sym.deprecated
end
return config
