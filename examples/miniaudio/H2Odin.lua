-- Validation benchmark: miniaudio vs Odin vendor:miniaudio.
--
-- Exercises: ~95k-line single-header (API-only path; no
-- MINIAUDIO_IMPLEMENTATION), ma_ prefix strip, huge config/device structs,
-- many callbacks, backend #ifdef maze, result codes, nested enums.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "miniaudio"
config.type_mode = "idiomatic"
config.inputs = { "miniaudio.h" }
config.output_folder = "."
config.foreign.import_lib = "miniaudio"
config.foreign.link_prefix = "ma_"

config.naming = {
	strip_prefixes = {
		proc = "ma_",
		type = "ma_",
		const = "MA_",
		enum_value = "ma_",
	},
}

-- WORKAROUND: pure `typedef void ma_*;` panics emission (same as curl).
-- Drop those opaque tags so generation can finish; uses become rawptr-ish.
-- Tracked on ROADMAP — not a proper opaque-handle solution.
config.symbols.remove.names = {
	"ma_resampling_backend",
	"ma_data_source",
	"ma_async_notification",
	"ma_vfs",
	"ma_node",
}

return config
