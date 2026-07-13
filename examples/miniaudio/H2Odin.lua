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
	-- Fields named like package types (format, thread, log, …) break Odin
	-- when the same type is used again in the same record body.
	override = function(sym)
		if sym.kind == "field" then
			local n = sym.default
			if n == "format" or n == "thread" or n == "log" then
				return n .. "_"
			end
		end
	end,
}

-- Config structs are call-borrowed into init (vendor:miniaudio uses #by_ptr
-- on several of these). Result codes are required.
config.procs.params = {
	["ma_device_init.pConfig"] = { by_ptr = true },
	["ma_device_init_ex.pConfig"] = { by_ptr = true },
	["ma_context_init.pConfig"] = { by_ptr = true },
	["ma_decoder_init.pConfig"] = { by_ptr = true },
	["ma_encoder_init.pConfig"] = { by_ptr = true },
}
config.procs.require_results = {
	"ma_device_init",
	"ma_device_init_ex",
	"ma_device_start",
	"ma_device_stop",
	"ma_context_init",
	"ma_decoder_init",
	"ma_decoder_read_pcm_frames",
	"ma_encoder_init",
	"ma_engine_init",
}

return config
