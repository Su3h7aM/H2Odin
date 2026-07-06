-- Filtering: false drops a declaration, nil keeps the default (keep).
return {
	keep = function(sym)
		if sym.name:match("^internal_") then
			return false
		end
		return nil
	end,
}
