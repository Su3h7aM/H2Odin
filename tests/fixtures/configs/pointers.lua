-- Pointer lowering diagnostics.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../pointers.h" }
return config
