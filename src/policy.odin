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

// Top-level keys the policy layer actually reads. Anything else is either
// not-yet-supported (clearer message) or unknown (typo).
@(rodata)
CONFIG_KNOWN_KEYS := [?]cstring{"package", "foreign_lib", "type_mode", "strip_prefixes", "type_map", "rename", "keep"}

// Keys that appear in design docs / the README but are not wired yet.
// Rejected explicitly so a silent no-op cannot look like success.
@(rodata)
CONFIG_UNSUPPORTED_KEYS := [?]cstring{"headers", "include_dirs", "defines", "output", "comments", "wrappers"}

// Sub-keys allowed under strip_prefixes = { ... }.
@(rodata)
STRIP_PREFIX_KEYS := [?]cstring{"func", "type", "const"}

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
	// Sandbox: open only pure libraries. Withholding io/os/package/debug
	// makes "config is side-effect-free" structural rather than a convention.
	policy_open_sandbox_libs(L)

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

	if !policy_validate_keys(&policy) {
		policy_destroy(&policy)
		return Policy{}, false
	}

	has_rename, rename_ok := policy_optional_function(&policy, "rename")
	if !rename_ok {
		policy_destroy(&policy)
		return Policy{}, false
	}
	policy.has_rename = has_rename

	has_keep, keep_ok := policy_optional_function(&policy, "keep")
	if !keep_ok {
		policy_destroy(&policy)
		return Policy{}, false
	}
	policy.has_keep = has_keep

	package_name, package_ok := policy_optional_string_top(&policy, "package")
	if !package_ok {
		policy_destroy(&policy)
		return Policy{}, false
	}
	policy.package_name = package_name

	foreign_lib, foreign_ok := policy_optional_string_top(&policy, "foreign_lib")
	if !foreign_ok {
		policy_destroy(&policy)
		return Policy{}, false
	}
	policy.foreign_lib = foreign_lib

	mode, mode_ok := policy_optional_string_top(&policy, "type_mode")
	if !mode_ok {
		policy_destroy(&policy)
		return Policy{}, false
	}
	switch mode {
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

// Open the libraries a well-behaved config needs (string/table/math helpers)
// and withhold everything that reaches the host: io, os, package, debug.
// Also nil out base loaders (dofile/loadfile/load) so a config cannot pull
// more code in by path.
policy_open_sandbox_libs :: proc(L: ^lua.State) {
	// open_* are lua_CFunction openers; L_requiref registers and (when glb=1)
	// sets the module as a global, then leaves it on the stack — pop it.
	lua.L_requiref(L, "_G", lua.open_base, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "table", lua.open_table, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "string", lua.open_string, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "math", lua.open_math, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "utf8", lua.open_utf8, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "coroutine", lua.open_coroutine, 1)
	lua.pop(L, 1)

	// base still exposes loaders that read from the host filesystem / compile
	// arbitrary chunks. Config is one file; it does not need more.
	for name in ([?]cstring{"dofile", "loadfile", "load"}) {
		lua.pushnil(L)
		lua.setglobal(L, name)
	}
}

// Reject unknown and not-yet-supported top-level keys up front so a typo or
// a roadmap-only option cannot silently do nothing.
policy_validate_keys :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	lua.pushnil(L) // first key for lua_next
	for lua.next(L, -2) != 0 {
		// stack: table, key, value
		if lua.type(L, -2) != .STRING {
			fmt.eprintln("h2odin: config: keys must be strings")
			lua.pop(L, 2)
			return false
		}
		key := string(lua.tostring(L, -2))
		if config_key_in(key, CONFIG_KNOWN_KEYS[:]) {
			lua.pop(L, 1) // drop value, keep key
			continue
		}
		if config_key_in(key, CONFIG_UNSUPPORTED_KEYS[:]) {
			fmt.eprintfln("h2odin: config: %q is not yet supported", key)
			lua.pop(L, 2)
			return false
		}
		fmt.eprintfln("h2odin: config: unknown key %q (known: package, foreign_lib, type_mode, strip_prefixes, type_map, rename, keep)", key)
		lua.pop(L, 2)
		return false
	}
	return true
}

config_key_in :: proc(key: string, list: []cstring) -> bool {
	for candidate in list {
		if key == string(candidate) {
			return true
		}
	}
	return false
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

// Optional top-level function field. Absent (nil) is fine; any other non-
// function type is a config error — a table or string would otherwise be
// silently ignored by the old "is it a function?" check.
policy_optional_function :: proc(policy: ^Policy, key: cstring) -> (present: bool, ok: bool) {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)
	field_type := lua.getfield(L, -1, key)
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return false, true
	}
	if !lua.isfunction(L, -1) {
		fmt.eprintfln("h2odin: config: %s must be a function", key)
		lua.pop(L, 1)
		return false, false
	}
	lua.pop(L, 1)
	return true, true
}

// Optional top-level string field, copied into the generation arena.
// Absent → ""; present non-string → config error (never treated as absent).
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

Strip_Prefixes :: struct {
	func:  string,
	type:  string,
	const: string,
}

// Read strip_prefixes = { func = "...", type = "...", const = "..." }.
// Absent fields are fine; present non-string fields and unknown sub-keys
// are config errors.
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

	// Reject typos like strip_prefixes.function before reading known fields.
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintln("h2odin: config: strip_prefixes keys must be strings")
			lua.pop(L, 2)
			return {}, false
		}
		sub := string(lua.tostring(L, -2))
		if !config_key_in(sub, STRIP_PREFIX_KEYS[:]) {
			fmt.eprintfln("h2odin: config: unknown strip_prefixes key %q (known: func, type, const)", sub)
			lua.pop(L, 2)
			return {}, false
		}
		lua.pop(L, 1)
	}

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
