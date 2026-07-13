-- Exercise unsupported calling-convention diagnostics.
-- vectorcall is present in the header and must fail with unsupported_calling_conv.
local h2o = require "h2odin"
local config = h2o.config()

config.package = "calling_conv"
config.inputs = { "../calling_conv.h" }
config.foreign.import_lib = "c"

return config
