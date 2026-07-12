local h2o = require "h2odin"
local config = h2o.config()
config.package = "reqres"
config.inputs = { "../add.h" }
config.foreign.import_lib = "c"
-- Only add is in the header; block-level compression applies.
config.procs.require_results = { "add" }
return config
