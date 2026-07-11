package h2odin

import "core:c"
import "core:fmt"
import "core:strings"

import lua "vendor:lua/5.4"

// Generic Lua↔Odin marshalling used by section readers and callbacks.
// Stack conventions are documented on each procedure.

policy_lua_check_string :: proc(L: ^lua.State, arg: c.int) -> string {
	n: c.size_t
	ptr := lua.L_checkstring(L, arg, &n)
	if n == 0 || ptr == nil {
		return ""
	}
	return strings.string_from_ptr((^byte)(rawptr(ptr)), int(n))
}

policy_lua_push_string :: proc(L: ^lua.State, s: string) {
	if len(s) == 0 {
		lua.pushlstring(L, "", 0)
		return
	}
	lua.pushlstring(L, cstring(raw_data(s)), c.size_t(len(s)))
}

// Read a pure list of strings from parent[key]. Absent/nil → nil slice.
// Rejects non-array tables (string keys only).
policy_string_list_field :: proc(L: ^lua.State, table_name: string, field_key: cstring) -> (list: []string, ok: bool) {
	field_type := lua.getfield(L, -1, field_key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s.%s must be a list of strings", table_name, field_key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)
	return policy_read_string_list_at_top(L, table_name, field_key)
}

// Table at stack top is a string list. Validates a pure dense array (keys
// exactly 1..n, no hybrid string keys) and clones the string values.
policy_read_string_list_at_top :: proc(L: ^lua.State, table_name: string, field_key: cstring) -> (list: []string, ok: bool) {
	n := int(lua.L_len(L, -1))
	if !policy_require_pure_list(L, table_name, field_key, n) {
		return nil, false
	}
	if n == 0 {
		return nil, true
	}
	out := make([]string, n)
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.STRING) {
			fmt.eprintfln("h2odin: config: %s.%s[%d] must be a string", table_name, field_key, i + 1)
			lua.pop(L, 1)
			return nil, false
		}
		out[i] = strings.clone(string(lua.tostring(L, -1)))
		lua.pop(L, 1)
	}
	return out, true
}

// Table at stack top must be a dense sequence of length n: only integer keys
// 1..n (no holes, no hybrid string keys like { "a", typo = "b" }).
policy_require_pure_list :: proc(L: ^lua.State, table_name: string, field_key: cstring, n: int) -> bool {
	count := 0
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if !bool(lua.isinteger(L, -2)) {
			fmt.eprintfln("h2odin: config: %s.%s must be a pure list of strings (got a non-integer key)", table_name, field_key)
			lua.pop(L, 2)
			return false
		}
		idx := int(lua.tointeger(L, -2))
		if idx < 1 || idx > n {
			fmt.eprintfln("h2odin: config: %s.%s must be a dense list of strings (unexpected index %d; expected 1..%d)", table_name, field_key, idx, n)
			lua.pop(L, 2)
			return false
		}
		count += 1
		lua.pop(L, 1) // value; leave key for next
	}
	if count != n {
		fmt.eprintfln("h2odin: config: %s.%s must be a dense list of strings (length %d but %d entries)", table_name, field_key, n, count)
		return false
	}
	return true
}

// Read a map of "Parent.child" (or bare name for results) → action tables.
// Parent table is at stack top. Absent/nil → empty map.
policy_member_action_map :: proc(
	L: ^lua.State,
	parent_name: string,
	key: cstring,
	allow_tag: bool,
	allow_default: bool,
) -> (
	result: map[string]Member_Action,
	ok: bool,
) {
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s.%s must be a table", parent_name, key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	result = make(map[string]Member_Action)
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s.%s keys must be strings", parent_name, key)
			lua.pop(L, 2)
			return nil, false
		}
		map_key := strings.clone(string(lua.tostring(L, -2)))
		if !lua.istable(L, -1) {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must be a table", parent_name, key, map_key)
			lua.pop(L, 2)
			return nil, false
		}
		allowed := make([dynamic]cstring, context.temp_allocator)
		append(&allowed, "type")
		if allow_tag {
			append(&allowed, "tag")
		}
		if allow_default {
			append(&allowed, "default")
		}
		if !policy_reject_unknown_subkeys(L, fmt.tprintf("%s.%s[]", parent_name, key), allowed[:]) {
			lua.pop(L, 2)
			return nil, false
		}
		action: Member_Action
		type_s, type_ok := policy_optional_string_field(L, fmt.tprintf("%s.%s[]", parent_name, key), "type")
		if !type_ok {
			lua.pop(L, 2)
			return nil, false
		}
		action.type = type_s
		if allow_tag {
			tag_s, tag_ok := policy_optional_string_field(L, fmt.tprintf("%s.%s[]", parent_name, key), "tag")
			if !tag_ok {
				lua.pop(L, 2)
				return nil, false
			}
			action.tag = tag_s
		}
		if allow_default {
			def_s, def_ok := policy_optional_string_field(L, fmt.tprintf("%s.%s[]", parent_name, key), "default")
			if !def_ok {
				lua.pop(L, 2)
				return nil, false
			}
			action.default = def_s
		}
		if action.type == "" && action.tag == "" && action.default == "" {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must set at least one of type/tag/default", parent_name, key, map_key)
			lua.pop(L, 2)
			return nil, false
		}
		result[map_key] = action
		lua.pop(L, 1)
	}
	return result, true
}

// string → int map nested under parent (at stack top).
policy_int_map_nested :: proc(L: ^lua.State, parent_name: string, key: cstring) -> (result: map[string]int, ok: bool) {
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s.%s must be a table of integers", parent_name, key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	result = make(map[string]int)
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s.%s keys must be strings", parent_name, key)
			lua.pop(L, 2)
			return nil, false
		}
		map_key := strings.clone(string(lua.tostring(L, -2)))
		if !lua.isnumber(L, -1) {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must be an integer", parent_name, key, map_key)
			lua.pop(L, 2)
			return nil, false
		}
		n := int(lua.tointeger(L, -1))
		if n <= 0 {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must be a positive integer", parent_name, key, map_key)
			lua.pop(L, 2)
			return nil, false
		}
		result[map_key] = n
		lua.pop(L, 1)
	}
	return result, true
}

// Parent table at stack top; reject any string key not in allowed.
policy_reject_unknown_subkeys :: proc(L: ^lua.State, table_name: string, allowed: []cstring) -> bool {
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s keys must be strings", table_name)
			lua.pop(L, 2)
			return false
		}
		sub := string(lua.tostring(L, -2))
		if !config_key_in(sub, allowed) {
			fmt.eprintfln("h2odin: config: unknown %s key %q", table_name, sub)
			lua.pop(L, 2)
			return false
		}
		lua.pop(L, 1)
	}
	return true
}

// Parent table at stack top. Reject if nested key is present and not nil.
policy_reject_nested_if_set :: proc(L: ^lua.State, parent: string, key: cstring) -> bool {
	field_type := lua.getfield(L, -1, key)
	defer lua.pop(L, 1)
	if field_type == c.int(lua.Type.NIL) {
		return true
	}
	fmt.eprintfln("h2odin: config: %s.%s is not yet supported", parent, key)
	return false
}

// Internal field names avoid Odin keywords (`proc`, `const`); Lua keys are
// "proc" / "type" / "const" / "enum_value" as the config surface.
Strip_Kinds :: struct {
	procs:       []string,
	types:       []string,
	constants:   []string,
	enum_values: []string,
}

// Read naming.strip_prefixes or naming.strip_suffixes from the naming table
// at stack top. Each kind accepts a string or a list of strings.
policy_strip_kinds_from :: proc(L: ^lua.State, field_key: cstring) -> (kinds: Strip_Kinds, ok: bool) {
	path := fmt.tprintf("naming.%s", field_key)
	outer_type := lua.getfield(L, -1, field_key)
	if outer_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return {}, true
	}
	if outer_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s must be a table", path)
		lua.pop(L, 1)
		return {}, false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, path, STRIP_KIND_KEYS[:]) {
		return {}, false
	}

	field_ok: bool
	kinds.procs, field_ok = policy_string_or_list_field(L, path, "proc")
	if !field_ok {
		return {}, false
	}
	kinds.types, field_ok = policy_string_or_list_field(L, path, "type")
	if !field_ok {
		return {}, false
	}
	kinds.constants, field_ok = policy_string_or_list_field(L, path, "const")
	if !field_ok {
		return {}, false
	}
	kinds.enum_values, field_ok = policy_string_or_list_field(L, path, "enum_value")
	if !field_ok {
		return {}, false
	}
	return kinds, true
}

// Copies into context.allocator (generation arena during a normal run).
// A bare string is accepted as a one-element list; tables must be pure dense
// arrays (shared validation with policy_string_list_field).
policy_string_or_list_field :: proc(L: ^lua.State, table_name: string, field_key: cstring) -> (list: []string, ok: bool) {
	field_type := lua.getfield(L, -1, field_key)
	#partial switch lua.Type(field_type) {
	case .NIL:
		lua.pop(L, 1)
		return nil, true
	case .STRING:
		s := strings.clone(string(lua.tostring(L, -1)))
		lua.pop(L, 1)
		out := make([]string, 1)
		out[0] = s
		return out, true
	case .TABLE:
	// fall through
	case:
		fmt.eprintfln("h2odin: config: %s.%s must be a string or list of strings", table_name, field_key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)
	return policy_read_string_list_at_top(L, table_name, field_key)
}

push_string_field :: proc(L: ^lua.State, key: cstring, value: string) {
	lua.pushstring(L, strings.clone_to_cstring(value, context.temp_allocator))
	lua.setfield(L, -2, key)
}

policy_optional_string_top :: proc(policy: ^Policy, key: cstring) -> (value: string, ok: bool) {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return "", true
	}
	if field_type != c.int(lua.Type.STRING) {
		fmt.eprintfln("h2odin: config: %s must be a string", key)
		lua.pop(L, 1)
		return "", false
	}
	defer lua.pop(L, 1)
	return strings.clone(string(lua.tostring(L, -1))), true
}

policy_optional_string_field :: proc(L: ^lua.State, table_name: string, field_key: cstring) -> (string, bool) {
	field_type := lua.getfield(L, -1, field_key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return "", true
	}
	if field_type != c.int(lua.Type.STRING) {
		fmt.eprintfln("h2odin: config: %s.%s must be a string", table_name, field_key)
		lua.pop(L, 1)
		return "", false
	}
	defer lua.pop(L, 1)
	return strings.clone(string(lua.tostring(L, -1))), true
}

// Read parent[key] as string→bool. Parent table is at stack top.
// Absent → nil map. Keys are cloned into context.allocator.
policy_bool_map_nested :: proc(L: ^lua.State, parent_name: string, key: cstring) -> (result: map[string]bool, ok: bool) {
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s.%s must be a table of booleans", parent_name, key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	result = make(map[string]bool)
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s.%s keys must be strings", parent_name, key)
			lua.pop(L, 2)
			return nil, false
		}
		if lua.type(L, -1) != .BOOLEAN {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must be a boolean", parent_name, key, lua.tostring(L, -2))
			lua.pop(L, 2)
			return nil, false
		}
		k := strings.clone(string(lua.tostring(L, -2)))
		result[k] = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
	}
	return result, true
}

// Read parent[key] as string→string. Parent table is at stack top.
// Absent → nil map. Entries are cloned into context.allocator.
policy_string_map_nested :: proc(L: ^lua.State, parent_name: string, key: cstring) -> (result: map[string]string, ok: bool) {
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s.%s must be a table", parent_name, key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	result = make(map[string]string)
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s.%s keys must be strings", parent_name, key)
			lua.pop(L, 2)
			return nil, false
		}
		if lua.type(L, -1) != .STRING {
			fmt.eprintfln("h2odin: config: %s.%s[%q] must be a string", parent_name, key, lua.tostring(L, -2))
			lua.pop(L, 2)
			return nil, false
		}
		k := strings.clone(string(lua.tostring(L, -2)))
		v := strings.clone(string(lua.tostring(L, -1)))
		result[k] = v
		lua.pop(L, 1)
	}
	return result, true
}
