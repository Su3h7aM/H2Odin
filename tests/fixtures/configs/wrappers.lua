local h2o = require "h2odin"
local config = h2o.config()
config.package = "wrappers"
config.type_mode = "idiomatic"
config.inputs = { "../wrappers.h" }
config.foreign.import_lib = "c"
config.procs.wrappers = {
	parse = h2o.proc.wrapper {
		out_params = { "out_data" },
	},
	consume = h2o.proc.wrapper {
		slices = {
			{ pointer = "items", count = "count", name = "items" },
		},
	},
}
return config
