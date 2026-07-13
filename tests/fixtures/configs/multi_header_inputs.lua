local h2o = require "h2odin"

local config = h2o.config()
config.package = "m10i"
config.foreign.import_lib = "m10i"
-- Relative to this config file's directory (tests/fixtures/configs/).
config.inputs = { "../multi_header_a.h", "../multi_header_b.h" }
return config
