local h2o = require "h2odin"
local config = h2o.config()

config.package = "roots_external"
config.foreign.import_lib = "roots_external"
config.inputs = { "../roots_external/root.h" }

return config
