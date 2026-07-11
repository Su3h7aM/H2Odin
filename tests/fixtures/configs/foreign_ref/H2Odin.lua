local h2o = require "h2odin"

local config = h2o.config()
config.package = "foreign_ref"
config.foreign.import_lib = "foreign_ref"
config.inputs = { "input.h" }
config.preprocess.include_paths = { "." }
config.output_folder = "."
config.type_mode = "abi"

return config
