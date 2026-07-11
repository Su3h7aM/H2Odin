local h2o = require "h2odin"

local config = h2o.config()
config.package = "symbol_collision"
config.foreign.import_lib = "symbol_collision"
config.inputs = { "input.h" }
config.output_folder = "."
config.type_mode = "abi"

config.naming.strip_prefixes = {
	proc = { "gl_", "vk_" },
}

return config
