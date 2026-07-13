local h2o = require "h2odin"

local config = h2o.config()
config.package = "per_header_output"
config.foreign.import_lib = "per_header_output"
config.inputs = { "../per_header_a.h", "../per_header_b.h", "../per_header_empty.h" }
-- Caller sets output_folder when writing to disk; e2e uses a temp path via a
-- generated config, or this default relative folder next to the config.
config.output_folder = "/tmp/h2odin-per-header-output"
config.output.layout = "per_header"
return config
