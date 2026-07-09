-- Declarative shortcuts: no callbacks needed for the common case.
local h2o = require "h2odin"

local config = h2o.config()
config.naming = h2o.naming.odin {
	strip_prefixes = { proc = "gl_", type = "gl_", const = "GL_" },
}
config.types.overrides = { gl_Vector2 = "[2]f32" }
return config
