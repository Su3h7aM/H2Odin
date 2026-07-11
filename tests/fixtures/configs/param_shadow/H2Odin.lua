local h2o = require "h2odin"

local config = h2o.config()
config.package = "param_shadow"
config.foreign.import_lib = "param_shadow"
config.inputs = { "input.h" }
config.output_folder = "."
config.type_mode = "idiomatic"

config.naming.strip_prefixes = {
	proc = "curl_",
	type = "curl_",
}

return config
