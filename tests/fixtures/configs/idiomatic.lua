-- Idiomatic leaf-type ladder fixture.
local h2o = require "h2odin"
local config = h2o.config()
config.type_mode = "idiomatic"
config.inputs = { "../idiomatic.h" }
return config
