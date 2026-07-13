-- Semantic Deprecated: lines survive comments = false.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "deprecated"
config.foreign.import_lib = "deprecated"
config.comments = false
config.inputs = { "../deprecated.h" }
return config
