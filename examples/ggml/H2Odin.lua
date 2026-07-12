-- Validation example: ggml (https://github.com/ggml-org/ggml).
--
-- Exercises: tensor/ML C API, multi-header (ggml + alloc + backend + cpu + gguf),
-- ggml_/GGML_ prefixes, opaque contexts, large enum surfaces, function pointers.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "ggml"
config.type_mode = "idiomatic"

config.inputs = {
	"include/ggml.h",
	"include/ggml-alloc.h",
	"include/ggml-backend.h",
	"include/ggml-cpu.h",
	"include/gguf.h",
}
config.preprocess.include_paths = { "include" }
config.output_folder = "."
config.output.layout = "merged"

config.foreign.import_lib = "ggml"
config.foreign.link_prefix = "ggml_"

config.naming = {
	strip_prefixes = {
		proc = { "ggml_", "gguf_" },
		type = { "ggml_", "gguf_" },
		const = { "GGML_", "GGUF_" },
		enum_value = { "GGML_", "GGUF_" },
	},
}

return config
