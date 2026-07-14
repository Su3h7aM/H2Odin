local h2o = require "h2odin"
local config = h2o.config()

config.package = "roots_diamond"
config.foreign.import_lib = "roots_diamond"
config.inputs = { "../roots_diamond/a.h", "../roots_diamond/b.h" }
config.output_folder = "/tmp/h2odin-roots-diamond-error"
config.diagnostics.header_ownership_conflict = "error"

return config
