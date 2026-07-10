local h2o = require "h2odin"
local config = h2o.config()
config.package = "opaque_handles"
config.foreign.import_lib = "opaque_handles"
config.inputs = { "../opaque_handles.h" }
-- Opt the void* handle into distinct; leave Void_Plain as a plain alias.
config.types.distinct = { "Void_Handle" }
return config
