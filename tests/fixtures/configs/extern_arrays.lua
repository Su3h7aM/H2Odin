-- Incomplete extern array diagnostics.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../extern_arrays.h" }
return config
