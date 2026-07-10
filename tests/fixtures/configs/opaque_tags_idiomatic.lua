-- Idiomatic mode collapses incomplete tags by default (no types.opaque).
local h2o = require "h2odin"
local config = h2o.config()
config.package = "opaque_tags"
config.type_mode = "idiomatic"
config.foreign.import_lib = "opaque_tags"
config.inputs = { "../opaque_tags.h" }
return config
