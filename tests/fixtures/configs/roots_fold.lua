local h2o = require "h2odin"
local config = h2o.config()

config.package = "roots_fold"
config.foreign.import_lib = "roots_fold"
config.inputs = { "../roots_fold/root.h" }

return config
