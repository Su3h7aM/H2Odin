-- Validation benchmark: libcurl vs Odin vendor:curl (vendor_curl).
--
-- Exercises: multi-header umbrella, opaque void* handles (CURL), massive
-- CURLOPT_*/CURLINFO_* option space (enums + macros), callbacks with
-- function-pointer typedefs, platform socket typedefs, deprecation attrs.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "curl"
config.type_mode = "idiomatic"
-- Only declarations whose home is a config.inputs path are emitted. curl.h
-- #includes easy.h / multi.h / urlapi.h, but those files are not "ours" unless
-- listed — and they cannot be listed alone (they need CURL_EXTERN / types from
-- curl.h). Curate require_results for symbols that actually live in curl.h.
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
	-- formadd(httppost: ^^httppost, last_post: ^^httppost) — the first
	-- parameter name shadows the type for later parameters (spec 0008).
	override = function(sym)
		if sym.kind == "param" and sym.default == "httppost" then
			return "httppost_"
		end
	end,
}

-- Honest subset: only procs declared in curl.h itself (not easy.h/multi.h).
-- vendor:curl marks many more; expanding the input surface is future work.
config.procs.require_results = {
	"curl_slist_append",
	"curl_global_init",
	"curl_share_init",
	"curl_mime_init",
	"curl_version_info",
	"curl_easy_escape",
	"curl_easy_unescape",
}

return config
