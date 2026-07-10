local h2o = require "h2odin"

local config = h2o.config()
config.package = "m14"
config.foreign.import_lib = "m14"
config.inputs = { "../m14_a.h", "../m14_b.h", "../m14_empty.h" }
-- Caller sets output_folder when writing to disk; e2e uses a temp path via a
-- generated config, or this default relative folder next to the config.
config.output_folder = "/tmp/h2odin-m14-out"
config.output.layout = "per_header"
return config
