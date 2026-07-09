local h2o = require "h2odin"

local config = h2o.config()
config.package = "m9_macros"
config.foreign.import_lib = "m9_macros"

config.macros.groups = {
	h2o.macro_group.enum {
		id = "result",
		name = "Result_Code",
		prefix = "LIB_",
		exclude_prefixes = { "LIB_OPEN_" },
		member_strip_prefix = "LIB_",
		emit_original_consts = false,
		include = function(m)
			return m:is_integer() and m.value <= 100
		end,
	},
}

return config
