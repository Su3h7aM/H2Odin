-- One callback expresses a whole renaming policy; nil keeps the default.
local h2o = require "h2odin"

local config = h2o.config()
config.naming.override = function(sym)
	if sym.kind == "proc" then
		return "lib_" .. sym.name
	end
	if sym.kind == "enum_value" and sym.parent == "Color" then
		return sym.name:gsub("^RED", "Red"):gsub("^GREEN", "Green"):gsub("^BLUE", "Blue")
	end
	return nil
end
return config
