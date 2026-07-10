-- ABI mode: incomplete tags stay faithful (struct {} + ^T) by default.
local h2o = require "h2odin"
local config = h2o.config()
config.package = "opaque_tags"
config.type_mode = "abi"
config.foreign.import_lib = "opaque_tags"
config.inputs = { "../opaque_tags.h" }
return config
