local h2o = require "h2odin"

local config = h2o.config()
config.package = "void_opaque"
config.foreign.import_lib = "void_opaque"
config.inputs = { "void_opaque.h" }
config.output_folder = "."
config.type_mode = "abi"

return config
