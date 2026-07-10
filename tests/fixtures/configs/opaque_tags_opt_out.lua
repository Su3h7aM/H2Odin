-- Idiomatic mode + override keeps one tag faithful.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "opaque_tags"
config.type_mode = "idiomatic"
config.foreign.import_lib = "opaque_tags"
config.inputs = { "../opaque_tags.h" }
config.types.opaque = { Opaque_Tag = false }
return config
