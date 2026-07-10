-- Idiomatic mode for add.h.
local h2o = require "h2odin"
local config = h2o.config()
config.type_mode = "idiomatic"
config.inputs = { "../add.h" }
return config
