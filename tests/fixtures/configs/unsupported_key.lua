local h2o = require "h2odin"

local config = h2o.config()
-- "wrappers" is invalid at the top level; wrapper rules live under procs.
config.wrappers = true
return config
