package h2odin

import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

import lua "vendor:lua/5.4"

// The policy layer is the only place Lua exists. Transformation consults
// policy through the policy_* procedures and never sees the VM, its stack,
// or its strings — every string that crosses this boundary is copied into
// the generation arena, so nothing downstream depends on Lua's lifetime.
//
// Configuration selects and parameterizes; it never authors output.

// The registry key under which the config table stays addressable for the
// lifetime of the run.
CONFIG_REGISTRY_KEY :: "h2odin.config"

Policy :: struct {
	// Private to the policy_* procedures. nil when no config was given —
	// every query then answers with the generator default.
	state:              ^lua.State,

	// Declarative settings copied out of the config table; "" means the
	// field was absent and the generator default applies.
	package_name:       string,
	foreign_lib:        string,
	type_mode:          Type_Mode,
	type_mode_is_set:   bool,

	// strip_prefixes = { func = "gl", type = "GL", const = "GL_" }. "" means
	// no prefix configured for that symbol kind.
	strip_prefix_func:  string,
	strip_prefix_type:  string,
	strip_prefix_const: string,

	// type_map = { Vector2 = "[2]f32" }: a direct C-type-name -> Odin
	// spelling override, read fully at load since it is plain data. nil
	// (not just empty) means the config never set the field.
	type_map:           map[string]string,

	// Which callbacks the config actually defines, checked once at load so
	// the common no-callback run never touches the VM per declaration.
	has_rename:         bool,
	has_keep:           bool,
}

// What kind of thing a symbol is. Renaming rules commonly differ by kind,
// so the kind travels with every symbol handed to a callback.
Symbol_Kind :: enum {
	Func,
	Type, // struct/union/enum/typedef names
	Var,
	Const, // macro constants
	Enum_Member,
	Field,
}

// The kind names as the Lua side sees them.
@(rodata)
symbol_kind_names := [Symbol_Kind]cstring {
	.Func        = "function",
	.Type        = "type",
	.Var         = "variable",
	.Const       = "constant",
	.Enum_Member = "enum_member",
	.Field       = "field",
}

// Everything a rename callback gets to see about one symbol. A single table
// on the Lua side, so richer context can be added without breaking existing
// configurations.
Symbol_Context :: struct {
	name:         string, // the original C name
	default_name: string, // the generator's default choice
	kind:         Symbol_Kind,
	parent:       string, // owning declaration for members/fields; "" otherwise
}

// Load and execute the Lua configuration once, at startup. The file must
// return a table; declarative fields are copied out here and the table is
// kept in the registry for callback queries. A broken config halts the run —
// silently degrading to defaults would generate something the user did not
// ask for.
policy_load :: proc(path: string) -> (policy: Policy, ok: bool) {
	if path == "" {
		return Policy{}, true
	}

	L := lua.L_newstate()
	if L == nil {
		fmt.eprintln("h2odin: failed to create the Lua state")
		return Policy{}, false
	}
	lua.L_openlibs(L)

	config_path := strings.clone_to_cstring(path, context.temp_allocator)
	if lua.L_dofile(L, config_path) != 0 {
		fmt.eprintfln("h2odin: config error: %s", lua.tostring(L, -1))
		lua.close(L)
		return Policy{}, false
	}
	if !lua.istable(L, -1) {
		fmt.eprintfln("h2odin: config %q must return a table", path)
		lua.close(L)
		return Policy{}, false
	}
	policy.state = L
	lua.setfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)

	policy.has_rename = policy_has_function(&policy, "rename")
	policy.has_keep = policy_has_function(&policy, "keep")

	policy.package_name = policy_string_field(&policy, "package")
	policy.foreign_lib = policy_string_field(&policy, "foreign_lib")
	switch mode := policy_string_field(&policy, "type_mode"); mode {
	case "":
	case "abi":
		policy.type_mode = .ABI
		policy.type_mode_is_set = true
	case "idiomatic":
		policy.type_mode = .Idiomatic
		policy.type_mode_is_set = true
	case:
		fmt.eprintfln("h2odin: config: type_mode must be \"abi\" or \"idiomatic\", got %q", mode)
		policy_destroy(&policy)
		return Policy{}, false
	}
	if strip_prefixes, prefixes_ok := policy_strip_prefixes(&policy); prefixes_ok {
		policy.strip_prefix_func = strip_prefixes.func
		policy.strip_prefix_type = strip_prefixes.type
		policy.strip_prefix_const = strip_prefixes.const
	} else {
		policy_destroy(&policy)
		return Policy{}, false
	}
	if type_map, type_map_ok := policy_string_map_field(&policy, "type_map"); type_map_ok {
		policy.type_map = type_map
	} else {
		policy_destroy(&policy)
		return Policy{}, false
	}

	return policy, true
}

// Ask the config to rename a symbol. decided = false means no rename
// callback exists or it returned nil — the caller keeps the default. The
// returned name is copied into the generation arena. A callback that errors
// or returns a non-string halts the run: guessing what a broken config meant
// would generate something the user did not ask for.
policy_rename :: proc(policy: ^Policy, ctx: Symbol_Context) -> (name: string, decided: bool) {
	if !policy.has_rename {
		return "", false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "rename")
	push_symbol_table(L, ctx)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config rename callback failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2) // the result and the config table

	if lua.isnil(L, -1) {
		return "", false
	}
	// Exact type check: lua_isstring would accept numbers by coercion.
	if lua.type(L, -1) != .STRING {
		fmt.eprintfln("h2odin: config rename for %q must return a string or nil", ctx.name)
		os.exit(1)
	}
	return strings.clone(string(lua.tostring(L, -1))), true
}

// Ask the config whether to keep a declaration. Only nil means "use the
// default" (keep everything); true and false are both explicit decisions.
// Anything else halts the run.
policy_keep :: proc(policy: ^Policy, ctx: Symbol_Context) -> bool {
	if !policy.has_keep {
		return true
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "keep")
	push_symbol_table(L, ctx)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config keep callback failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}

	keep: bool
	#partial switch lua.type(L, -1) {
	case .NIL:
		keep = true
	case .BOOLEAN:
		keep = bool(lua.toboolean(L, -1))
	case:
		fmt.eprintfln("h2odin: config keep for %q must return a boolean or nil", ctx.name)
		os.exit(1)
	}
	lua.pop(L, 2) // the result and the config table
	return keep
}

// Build the single context table a callback receives.
push_symbol_table :: proc(L: ^lua.State, ctx: Symbol_Context) {
	lua.createtable(L, 0, 4)
	push_string_field(L, "name", ctx.name)
	push_string_field(L, "default", ctx.default_name)
	lua.pushstring(L, symbol_kind_names[ctx.kind])
	lua.setfield(L, -2, "kind")
	if ctx.parent != "" {
		push_string_field(L, "parent", ctx.parent)
	}
}

push_string_field :: proc(L: ^lua.State, key: cstring, value: string) {
	lua.pushstring(L, strings.clone_to_cstring(value, context.temp_allocator))
	lua.setfield(L, -2, key)
}

policy_destroy :: proc(policy: ^Policy) {
	if policy.state != nil {
		lua.close(policy.state)
		policy.state = nil
	}
}

policy_has_function :: proc(policy: ^Policy, key: cstring) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 2)
	lua.getfield(L, -1, key)
	return lua.isfunction(L, -1)
}

// A string field from the config table, copied into the generation arena;
// "" when the field is absent. Lua may collect its copy any time after the
// pop, which is exactly why the copy happens here at the boundary.
policy_string_field :: proc(policy: ^Policy, key: cstring) -> string {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 2)
	if lua.getfield(L, -1, key) != c.int(lua.Type.STRING) {
		return ""
	}
	return strings.clone(string(lua.tostring(L, -1)))
}

Strip_Prefixes :: struct {
	func:  string,
	type:  string,
	const: string,
}

// Read strip_prefixes = { func = "...", type = "...", const = "..." }.
// Absent fields are fine; present non-string fields are config errors.
policy_strip_prefixes :: proc(policy: ^Policy) -> (prefixes: Strip_Prefixes, ok: bool) {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)
	outer_type := lua.getfield(L, -1, "strip_prefixes")
	if outer_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return prefixes, true
	}
	if outer_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: strip_prefixes must be a table")
		lua.pop(L, 1)
		return {}, false
	}
	defer lua.pop(L, 1)

	field_ok: bool
	prefixes.func, field_ok = policy_optional_string_field(L, "strip_prefixes", "func")
	if !field_ok {
		return {}, false
	}
	prefixes.type, field_ok = policy_optional_string_field(L, "strip_prefixes", "type")
	if !field_ok {
		return {}, false
	}
	prefixes.const, field_ok = policy_optional_string_field(L, "strip_prefixes", "const")
	if !field_ok {
		return {}, false
	}
	return prefixes, true
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

// Read a config table of string -> string fully into an Odin map, e.g.
// type_map = { Vector2 = "[2]f32" }. Declarative data this small is simpler
// to copy once than to query the VM per lookup; nil when the field is absent.
policy_string_map_field :: proc(policy: ^Policy, key: cstring) -> (map[string]string, bool) {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintfln("h2odin: config: %s must be a table", key)
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	result: map[string]string
	lua.pushnil(L) // first key for lua_next
	for lua.next(L, -2) != 0 {
		// stack: table, key, value
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config: %s keys must be strings", key)
			lua.pop(L, 2)
			return nil, false
		}
		if lua.type(L, -1) != .STRING {
			fmt.eprintfln("h2odin: config: %s[%q] must be a string", key, lua.tostring(L, -2))
			lua.pop(L, 2)
			return nil, false
		}
		k := strings.clone(string(lua.tostring(L, -2)))
		v := strings.clone(string(lua.tostring(L, -1)))
		result[k] = v
		lua.pop(L, 1) // drop value, keep key for the next iteration
	}
	return result, true
}
