-- Validation benchmark: cgltf vs Odin vendor:cgltf.
--
-- Exercises: single-header library, dense pointer graphs (glTF scene
-- graph), many small enums, size_t/float typedef aliases, cgltf_ prefix.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "cgltf"
config.type_mode = "idiomatic"
-- The upstream API is one header; the vendor package's extra wasm file is a
-- target-specific binding concern rather than another declaration root.
config.inputs = { "cgltf.h" }
config.output_folder = "."
config.foreign.import_lib = "cgltf"
-- Official vendor:cgltf keeps the full cgltf_ names on many symbols.
-- Stripping type prefixes (cgltf_size → size, cgltf_image → image) collides
-- with field names of the same spelling and yields illegal Odin cycles —
-- documented as a validation finding; do not strip types here.
config.foreign.link_prefix = "cgltf_"

config.naming = {
	strip_prefixes = {
		proc = "cgltf_",
		-- type deliberately unstripped (see README)
		const = "cgltf_",
		enum_value = "cgltf_",
	},
}

-- vendor:cgltf style: options as #by_ptr, parse results required.
config.procs.params = {
	["cgltf_parse.options"] = { by_ptr = true },
	["cgltf_parse_file.options"] = { by_ptr = true },
	["cgltf_load_buffers.options"] = { by_ptr = true },
	["cgltf_load_buffer_base64.options"] = { by_ptr = true },
}
config.procs.require_results = {
	"cgltf_parse",
	"cgltf_parse_file",
	"cgltf_load_buffers",
	"cgltf_load_buffer_base64",
	"cgltf_validate",
}

-- vendor:cgltf-style out-parameter → multi-result wrappers.
-- Faithful foreign decls remain under _name; public API is the wrapper.
config.procs.wrappers = {
	cgltf_parse = h2o.proc.wrapper {
		out_params = { "out_data" },
	},
	cgltf_parse_file = h2o.proc.wrapper {
		out_params = { "out_data" },
	},
	cgltf_load_buffer_base64 = h2o.proc.wrapper {
		out_params = { "out_data" },
	},
}

return config
