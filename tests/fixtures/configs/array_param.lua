local h2o = require "h2odin"
local config = h2o.config()
config.package = "array_param"
config.inputs = { "../array_param.h" }
config.foreign.import_lib = "c"
-- Explicit multi on a bare T* (no array form in the header).
config.procs.params = {
	["bare.p"] = { pointer = "multi" },
}
return config
