-- Validation benchmark: cgltf vs Odin vendor:cgltf.
--
-- Exercises: single-header library, dense pointer graphs (glTF scene
-- graph), many small enums, size_t/float typedef aliases, cgltf_ prefix.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "cgltf"
config.type_mode = "idiomatic"
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

return config
