-- One callback expresses a whole renaming policy; nil keeps the default.
return {
	rename = function(sym)
		if sym.kind == "function" then
			return "lib_" .. sym.name
		end
		if sym.kind == "enum_member" and sym.parent == "Color" then
			return sym.name:gsub("^RED", "Red"):gsub("^GREEN", "Green"):gsub("^BLUE", "Blue")
		end
		return nil
	end,
}
