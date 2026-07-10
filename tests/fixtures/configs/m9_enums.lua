local h2o = require "h2odin"

local config = h2o.config()
config.package = "m9_enums"
config.foreign.import_lib = "m9_enums"

config.enums.anonymous = {
	h2o.enum.anonymous { name = "Keyboard_Key", first_member = "KEY_NULL" },
}

config.enums.member = function(member)
	if h2o.str.has_suffix(member.name, "_COUNT") then
		return { remove = true }
	end
	return nil
end

config.enums.bit_sets = {
	h2o.enum.bit_set { enum = "Config_Flag", name = "Config_Flags", mode = "log2" },
}

config.naming = h2o.naming.odin {
	strip_prefixes = {
		enum_value = { "FLAG_", "KEY_" },
	},
}

config.inputs = { "../m9_enums.h" }
return config
