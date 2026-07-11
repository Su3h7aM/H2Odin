local h2o = require "h2odin"

local config = h2o.config()
config.package = "field_shadow"
config.foreign.import_lib = "field_shadow"
config.inputs = { "input.h" }
config.output_folder = "."
config.type_mode = "idiomatic"

config.naming.strip_prefixes = {
	type = "ma_",
	enum_value = "FMT_",
}

return config
