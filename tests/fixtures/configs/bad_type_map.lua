-- Invalid types.overrides value type should fail the run with a clear error.
local h2o = require "h2odin"

local config = h2o.config()
config.types.overrides = { Foo = 42 }
return config
