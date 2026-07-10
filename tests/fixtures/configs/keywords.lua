-- Keyword-safe default renames.
local h2o = require "h2odin"
local config = h2o.config()
config.inputs = { "../keywords.h" }
return config
