-- Declarative shortcuts: no callbacks needed for the common case.
return {
	strip_prefixes = { func = "gl_", type = "gl_", const = "GL_" },
	type_map = { gl_Vector2 = "[2]f32" },
}
