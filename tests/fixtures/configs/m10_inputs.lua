local h2o = require "h2odin"

local config = h2o.config()
config.package = "m10i"
config.foreign.import_lib = "m10i"
-- Relative to this config file's directory (tests/fixtures/configs/).
config.inputs = { "../m10_a.h", "../m10_b.h" }
return config
