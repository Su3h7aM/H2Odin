local h2o = require "h2odin"

local config = h2o.config()
config.package = "m10o"
config.foreign.import_lib = "m10o"
config.output.procedures_at_end = false
config.output.footer_per_header = true
return config
