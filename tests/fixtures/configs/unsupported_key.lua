local h2o = require "h2odin"

local config = h2o.config()
-- "wrappers" is still a roadmap-only top-level key (not a section field).
config.wrappers = true
return config
