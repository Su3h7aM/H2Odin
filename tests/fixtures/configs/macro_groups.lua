local h2o = require "h2odin"

local config = h2o.config()
config.package = "macro_groups"
config.foreign.import_lib = "macro_groups"

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

config.inputs = { "../macro_groups.h" }
return config
