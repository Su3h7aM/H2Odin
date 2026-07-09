local h2o = require "h2odin"

local config = h2o.config()
config.package = "m10p"
config.foreign.import_lib = "m10p"
config.inputs = { "../m10_preprocess.h" }
config.preprocess.include_paths = { "../include" }
config.preprocess.defines = { M10_ENABLE = "1" }
return config
