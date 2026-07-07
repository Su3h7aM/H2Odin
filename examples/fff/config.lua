-- Example config for /tmp/fff.h.
--
-- This keeps the generated package idiomatic enough for normal Odin use:
-- fixed-width-safe C leaves become Odin leaves, and const char * lowers to
-- cstring without authored conversion code.

return {
	package = "fff",
	foreign_lib = "fff",

	type_mode = "idiomatic",

	strip_prefixes = {
		func = "fff_",
		const = "FFF_",
	},
}
