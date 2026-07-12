-- Calling conventions that Odin can spell (drop vectorcall).
local h2o = require "h2odin"
local config = h2o.config()

config.package = "calling_conv"
config.inputs = { "../calling_conv.h" }
config.foreign.import_lib = "c"
config.symbols.remove.names = { "vectorcall_fn" }

return config
