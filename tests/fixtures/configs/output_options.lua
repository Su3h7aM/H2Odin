local h2o = require "h2odin"

local config = h2o.config()
config.package = "output_options"
config.foreign.import_lib = "output_options"
config.output.procedures_at_end = false
config.output.footer_per_header = true
config.inputs = { "../add.h" }
return config
