package h2odin

import "base:runtime"
import "core:c"

import lua "vendor:lua/5.4"

// proc "c" shims that register pure Odin algorithms into the Lua VM
// (h2o.str.*, h2o.naming.*, macro-view methods). Algorithms themselves live
// in naming.odin / str.odin / macro_value.odin.

policy_lua_str_has_prefix :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	prefix := policy_lua_check_string(L, 2)
	lua.pushboolean(L, b32(str_has_prefix(s, prefix)))
	return 1
}

policy_lua_str_has_suffix :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	suffix := policy_lua_check_string(L, 2)
	lua.pushboolean(L, b32(str_has_suffix(s, suffix)))
	return 1
}

policy_lua_str_strip_prefix :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	prefix := policy_lua_check_string(L, 2)
	policy_lua_push_string(L, str_strip_prefix(s, prefix))
	return 1
}

policy_lua_str_strip_suffix :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	suffix := policy_lua_check_string(L, 2)
	policy_lua_push_string(L, str_strip_suffix(s, suffix))
	return 1
}

// h2o.naming.snake_case(s) / ada_case(s) — no known_tokens from Lua; the
// generator passes its dictionary only on the Odin automatic-naming path.
// Users who need known_tokens in a callback set naming.known_tokens and rely
// on sym.default (already tokenized with that dictionary).
policy_lua_naming_snake_case :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	result, _ := naming_snake_case(s, nil, context.temp_allocator)
	policy_lua_push_string(L, result)
	return 1
}

policy_lua_naming_ada_case :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	s := policy_lua_check_string(L, 1)
	result, _ := naming_ada_case(s, nil, context.temp_allocator)
	policy_lua_push_string(L, result)
	return 1
}

policy_lua_macro_is_integer :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	// Method form: m:is_integer() → self at arg 1.
	if !lua.istable(L, 1) {
		lua.pushboolean(L, false)
		return 1
	}
	lua.getfield(L, 1, "value")
	is_int := lua.isnumber(L, -1)
	lua.pop(L, 1)
	lua.pushboolean(L, b32(is_int))
	return 1
}

policy_lua_macro_has_prefix :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	if !lua.istable(L, 1) {
		lua.pushboolean(L, false)
		return 1
	}
	lua.getfield(L, 1, "name")
	name := string(lua.tostring(L, -1))
	lua.pop(L, 1)
	prefix := policy_lua_check_string(L, 2)
	lua.pushboolean(L, b32(str_has_prefix(name, prefix)))
	return 1
}
