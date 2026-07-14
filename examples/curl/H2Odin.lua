-- Validation benchmark: libcurl vs Odin vendor:curl (vendor_curl).
--
-- Exercises: multi-header umbrella, opaque void* handles (CURL), massive
-- CURLOPT_*/CURLINFO_* option space (enums + macros), callbacks with
-- function-pointer typedefs, platform socket typedefs, deprecation attrs.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "curl"
config.type_mode = "idiomatic"
-- Keep libcurl's independently parseable public API areas as separate roots.
-- easy/header/options/websockets are only valid inside curl.h's umbrella
-- context, so they fold into the core unit alongside support headers. This is
-- the closest honest split to vendor:curl without patching upstream headers.
config.inputs = {
	"include/curl.h",
	"include/multi.h",
	"include/urlapi.h",
}
config.preprocess.include_paths = { "include" }
-- Directly parsing multi.h includes curl.h before multi.h's own declarations;
-- disable the convenience type-check macros so they do not rewrite those
-- declarations on the second half of that include cycle.
config.preprocess.defines = { CURL_DISABLE_TYPECHECK = "1" }
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
	-- parameter name shadows the type for later parameters.
	override = function(sym)
		if sym.kind == "param" and sym.default == "httppost" then
			return "httppost_"
		end
	end,
}

-- Curated subset of pointer-returning procedures across the folded umbrella.
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
