-- Declarative settings only: the common case needs no callbacks.
local h2o = require "h2odin"

local config = h2o.config()
config.package = "mylib"
config.foreign.import_lib = "mylib_native"
config.type_mode = "idiomatic"
return config
