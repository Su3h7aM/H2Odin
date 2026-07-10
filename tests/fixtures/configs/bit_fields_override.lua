local h2o = require "h2odin"
local config = h2o.config()
config.package = "bit_fields"
config.foreign.import_lib = "bit_fields"
config.inputs = { "../bit_fields.h" }
config.structs.fields = {
  ["H2O_IndexOptions.Size"] = { type = "[16]u8" },
}
return config
