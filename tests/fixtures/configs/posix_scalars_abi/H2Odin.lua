local h2o = require "h2odin"
local config = h2o.config()
config.package = "posix_scalars"
config.foreign.import_lib = "posix_scalars"
config.inputs = { "input.h" }
config.preprocess.include_paths = { "." }
config.output_folder = "."
config.type_mode = "abi"
return config
