local h2o = require "h2odin"
local config = h2o.config()

config.package = "roots_nested"
config.foreign.import_lib = "roots_nested"
config.inputs = { "../roots_nested/a.h", "../roots_nested/b.h" }
config.output_folder = "/tmp/h2odin-roots-nested"

return config
