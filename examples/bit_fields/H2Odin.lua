local h2o = require "h2odin"
local config = h2o.config()
config.package = "bit_fields"
config.foreign.import_lib = "example"
config.inputs = { "options.h" }
config.output_folder = "."
return config
