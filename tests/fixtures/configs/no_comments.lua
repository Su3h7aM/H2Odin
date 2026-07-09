local h2o = require "h2odin"

local config = h2o.config()
config.package = "docs"
config.foreign.import_lib = "docs"
config.comments = false
return config
