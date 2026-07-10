-- Header that fails clang parse.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../bad_parse.h" }
return config
