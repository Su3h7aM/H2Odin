-- Spec 0009: symbols.remove.deprecated drops all C-deprecated decls.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "deprecated"
config.foreign.import_lib = "deprecated"
config.inputs = { "../deprecated.h" }
config.symbols.remove.deprecated = true
return config
