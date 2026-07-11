-- Spec 0009: default run propagates deprecation.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "deprecated"
config.foreign.import_lib = "deprecated"
config.inputs = { "../deprecated.h" }
return config
