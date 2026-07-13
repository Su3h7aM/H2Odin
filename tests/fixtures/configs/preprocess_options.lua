local h2o = require "h2odin"

local config = h2o.config()
config.package = "preprocess_options"
config.foreign.import_lib = "preprocess_options"
config.inputs = { "../preprocess_options.h" }
config.preprocess.include_paths = { "../include" }
config.preprocess.defines = { FEATURE_ENABLED = "1" }
return config
