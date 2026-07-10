-- Minimal ABI generation of add.h.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../add.h" }
return config
