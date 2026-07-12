-- Structured foreign.targets (Milestone 16 P1.1).
local h2o = require "h2odin"
local config = h2o.config()

config.package = "ftargs"
config.inputs = { "../add.h" }
config.foreign.targets = {
	windows = {
		libraries = { "lib/foo.lib" },
		system = { "user32.lib" },
	},
	linux_amd64 = {
		libraries = { "lib/libfoo.a" },
		system = { "m", "pthread" },
	},
	fallback = {
		libraries = { "system:foo" },
	},
}

return config
