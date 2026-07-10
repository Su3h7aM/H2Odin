-- Doc-comment emission defaults.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../docs.h" }
return config
