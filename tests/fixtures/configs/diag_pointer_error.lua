-- Raise pointer_lowering_guess to error; default posture for other categories stays warn.
local h2o = require "h2odin"
local config = h2o.config()
config.diagnostics = {
	pointer_lowering_guess = "error",
}
return config
