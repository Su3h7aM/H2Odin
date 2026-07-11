-- Validation benchmark: libcurl vs Odin vendor:curl (vendor_curl).
--
-- Exercises: multi-header umbrella, opaque void* handles (CURL), massive
-- CURLOPT_*/CURLINFO_* option space (enums + macros), callbacks with
-- function-pointer typedefs, platform socket typedefs, deprecation attrs.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "curl"
config.type_mode = "idiomatic"
config.inputs = { "include/curl.h" }
config.preprocess.include_paths = { "include" }
config.output_folder = "."
config.foreign.import_lib = "curl"
config.foreign.link_prefix = "curl_"

config.naming = {
	strip_prefixes = {
		proc = "curl_",
		type = "curl_",
		const = "CURL_",
		enum_value = "CURL",
	},
}

-- WORKAROUND (do not treat as a fix): pure `typedef void CURL;` / CURLM /
-- CURLSH panic emission ("void type has no ABI spelling"). Dropping the
-- typedef decls lets uses peel toward void* → rawptr. Tracked on ROADMAP.
config.symbols.remove.names = {
	"CURL",
	"CURLSH",
	"CURLM",
}

return config
