-- One callback expresses a whole renaming policy; nil keeps the default.
local h2o = require "h2odin"

local config = h2o.config()
config.naming.override = function(sym)
	if sym.kind == "type" and sym.name == "Color" then
		return "Colour"
	end
	if sym.kind == "proc" then
		return "lib_" .. sym.name
	end
	if sym.kind == "param" and sym.parent == "paint" and sym.name == "strength" then
		return "opacity"
	end
	if sym.kind == "enum_value" and sym.parent == "Color" then
		return sym.name:gsub("^RED", "Red"):gsub("^GREEN", "Green"):gsub("^BLUE", "Blue")
	end
	return nil
end
config.inputs = { "../enums.h" }
return config
