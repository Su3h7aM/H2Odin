local h2o = require "h2odin"
local config = h2o.config()

config.package = "roots_auto_layout"
config.foreign.import_lib = "roots_auto_layout"
config.inputs = { "../multi_header_a.h", "../multi_header_b.h" }
config.output_folder = "/tmp/h2odin-roots-auto-layout"

return config
