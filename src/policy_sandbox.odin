package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"

import lua "vendor:lua/5.4"

// Sandboxed Lua VM setup: allowed libraries, restricted require, path checks.

// lua_upvalueindex is a C macro (REGISTRYINDEX - i); the Odin bindings do
// not expose it, so mirror the definition here.
lua_upvalueindex :: #force_inline proc "contextless" (i: c.int) -> c.int {
	return lua.REGISTRYINDEX - i
}

// Lua prelude for require "h2odin". Table-shaping only; algorithms are
// registered from Odin onto h2o.str / h2o.naming.
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
		comments = nil, -- nil → true (emit doc comments)
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

-- Constructor sugar: type-checks the table and returns it. Field validation
-- lives on the Odin side at load.
local function ctor(name)
	return function(opts)
		if type(opts) ~= "table" then
			error(name .. " expects a table", 2)
		end
		return opts
	end
end

h2o.naming = {}
h2o.naming.odin = ctor("h2o.naming.odin")
-- snake_case / ada_case filled by the host (pure Odin algorithms).

h2o.macro_group = {}
h2o.macro_group["enum"] = ctor("h2o.macro_group.enum")

h2o["enum"] = {}
h2o["enum"].anonymous = ctor("h2o.enum.anonymous")
h2o["enum"].bit_set = ctor("h2o.enum.bit_set")

-- Filled by the host with Odin-registered helpers.
h2o.str = {}

return h2o
`

// Pure libraries only. package is opened by policy_install_require with
// restricted searchers. Raw loaders stay nil.
//
// math is opened for abs/floor/… but math.random / math.randomseed are
// stripped so a callback cannot rename nondeterministically.
policy_open_sandbox_libs :: proc(L: ^lua.State) {
	lua.L_requiref(L, "_G", lua.open_base, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "table", lua.open_table, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "string", lua.open_string, 1)
	lua.pop(L, 1)
	lua.L_requiref(L, "math", lua.open_math, 1)
	// stack: math
	lua.pushnil(L)
	lua.setfield(L, -2, "random")
	lua.pushnil(L)
	lua.setfield(L, -2, "randomseed")
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
		user_error("h2odin: internal error: package.preload missing")
		lua.pop(L, 2)
		return false
	}
	lua.pushcfunction(L, policy_open_h2odin)
	lua.setfield(L, -2, "h2odin")
	lua.pop(L, 1) // → package

	// package.searchers = { preload_searcher, config_dir_searcher }
	if lua.getfield(L, -1, "searchers") != c.int(lua.Type.TABLE) {
		user_error("h2odin: internal error: package.searchers missing")
		lua.pop(L, 2)
		return false
	}
	// stack: package, searchers
	if lua.rawgeti(L, -1, 1); !lua.isfunction(L, -1) {
		user_error("h2odin: internal error: package.searchers[1] is not the preload searcher")
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

// require "h2odin" opener: run the prelude, attach Odin helpers.
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
	str_regs := [?]lua.L_Reg {
		{"has_prefix", policy_lua_str_has_prefix},
		{"strip_prefix", policy_lua_str_strip_prefix},
		{"has_suffix", policy_lua_str_has_suffix},
		{"strip_suffix", policy_lua_str_strip_suffix},
		{nil, nil},
	}
	lua.L_setfuncs(L, raw_data(str_regs[:]), 0)
	lua.pop(L, 1) // str

	if lua.getfield(L, -1, "naming"); !lua.istable(L, -1) {
		lua.L_error(L, "h2odin: prelude missing h2o.naming")
		return 0
	}
	naming_regs := [?]lua.L_Reg{{"snake_case", policy_lua_naming_snake_case}, {"ada_case", policy_lua_naming_ada_case}, {nil, nil}}
	lua.L_setfuncs(L, raw_data(naming_regs[:]), 0)
	lua.pop(L, 1) // naming
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
