local h2o = require "h2odin"

local config = h2o.config()
config.package = "m13s"
config.foreign.import_lib = "m13s"
-- Both headers are "ours": the typedef in b must survive use sites in a.
config.inputs = { "../m13_sibling_a.h", "../m13_sibling_b.h" }
return config
