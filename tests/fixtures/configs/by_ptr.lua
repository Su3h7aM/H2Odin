local h2o = require "h2odin"
local config = h2o.config()
config.package = "by_ptr"
config.type_mode = "idiomatic"
config.inputs = { "../by_ptr.h" }
config.foreign.import_lib = "c"
config.procs.params = {
	["create.options"] = { by_ptr = true },
}
return config
