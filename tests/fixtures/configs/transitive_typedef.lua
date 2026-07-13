local h2o = require "h2odin"

local config = h2o.config()
config.package = "m13p"
config.foreign.import_lib = "m13p"
-- Only the main header is ours; the included typedef peels to the underlying type.
config.inputs = { "../transitive_typedef_main.h" }
return config
