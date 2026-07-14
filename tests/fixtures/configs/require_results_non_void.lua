local h2o = require "h2odin"
local config = h2o.config()
config.package = "reqres_mode"
config.inputs = { "../member_policies.h" }
config.foreign.import_lib = "c"
-- Mark every non-void foreign procedure; void procs stay unmarked.
config.procs.require_results = "non_void"
return config
