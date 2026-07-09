package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import lua "vendor:lua/5.4"

// The policy layer is the only place Lua exists. Transformation consults
// policy through the policy_* procedures and never sees the VM, its stack,
// or its strings — every string that crosses this boundary is copied into
// the generation arena, so nothing downstream depends on Lua's lifetime.
//
// Configuration selects and parameterizes; it never authors output.
//
// Config shape (Milestone 8): a Lua program that `require "h2odin"` and
// builds a sectioned object via `h2o.config()`. Flat legacy keys are
// rejected with migration messages rather than accepted alongside the new
// surface.

CONFIG_REGISTRY_KEY :: "h2odin.config"
CONFIG_DIR_REGISTRY_KEY :: "h2odin.config_dir"

// lua_upvalueindex is a C macro (REGISTRYINDEX - i); the Odin bindings do
// not expose it, so mirror the definition here.
lua_upvalueindex :: #force_inline proc "contextless" (i: c.int) -> c.int {
	return lua.REGISTRYINDEX - i
}

@(rodata)
CONFIG_KNOWN_KEYS := [?]cstring {
	"package",
	"type_mode",
	"inputs",
	"output_folder",
	"preprocess",
	"naming",
	"types",
	"symbols",
	"macros",
	"enums",
	"structs",
	"procs",
	"foreign",
	"output",
	"diagnostics",
}

// Pre-M8 flat keys — rejected by name (keep's polarity must not dual-exist).
@(rodata)
CONFIG_LEGACY_KEYS := [?]cstring{"foreign_lib", "strip_prefixes", "type_map", "rename", "keep"}

@(rodata)
CONFIG_UNSUPPORTED_KEYS := [?]cstring{"headers", "include_dirs", "defines", "comments", "wrappers"}

@(rodata)
STRIP_PREFIX_KEYS := [?]cstring{"proc", "type", "const"}

// Sections h2o.config() creates but that have no wired fields yet. Empty
// tables / nil are fine; any real content fails the load.
@(rodata)
CONFIG_UNWIRED_SECTIONS := [?]cstring{"inputs", "output_folder", "preprocess", "macros", "enums", "structs", "procs", "output", "diagnostics"}

// Lua prelude for require "h2odin". Table-shaping only; algorithms are
// registered from Odin onto h2o.str.
H2ODIN_PRELUDE :: `-- H2Odin config prelude (require "h2odin")
local h2o = {}

local function section()
	return {}
end

function h2o.config()
	return {
		package = nil,
		type_mode = nil,
		inputs = nil,
		output_folder = nil,
		preprocess = section(),
		naming = section(),
		types = section(),
		symbols = { remove = section() },
		macros = section(),
		enums = section(),
		structs = section(),
		procs = section(),
		foreign = section(),
		output = section(),
		diagnostics = section(),
	}
end

-- Constructor sugar: h2o.naming.odin { ... } returns the table after a type
-- check. Field validation lives on the Odin side at load.
h2o.naming = {}
function h2o.naming.odin(opts)
	if type(opts) ~= "table" then
		error("h2o.naming.odin expects a table", 2)
	end
	return opts
end

-- Filled by the host with Odin-registered helpers.
h2o.str = {}

return h2o
`

Policy :: struct {
	// Private to the policy_* procedures. nil when no config was given.
	state:              ^lua.State,

	// Declarative settings copied out of the config; "" means absent.
	package_name:       string,
	foreign_lib:        string, // foreign.import_lib
	type_mode:          Type_Mode,
	type_mode_is_set:   bool,

	// naming.strip_prefixes — first matching prefix wins per kind.
	// Backing memory lives in the generation arena (or the test allocator).
	strip_prefix_proc:  []string,
	strip_prefix_type:  []string,
	strip_prefix_const: []string,

	// types.map rewrites references; types.overrides also drops the decl.
	type_map:           map[string]string,
	type_overrides:     map[string]string,

	// Callbacks present in the config (checked once at load).
	has_rename:         bool, // naming.override
	has_remove:         bool, // symbols.remove.where
}

Symbol_Kind :: enum {
	Func,
	Type, // struct/union/enum/typedef names
	Var,
	Const, // macro constants
	Enum_Member,
	Field,
}

// Kind names as Lua sees them — Odin vocabulary (Milestone 8).
@(rodata)
symbol_kind_names := [Symbol_Kind]cstring {
	.Func        = "proc",
	.Type        = "type",
	.Var         = "var",
	.Const       = "const",
	.Enum_Member = "enum_value",
	.Field       = "field",
}

Symbol_Context :: struct {
	name:         string, // original C name
	default_name: string, // generator's default choice
	kind:         Symbol_Kind,
	parent:       string, // owning declaration for members/fields; "" otherwise
}

// Load and execute the Lua configuration once, at startup. Declarative
// fields are copied into the Policy; the table stays in the registry for
// callback queries. Failure leaves no live Lua state for the caller.
policy_load :: proc(path: string) -> (policy: Policy, ok: bool) {
	if path == "" {
		return {}, true
	}

	L := lua.L_newstate()
	if L == nil {
		fmt.eprintln("h2odin: failed to create the Lua state")
		return {}, false
	}

	config_dir, dir_ok := policy_config_dir(path)
	if !dir_ok {
		lua.close(L)
		return {}, false
	}

	policy_open_sandbox_libs(L)
	if !policy_install_require(L, config_dir) {
		lua.close(L)
		return {}, false
	}

	config_path := strings.clone_to_cstring(path, context.temp_allocator)
	if lua.L_dofile(L, config_path) != 0 {
		fmt.eprintfln("h2odin: config error: %s", lua.tostring(L, -1))
		lua.close(L)
		return {}, false
	}
	if !lua.istable(L, -1) {
		fmt.eprintfln("h2odin: config %q must return a table", path)
		lua.close(L)
		return {}, false
	}

	policy.state = L
	lua.setfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)

	if !policy_validate_keys(&policy) || !policy_read_config(&policy) {
		policy_destroy(&policy)
		return {}, false
	}
	return policy, true
}

policy_config_dir :: proc(path: string) -> (dir: string, ok: bool) {
	abs_path, abs_err := filepath.abs(path, context.temp_allocator)
	if abs_err != nil {
		fmt.eprintfln("h2odin: cannot resolve config path %q", path)
		return "", false
	}
	dir_part := filepath.dir(abs_path)
	if dir_part == "" {
		dir_part = "."
	}
	return dir_part, true
}

// Pure libraries only. package is opened by policy_install_require with
// restricted searchers. Raw loaders stay nil.
policy_open_sandbox_libs :: proc(L: ^lua.State) {
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

	for name in ([?]cstring{"dofile", "loadfile", "load"}) {
		lua.pushnil(L)
		lua.setglobal(L, name)
	}
}

// package + require: only the preloaded h2odin prelude and .lua files under
// the config directory resolve. loadlib is withheld.
policy_install_require :: proc(L: ^lua.State, config_dir: string) -> bool {
	lua.L_requiref(L, "package", lua.open_package, 1)
	// stack: package

	lua.pushstring(L, strings.clone_to_cstring(config_dir, context.temp_allocator))
	lua.setfield(L, lua.REGISTRYINDEX, CONFIG_DIR_REGISTRY_KEY)

	// package.preload["h2odin"] = opener
	if lua.getfield(L, -1, "preload") != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: internal error: package.preload missing")
		lua.pop(L, 2)
		return false
	}
	lua.pushcfunction(L, policy_open_h2odin)
	lua.setfield(L, -2, "h2odin")
	lua.pop(L, 1) // → package

	// package.searchers = { preload_searcher, config_dir_searcher }
	if lua.getfield(L, -1, "searchers") != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: internal error: package.searchers missing")
		lua.pop(L, 2)
		return false
	}
	// stack: package, searchers
	if lua.rawgeti(L, -1, 1); !lua.isfunction(L, -1) {
		fmt.eprintln("h2odin: internal error: package.searchers[1] is not the preload searcher")
		lua.pop(L, 3)
		return false
	}
	// stack: package, searchers, preload_fn

	lua.createtable(L, 2, 0)
	// stack: package, searchers, preload_fn, new_searchers
	lua.pushvalue(L, -2)
	lua.rawseti(L, -2, 1)
	lua.pushcfunction(L, policy_config_searcher)
	lua.rawseti(L, -2, 2)
	// package.searchers = new_searchers (pops new_searchers)
	lua.setfield(L, -4, "searchers")
	// stack: package, old_searchers, preload_fn
	lua.pop(L, 2)
	// stack: package

	lua.pushnil(L)
	lua.setfield(L, -2, "loadlib")
	lua.pushstring(L, "")
	lua.setfield(L, -2, "path")
	lua.pushstring(L, "")
	lua.setfield(L, -2, "cpath")

	lua.pop(L, 1)
	return true
}

// require "h2odin" opener: run the prelude, attach Odin str helpers.
// L_error longjmps out of the C callback; the trailing return is unreachable
// but keeps the procedure's type `-> c.int`.
policy_open_h2odin :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()

	prelude := strings.clone_to_cstring(H2ODIN_PRELUDE, context.temp_allocator)
	if lua.L_loadstring(L, prelude) != .OK {
		lua.L_error(L, "h2odin: failed to load prelude: %s", lua.tostring(L, -1))
		return 0
	}
	if lua.pcall(L, 0, 1, 0) != 0 {
		lua.L_error(L, "h2odin: prelude error: %s", lua.tostring(L, -1))
		return 0
	}
	// stack: h2o
	if lua.getfield(L, -1, "str"); !lua.istable(L, -1) {
		lua.L_error(L, "h2odin: prelude missing h2o.str")
		return 0
	}
	regs := [?]lua.L_Reg {
		{"has_prefix", policy_lua_str_has_prefix},
		{"strip_prefix", policy_lua_str_strip_prefix},
		{"has_suffix", policy_lua_str_has_suffix},
		{nil, nil},
	}
	lua.L_setfuncs(L, raw_data(regs[:]), 0)
	lua.pop(L, 1) // str
	return 1
}

// package searcher #2: only .lua files under the config directory.
// Returns a loader function, or a not-found explanation string (Lua convention).
policy_config_searcher :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()

	modname := policy_lua_check_string(L, 1)
	if modname == "" || strings.contains(modname, "..") || strings.contains(modname, "/") || strings.contains(modname, "\\") {
		lua.pushstring(L, "h2odin: module name must be a dotted path without '..' or separators")
		return 1
	}

	if lua.getfield(L, lua.REGISTRYINDEX, CONFIG_DIR_REGISTRY_KEY); !lua.isstring(L, -1) {
		lua.pushstring(L, "h2odin: config directory not set")
		return 1
	}
	config_dir := string(lua.tostring(L, -1))
	lua.pop(L, 1)

	rel, _ := strings.replace_all(modname, ".", "/", context.temp_allocator)
	file_name := strings.concatenate({rel, ".lua"}, context.temp_allocator)
	candidate, join_err := filepath.join({config_dir, file_name}, context.temp_allocator)
	if join_err != nil {
		lua.pushstring(L, "h2odin: cannot build required module path")
		return 1
	}

	abs_candidate, abs_err := filepath.abs(candidate, context.temp_allocator)
	if abs_err != nil {
		lua.pushstring(L, "h2odin: cannot resolve required module path")
		return 1
	}
	config_abs, config_abs_err := filepath.abs(config_dir, context.temp_allocator)
	if config_abs_err != nil || !path_is_under(abs_candidate, config_abs) {
		lua.pushstring(L, "h2odin: require path escapes the config directory")
		return 1
	}
	if !os.exists(abs_candidate) {
		// Leading newline matches Lua's default searcher style for require errors.
		msg := fmt.ctprintf("\n\tno file '%s'", abs_candidate)
		lua.pushstring(L, msg)
		return 1
	}

	lua.pushstring(L, strings.clone_to_cstring(abs_candidate, context.temp_allocator))
	lua.pushcclosure(L, policy_config_loader, 1)
	return 1
}

policy_config_loader :: proc "c" (L: ^lua.State) -> c.int {
	context = runtime.default_context()
	path := lua.tostring(L, lua_upvalueindex(1))
	if lua.L_loadfile(L, path) != .OK {
		lua.L_error(L, "h2odin: %s", lua.tostring(L, -1))
		return 0
	}
	if lua.pcall(L, 0, 1, 0) != 0 {
		lua.L_error(L, "h2odin: %s", lua.tostring(L, -1))
		return 0
	}
	return 1
}

// True when path is root or a descendant. Uses a separator boundary so
// "/tmp/cfg" does not match "/tmp/cfg_evil/x". No allocation.
path_is_under :: proc(path, root: string) -> bool {
	if path == root {
		return true
	}
	if len(path) <= len(root) || !strings.has_prefix(path, root) {
		return false
	}
	sep := path[len(root)]
	return sep == '/' || sep == '\\'
}

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

// Reject unknown, legacy, and unsupported top-level keys up front.
policy_validate_keys :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintln("h2odin: config: keys must be strings")
			lua.pop(L, 2)
			return false
		}
		key := string(lua.tostring(L, -2))
		switch {
		case config_key_in(key, CONFIG_KNOWN_KEYS[:]):
			lua.pop(L, 1)
		case config_key_in(key, CONFIG_LEGACY_KEYS[:]):
			fmt.eprintfln("h2odin: config: %s", legacy_key_message(key))
			lua.pop(L, 2)
			return false
		case config_key_in(key, CONFIG_UNSUPPORTED_KEYS[:]):
			fmt.eprintfln("h2odin: config: %q is not yet supported", key)
			lua.pop(L, 2)
			return false
		case:
			fmt.eprintfln("h2odin: config: unknown key %q (use h2o.config() sections: package, type_mode, naming, types, symbols, foreign, …)", key)
			lua.pop(L, 2)
			return false
		}
	}
	return true
}

legacy_key_message :: proc(key: string) -> string {
	switch key {
	case "foreign_lib":
		return `"foreign_lib" was removed; use foreign.import_lib`
	case "strip_prefixes":
		return `"strip_prefixes" was removed; use naming.strip_prefixes (key "func" is now "proc")`
	case "type_map":
		return `"type_map" was removed; use types.overrides (declaration replace) or types.map (reference rewrite)`
	case "rename":
		return `"rename" was removed; use naming.override`
	case "keep":
		return `"keep" was removed; use symbols.remove.where (polarity inverted: return true to drop)`
	}
	return fmt.tprintf("%q is a legacy key", key)
}

config_key_in :: proc(key: string, list: []cstring) -> bool {
	for candidate in list {
		if key == string(candidate) {
			return true
		}
	}
	return false
}

// Copy declarative fields and record which callbacks exist.
policy_read_config :: proc(policy: ^Policy) -> bool {
	for section in CONFIG_UNWIRED_SECTIONS {
		if !policy_reject_if_set(policy, section) {
			return false
		}
	}

	package_name, package_ok := policy_optional_string_top(policy, "package")
	if !package_ok {
		return false
	}
	policy.package_name = package_name

	mode, mode_ok := policy_optional_string_top(policy, "type_mode")
	if !mode_ok {
		return false
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
		return false
	}

	return policy_read_foreign(policy) && policy_read_naming(policy) && policy_read_types(policy) && policy_read_symbols(policy)
}

// inputs / output_folder may be nil; a non-nil value means the user set
// something we do not implement yet. Section tables must be empty.
policy_reject_if_set :: proc(policy: ^Policy, key: cstring) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, key)
	defer lua.pop(L, 1)

	#partial switch lua.Type(field_type) {
	case .NIL:
		return true
	case .TABLE:
		if policy_table_is_empty(L, -1) {
			return true
		}
	}
	fmt.eprintfln("h2odin: config: %s is not yet supported", key)
	return false
}

policy_table_is_empty :: proc(L: ^lua.State, index: c.int) -> bool {
	idx := lua.absindex(L, index)
	lua.pushnil(L)
	if lua.next(L, idx) != 0 {
		lua.pop(L, 2)
		return false
	}
	return true
}

policy_read_foreign :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "foreign")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: foreign must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "foreign", []cstring{"import_lib"}) {
		return false
	}
	lib, lib_ok := policy_optional_string_field(L, "foreign", "import_lib")
	if !lib_ok {
		return false
	}
	policy.foreign_lib = lib
	return true
}

policy_read_naming :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "naming")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: naming must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	// Supported: strip_prefixes (data), override (callback).
	// Not yet: overrides, strip_suffixes, known_tokens.
	allowed := []cstring{"strip_prefixes", "override", "overrides", "strip_suffixes", "known_tokens"}
	if !policy_reject_unknown_subkeys(L, "naming", allowed) {
		return false
	}
	for not_yet in ([?]cstring{"overrides", "strip_suffixes", "known_tokens"}) {
		if !policy_reject_nested_if_set(L, "naming", not_yet) {
			return false
		}
	}

	// Plural is data, singular is callback.
	override_type := lua.Type(lua.getfield(L, -1, "override"))
	#partial switch override_type {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_rename = true
	case .TABLE:
		fmt.eprintln("h2odin: config: naming.override must be a function (plural naming.overrides is the data map — not yet supported)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: naming.override must be a function")
		lua.pop(L, 1)
		return false
	}

	prefixes, prefixes_ok := policy_strip_prefixes_from(L)
	if !prefixes_ok {
		return false
	}
	policy.strip_prefix_proc = prefixes.procs
	policy.strip_prefix_type = prefixes.types
	policy.strip_prefix_const = prefixes.constants
	return true
}

policy_read_types :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "types")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: types must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "types", []cstring{"map", "overrides", "override"}) {
		return false
	}
	if !policy_reject_nested_if_set(L, "types", "override") {
		return false
	}

	// Plural is data.
	if lua.Type(lua.getfield(L, -1, "overrides")) == .FUNCTION {
		fmt.eprintln("h2odin: config: types.overrides must be a table (plural is data; singular types.override is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)
	if lua.Type(lua.getfield(L, -1, "map")) == .FUNCTION {
		fmt.eprintln("h2odin: config: types.map must be a table")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)

	m, m_ok := policy_string_map_nested(L, "types", "map")
	if !m_ok {
		return false
	}
	policy.type_map = m

	o, o_ok := policy_string_map_nested(L, "types", "overrides")
	if !o_ok {
		return false
	}
	policy.type_overrides = o
	return true
}

policy_read_symbols :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "symbols")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: symbols must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "symbols", []cstring{"remove"}) {
		return false
	}

	remove_type := lua.getfield(L, -1, "remove")
	if remove_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if remove_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: symbols.remove must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "symbols.remove", []cstring{"where", "names", "patterns"}) {
		return false
	}
	for not_yet in ([?]cstring{"names", "patterns"}) {
		if !policy_reject_nested_if_set(L, "symbols.remove", not_yet) {
			return false
		}
	}

	where_type := lua.Type(lua.getfield(L, -1, "where"))
	#partial switch where_type {
	case .NIL:
		lua.pop(L, 1)
		return true
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_remove = true
		return true
	case .TABLE:
		fmt.eprintln("h2odin: config: symbols.remove.where must be a function (predicate callback)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: symbols.remove.where must be a function")
		lua.pop(L, 1)
		return false
	}
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
// "proc" / "type" / "const" as the config surface.
Strip_Prefixes :: struct {
	procs:     []string,
	types:     []string,
	constants: []string,
}

// Read naming.strip_prefixes from the naming table at stack top.
// Each kind accepts a string or a list of strings.
policy_strip_prefixes_from :: proc(L: ^lua.State) -> (prefixes: Strip_Prefixes, ok: bool) {
	outer_type := lua.getfield(L, -1, "strip_prefixes")
	if outer_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return {}, true
	}
	if outer_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: naming.strip_prefixes must be a table")
		lua.pop(L, 1)
		return {}, false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "naming.strip_prefixes", STRIP_PREFIX_KEYS[:]) {
		return {}, false
	}

	field_ok: bool
	prefixes.procs, field_ok = policy_string_or_list_field(L, "naming.strip_prefixes", "proc")
	if !field_ok {
		return {}, false
	}
	prefixes.types, field_ok = policy_string_or_list_field(L, "naming.strip_prefixes", "type")
	if !field_ok {
		return {}, false
	}
	prefixes.constants, field_ok = policy_string_or_list_field(L, "naming.strip_prefixes", "const")
	if !field_ok {
		return {}, false
	}
	return prefixes, true
}

// Copies into context.allocator (generation arena during a normal run).
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

	n := int(lua.L_len(L, -1))
	if n == 0 {
		// Empty list is fine; a non-array table (string keys only) is not.
		lua.pushnil(L)
		if lua.next(L, -2) != 0 {
			fmt.eprintfln("h2odin: config: %s.%s must be a list of strings", table_name, field_key)
			lua.pop(L, 2)
			return nil, false
		}
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

// naming.override — returns a name when the callback decides, else decided=false.
// Callback failure is fatal: guessing a broken config would emit the wrong API.
policy_rename :: proc(policy: ^Policy, ctx: Symbol_Context) -> (name: string, decided: bool) {
	if !policy.has_rename {
		return "", false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "naming")
	lua.getfield(L, -1, "override")
	// stack: config, naming, override
	lua.remove(L, -2) // config, override
	push_symbol_table(L, ctx)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config naming.override failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2) // result, config

	if lua.isnil(L, -1) {
		return "", false
	}
	if lua.type(L, -1) != .STRING {
		fmt.eprintfln("h2odin: config naming.override for %q must return a string or nil", ctx.name)
		os.exit(1)
	}
	return strings.clone(string(lua.tostring(L, -1))), true
}

// symbols.remove.where — true means drop. nil/false mean keep (predicate
// nil collapses to false per the config spec).
policy_remove :: proc(policy: ^Policy, ctx: Symbol_Context) -> bool {
	if !policy.has_remove {
		return false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "symbols")
	lua.getfield(L, -1, "remove")
	lua.getfield(L, -1, "where")
	// stack: config, symbols, remove, where
	lua.remove(L, -2) // drop remove
	lua.remove(L, -2) // drop symbols → config, where
	push_symbol_table(L, ctx)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config symbols.remove.where failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}

	remove := false
	#partial switch lua.type(L, -1) {
	case .NIL:
		remove = false
	case .BOOLEAN:
		remove = bool(lua.toboolean(L, -1))
	case:
		fmt.eprintfln("h2odin: config symbols.remove.where for %q must return a boolean or nil", ctx.name)
		os.exit(1)
	}
	lua.pop(L, 2) // result, config
	return remove
}

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
