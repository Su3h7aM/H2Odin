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
STRIP_KIND_KEYS := [?]cstring{"proc", "type", "const", "enum_value"}

// Sections h2o.config() creates but that have no wired fields yet. Empty
// tables / nil are fine; any real content fails the load.
@(rodata)
CONFIG_UNWIRED_SECTIONS := [?]cstring{"diagnostics"}

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

// A macros.groups entry of kind enum. The include callback, when present,
// lives in the Lua config table at groups[lua_index]; Odin never stores a
// Lua reference beyond the state + index.
Macro_Group_Enum :: struct {
	id:                   string,
	name:                 string, // Odin enum type name
	base_type:            string, // optional spelling hint; empty → c.int / Int
	prefix:               string,
	exclude_prefixes:     []string,
	member_strip_prefix:  string,
	emit_original_consts: bool, // default true when field absent
	has_include:          bool,
	lua_index:            int, // 1-based index into config.macros.groups
}

Enum_Anonymous_Rule :: struct {
	name:         string, // Odin name to give the anonymous enum
	first_member: string, // match by first member's C name
}

Enum_Bit_Set_Rule :: struct {
	enum_name: string, // C enum to transform
	name:      string, // Odin bit_set type name
	mode:      string, // must be "log2" today
}

// A type/tag (or type/default) action from structs.fields / procs.params.
// Empty strings mean "not set"; callbacks may refine further.
Member_Action :: struct {
	type:    string,
	tag:     string, // structs only
	default: string, // procs only
}

Policy :: struct {
	// Private to the policy_* procedures. nil when no config was given.
	state:               ^lua.State,

	// Directory containing the config file (absolute). Used to resolve
	// relative inputs and preprocess paths. Empty when no config was given.
	config_dir:          string,

	// Declarative settings copied out of the config; "" means absent.
	package_name:        string,
	foreign_lib:         string, // foreign.import_lib
	foreign_link_prefix: string, // foreign.link_prefix — C symbol prefix
	type_mode:           Type_Mode,
	type_mode_is_set:    bool,

	// Multi-header inputs and clang preprocess knobs.
	inputs:              []string,
	include_paths:       []string,
	defines:             map[string]string, // NAME → value ("" when -DNAME alone)

	// Output layout.
	output_folder:       string,
	procedures_at_end:   bool, // default true when output section absent
	imports_file:        string,
	footer_per_header:   bool,

	// naming.strip_prefixes / strip_suffixes — first match wins per kind.
	// Backing memory lives in the generation arena (or the test allocator).
	strip_prefix_proc:   []string,
	strip_prefix_type:   []string,
	strip_prefix_const:  []string,
	strip_prefix_enum:   []string,
	strip_suffix_proc:   []string,
	strip_suffix_type:   []string,
	strip_suffix_const:  []string,
	strip_suffix_enum:   []string,

	// naming.known_tokens: surface spelling → lower form.
	known_tokens:        map[string]string,
	// naming.overrides: C name → Odin name (absolute).
	naming_overrides:    map[string]string,

	// types.map rewrites references; types.overrides also drops the decl.
	type_map:            map[string]string,
	type_overrides:      map[string]string,

	// symbols.remove declarative tiers.
	remove_names:        []string,
	remove_patterns:     []string,

	// macros.groups
	macro_groups:        []Macro_Group_Enum,

	// enums.*
	enum_anonymous:      []Enum_Anonymous_Rule,
	enum_bit_sets:       []Enum_Bit_Set_Rule,

	// structs.* — "Struct.field" → action; align is C struct name → N.
	struct_fields:       map[string]Member_Action,
	struct_align:        map[string]int,

	// procs.* — "Proc.param" / "Proc" (results) → action.
	proc_params:         map[string]Member_Action,
	proc_results:        map[string]Member_Action,

	// Callbacks present in the config (checked once at load).
	has_rename:          bool, // naming.override
	has_remove_where:    bool, // symbols.remove.where
	has_enum_member:     bool, // enums.member
	has_struct_field:    bool, // structs.field
	has_proc_param:      bool, // procs.param
	has_proc_result:     bool, // procs.result
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
	// Clone only after a successful load so failed validation does not leak.
	policy.config_dir = strings.clone(config_dir)
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

	// Default: procedures after types (current emit layout).
	policy.procedures_at_end = true

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

	return(
		policy_read_inputs(policy) &&
		policy_read_output_folder(policy) &&
		policy_read_preprocess(policy) &&
		policy_read_foreign(policy) &&
		policy_read_naming(policy) &&
		policy_read_types(policy) &&
		policy_read_symbols(policy) &&
		policy_read_macros(policy) &&
		policy_read_enums(policy) &&
		policy_read_structs(policy) &&
		policy_read_procs(policy) &&
		policy_read_output(policy) \
	)
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

	if !policy_reject_unknown_subkeys(L, "foreign", []cstring{"import_lib", "link_prefix"}) {
		return false
	}
	lib, lib_ok := policy_optional_string_field(L, "foreign", "import_lib")
	if !lib_ok {
		return false
	}
	policy.foreign_lib = lib
	prefix, prefix_ok := policy_optional_string_field(L, "foreign", "link_prefix")
	if !prefix_ok {
		return false
	}
	policy.foreign_link_prefix = prefix
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

	allowed := []cstring{"strip_prefixes", "strip_suffixes", "known_tokens", "overrides", "override"}
	if !policy_reject_unknown_subkeys(L, "naming", allowed) {
		return false
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
		fmt.eprintln("h2odin: config: naming.override must be a function (plural naming.overrides is the data map)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: naming.override must be a function")
		lua.pop(L, 1)
		return false
	}

	if lua.Type(lua.getfield(L, -1, "overrides")) == .FUNCTION {
		fmt.eprintln("h2odin: config: naming.overrides must be a table (plural is data; singular naming.override is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)

	prefixes, prefixes_ok := policy_strip_kinds_from(L, "strip_prefixes")
	if !prefixes_ok {
		return false
	}
	policy.strip_prefix_proc = prefixes.procs
	policy.strip_prefix_type = prefixes.types
	policy.strip_prefix_const = prefixes.constants
	policy.strip_prefix_enum = prefixes.enum_values

	suffixes, suffixes_ok := policy_strip_kinds_from(L, "strip_suffixes")
	if !suffixes_ok {
		return false
	}
	policy.strip_suffix_proc = suffixes.procs
	policy.strip_suffix_type = suffixes.types
	policy.strip_suffix_const = suffixes.constants
	policy.strip_suffix_enum = suffixes.enum_values

	known, known_ok := policy_string_map_nested(L, "naming", "known_tokens")
	if !known_ok {
		return false
	}
	policy.known_tokens = known

	overrides, overrides_ok := policy_string_map_nested(L, "naming", "overrides")
	if !overrides_ok {
		return false
	}
	policy.naming_overrides = overrides
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

	names, names_ok := policy_string_list_field(L, "symbols.remove", "names")
	if !names_ok {
		return false
	}
	policy.remove_names = names

	patterns, patterns_ok := policy_string_list_field(L, "symbols.remove", "patterns")
	if !patterns_ok {
		return false
	}
	policy.remove_patterns = patterns

	where_type := lua.Type(lua.getfield(L, -1, "where"))
	#partial switch where_type {
	case .NIL:
		lua.pop(L, 1)
		return true
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_remove_where = true
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

	n := int(lua.L_len(L, -1))
	if n == 0 {
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

policy_read_macros :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "macros")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: macros must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "macros", []cstring{"groups"}) {
		return false
	}

	groups_type := lua.getfield(L, -1, "groups")
	if groups_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if groups_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: macros.groups must be a list of group tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	groups := make([dynamic]Macro_Group_Enum, 0, n)
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			fmt.eprintfln("h2odin: config: macros.groups[%d] must be a table (use h2o.macro_group.enum{{...}})", i + 1)
			lua.pop(L, 1)
			return false
		}
		group, group_ok := policy_read_macro_group_enum(L, i + 1)
		lua.pop(L, 1)
		if !group_ok {
			return false
		}
		append(&groups, group)
	}
	policy.macro_groups = groups[:]
	return true
}

// Group table is at stack top.
policy_read_macro_group_enum :: proc(L: ^lua.State, lua_index: int) -> (group: Macro_Group_Enum, ok: bool) {
	allowed := []cstring{"id", "name", "base_type", "prefix", "exclude_prefixes", "include", "member_strip_prefix", "emit_original_consts"}
	if !policy_reject_unknown_subkeys(L, "macros.groups[]", allowed) {
		return {}, false
	}

	name, name_ok := policy_optional_string_field(L, "macros.groups[]", "name")
	if !name_ok || name == "" {
		fmt.eprintln("h2odin: config: macros.groups[] requires name")
		return {}, false
	}
	group.name = name
	group.lua_index = lua_index

	id, id_ok := policy_optional_string_field(L, "macros.groups[]", "id")
	if !id_ok {
		return {}, false
	}
	group.id = id

	base, base_ok := policy_optional_string_field(L, "macros.groups[]", "base_type")
	if !base_ok {
		return {}, false
	}
	group.base_type = base

	prefix, prefix_ok := policy_optional_string_field(L, "macros.groups[]", "prefix")
	if !prefix_ok {
		return {}, false
	}
	group.prefix = prefix

	member_strip, member_strip_ok := policy_optional_string_field(L, "macros.groups[]", "member_strip_prefix")
	if !member_strip_ok {
		return {}, false
	}
	group.member_strip_prefix = member_strip

	// exclude_prefixes: string or list
	excl, excl_ok := policy_string_or_list_field(L, "macros.groups[]", "exclude_prefixes")
	if !excl_ok {
		return {}, false
	}
	group.exclude_prefixes = excl

	// emit_original_consts defaults to true when absent.
	group.emit_original_consts = true
	emit_type := lua.getfield(L, -1, "emit_original_consts")
	#partial switch lua.Type(emit_type) {
	case .NIL:
		lua.pop(L, 1)
	case .BOOLEAN:
		group.emit_original_consts = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
	case:
		fmt.eprintln("h2odin: config: macros.groups[].emit_original_consts must be a boolean")
		lua.pop(L, 1)
		return {}, false
	}

	inc_type := lua.Type(lua.getfield(L, -1, "include"))
	#partial switch inc_type {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		group.has_include = true
	case:
		fmt.eprintln("h2odin: config: macros.groups[].include must be a function")
		lua.pop(L, 1)
		return {}, false
	}

	return group, true
}

policy_read_enums :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "enums")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: enums must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "enums", []cstring{"member", "anonymous", "bit_sets"}) {
		return false
	}

	member_type := lua.Type(lua.getfield(L, -1, "member"))
	#partial switch member_type {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_enum_member = true
	case .TABLE:
		fmt.eprintln("h2odin: config: enums.member must be a function")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: enums.member must be a function")
		lua.pop(L, 1)
		return false
	}

	if !policy_read_enum_anonymous(L, policy) {
		return false
	}
	return policy_read_enum_bit_sets(L, policy)
}

// enums table at stack top.
policy_read_enum_anonymous :: proc(L: ^lua.State, policy: ^Policy) -> bool {
	field_type := lua.getfield(L, -1, "anonymous")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: enums.anonymous must be a list of tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	rules := make([dynamic]Enum_Anonymous_Rule, 0, n)
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			fmt.eprintfln("h2odin: config: enums.anonymous[%d] must be a table", i + 1)
			lua.pop(L, 1)
			return false
		}
		if !policy_reject_unknown_subkeys(L, "enums.anonymous[]", []cstring{"name", "first_member"}) {
			lua.pop(L, 1)
			return false
		}
		name, name_ok := policy_optional_string_field(L, "enums.anonymous[]", "name")
		first, first_ok := policy_optional_string_field(L, "enums.anonymous[]", "first_member")
		lua.pop(L, 1)
		if !name_ok || !first_ok || name == "" || first == "" {
			fmt.eprintln("h2odin: config: enums.anonymous[] requires name and first_member")
			return false
		}
		append(&rules, Enum_Anonymous_Rule{name = name, first_member = first})
	}
	policy.enum_anonymous = rules[:]
	return true
}

policy_read_enum_bit_sets :: proc(L: ^lua.State, policy: ^Policy) -> bool {
	field_type := lua.getfield(L, -1, "bit_sets")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: enums.bit_sets must be a list of tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	rules := make([dynamic]Enum_Bit_Set_Rule, 0, n)
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			fmt.eprintfln("h2odin: config: enums.bit_sets[%d] must be a table", i + 1)
			lua.pop(L, 1)
			return false
		}
		if !policy_reject_unknown_subkeys(L, "enums.bit_sets[]", []cstring{"enum", "name", "mode"}) {
			lua.pop(L, 1)
			return false
		}
		// "enum" is a Lua keyword-friendly field name in the constructor table.
		enum_name, enum_ok := policy_optional_string_field(L, "enums.bit_sets[]", "enum")
		name, name_ok := policy_optional_string_field(L, "enums.bit_sets[]", "name")
		mode, mode_ok := policy_optional_string_field(L, "enums.bit_sets[]", "mode")
		lua.pop(L, 1)
		if !enum_ok || !name_ok || !mode_ok || enum_name == "" || name == "" {
			fmt.eprintln("h2odin: config: enums.bit_sets[] requires enum, name, and mode")
			return false
		}
		if mode != "log2" {
			fmt.eprintfln("h2odin: config: enums.bit_sets[].mode must be \"log2\", got %q", mode)
			return false
		}
		append(&rules, Enum_Bit_Set_Rule{enum_name = enum_name, name = name, mode = mode})
	}
	policy.enum_bit_sets = rules[:]
	return true
}

// ---------------------------------------------------------------- Milestone 10

policy_read_inputs :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	list, list_ok := policy_string_list_field(L, "config", "inputs")
	if !list_ok {
		return false
	}
	policy.inputs = list
	return true
}

policy_read_output_folder :: proc(policy: ^Policy) -> bool {
	folder, ok := policy_optional_string_top(policy, "output_folder")
	if !ok {
		return false
	}
	policy.output_folder = folder
	return true
}

policy_read_preprocess :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "preprocess")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: preprocess must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "preprocess", []cstring{"include_paths", "defines"}) {
		return false
	}

	paths, paths_ok := policy_string_list_field(L, "preprocess", "include_paths")
	if !paths_ok {
		return false
	}
	policy.include_paths = paths

	defs, defs_ok := policy_string_map_nested(L, "preprocess", "defines")
	if !defs_ok {
		return false
	}
	// Allow non-string values only if we want -DNAME without value via true?
	// Spec shows string values. Keep string→string.
	policy.defines = defs
	return true
}

policy_read_structs :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "structs")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: structs must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "structs", []cstring{"fields", "field", "align"}) {
		return false
	}

	// Plural is data; singular is callback.
	if lua.Type(lua.getfield(L, -1, "fields")) == .FUNCTION {
		fmt.eprintln("h2odin: config: structs.fields must be a table (plural is data; singular structs.field is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)

	field_cb := lua.Type(lua.getfield(L, -1, "field"))
	#partial switch field_cb {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_struct_field = true
	case .TABLE:
		fmt.eprintln("h2odin: config: structs.field must be a function (plural structs.fields is the data map)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: structs.field must be a function")
		lua.pop(L, 1)
		return false
	}

	fields, fields_ok := policy_member_action_map(L, "structs", "fields", allow_tag = true, allow_default = false)
	if !fields_ok {
		return false
	}
	policy.struct_fields = fields

	align, align_ok := policy_int_map_nested(L, "structs", "align")
	if !align_ok {
		return false
	}
	policy.struct_align = align
	return true
}

policy_read_procs :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "procs")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: procs must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "procs", []cstring{"params", "param", "results", "result"}) {
		return false
	}

	if lua.Type(lua.getfield(L, -1, "params")) == .FUNCTION {
		fmt.eprintln("h2odin: config: procs.params must be a table (plural is data; singular procs.param is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)
	if lua.Type(lua.getfield(L, -1, "results")) == .FUNCTION {
		fmt.eprintln("h2odin: config: procs.results must be a table (plural is data; singular procs.result is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)

	param_cb := lua.Type(lua.getfield(L, -1, "param"))
	#partial switch param_cb {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_proc_param = true
	case .TABLE:
		fmt.eprintln("h2odin: config: procs.param must be a function (plural procs.params is the data map)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: procs.param must be a function")
		lua.pop(L, 1)
		return false
	}

	result_cb := lua.Type(lua.getfield(L, -1, "result"))
	#partial switch result_cb {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		policy.has_proc_result = true
	case .TABLE:
		fmt.eprintln("h2odin: config: procs.result must be a function (plural procs.results is the data map)")
		lua.pop(L, 1)
		return false
	case:
		fmt.eprintln("h2odin: config: procs.result must be a function")
		lua.pop(L, 1)
		return false
	}

	params, params_ok := policy_member_action_map(L, "procs", "params", allow_tag = false, allow_default = true)
	if !params_ok {
		return false
	}
	policy.proc_params = params

	results, results_ok := policy_member_action_map(L, "procs", "results", allow_tag = false, allow_default = false)
	if !results_ok {
		return false
	}
	policy.proc_results = results
	return true
}

policy_read_output :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "output")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		fmt.eprintln("h2odin: config: output must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "output", []cstring{"procedures_at_end", "imports_file", "footer_per_header"}) {
		return false
	}

	end_type := lua.getfield(L, -1, "procedures_at_end")
	#partial switch lua.Type(end_type) {
	case .NIL:
		lua.pop(L, 1)
	case .BOOLEAN:
		policy.procedures_at_end = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
	case:
		fmt.eprintln("h2odin: config: output.procedures_at_end must be a boolean")
		lua.pop(L, 1)
		return false
	}

	footer_type := lua.getfield(L, -1, "footer_per_header")
	#partial switch lua.Type(footer_type) {
	case .NIL:
		lua.pop(L, 1)
	case .BOOLEAN:
		policy.footer_per_header = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
	case:
		fmt.eprintln("h2odin: config: output.footer_per_header must be a boolean")
		lua.pop(L, 1)
		return false
	}

	imports, imports_ok := policy_optional_string_field(L, "output", "imports_file")
	if !imports_ok {
		return false
	}
	policy.imports_file = imports
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
policy_remove_where :: proc(policy: ^Policy, ctx: Symbol_Context) -> bool {
	if !policy.has_remove_where {
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

// macros.groups[i].include(m) — m has name, value, is_integer().
// Order already applied by the caller: prefix → exclude → integer gate.
// Returns true to include the macro in the group.
policy_macro_include :: proc(policy: ^Policy, group: Macro_Group_Enum, decl: Macro_Decl) -> bool {
	if !group.has_include {
		return true
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "macros")
	lua.getfield(L, -1, "groups")
	lua.geti(L, -1, lua.Integer(group.lua_index))
	lua.getfield(L, -1, "include")
	// stack: config, macros, groups, group, include
	lua.remove(L, -2) // drop group
	lua.remove(L, -2) // drop groups
	lua.remove(L, -2) // drop macros → config, include
	push_macro_view(L, decl)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config macros.groups[%d].include failed: %s", group.lua_index, lua.tostring(L, -1))
		os.exit(1)
	}
	include := false
	#partial switch lua.type(L, -1) {
	case .NIL:
		include = false
	case .BOOLEAN:
		include = bool(lua.toboolean(L, -1))
	case:
		fmt.eprintfln("h2odin: config macros.groups[%d].include for %q must return a boolean or nil", group.lua_index, decl.name)
		os.exit(1)
	}
	lua.pop(L, 2) // result, config
	return include
}

push_macro_view :: proc(L: ^lua.State, decl: Macro_Decl) {
	lua.createtable(L, 0, 4)
	push_string_field(L, "name", decl.name)
	if value, is_int := macro_integer_value(decl); is_int {
		lua.pushinteger(L, lua.Integer(value))
		lua.setfield(L, -2, "value")
	} else {
		lua.pushnil(L)
		lua.setfield(L, -2, "value")
	}
	lua.pushcfunction(L, policy_lua_macro_is_integer)
	lua.setfield(L, -2, "is_integer")
	lua.pushcfunction(L, policy_lua_macro_has_prefix)
	lua.setfield(L, -2, "has_prefix")
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

// enums.member(member) → nil | { remove = true }
// Returns true when the member should be dropped.
policy_enum_member_remove :: proc(policy: ^Policy, enum_name, member_name: string, value: i64) -> bool {
	if !policy.has_enum_member {
		return false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "enums")
	lua.getfield(L, -1, "member")
	// stack: config, enums, member
	lua.remove(L, -2) // config, member
	lua.createtable(L, 0, 3)
	push_string_field(L, "enum_name", enum_name)
	push_string_field(L, "name", member_name)
	lua.pushinteger(L, lua.Integer(value))
	lua.setfield(L, -2, "value")
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config enums.member failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2) // result, config

	if lua.isnil(L, -1) {
		return false
	}
	if !lua.istable(L, -1) {
		fmt.eprintfln("h2odin: config enums.member for %q must return nil or a table", member_name)
		os.exit(1)
	}
	lua.getfield(L, -1, "remove")
	defer lua.pop(L, 1)
	if lua.isnil(L, -1) {
		return false
	}
	if lua.type(L, -1) != .BOOLEAN {
		fmt.eprintfln("h2odin: config enums.member for %q: remove must be a boolean", member_name)
		os.exit(1)
	}
	return bool(lua.toboolean(L, -1))
}

// structs.field(field) → nil | { type?, tag? }
policy_struct_field_action :: proc(policy: ^Policy, struct_name, field_name, type_spelling: string) -> (action: Member_Action, decided: bool) {
	if !policy.has_struct_field {
		return {}, false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "structs")
	lua.getfield(L, -1, "field")
	lua.remove(L, -2) // config, field
	lua.createtable(L, 0, 3)
	push_string_field(L, "struct_name", struct_name)
	push_string_field(L, "name", field_name)
	push_string_field(L, "type", type_spelling)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config structs.field failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2)
	return policy_read_member_action_result(L, "structs.field", field_name, allow_tag = true, allow_default = false)
}

// procs.param(param) → nil | { type?, default? }
policy_proc_param_action :: proc(policy: ^Policy, proc_name, param_name, type_spelling: string) -> (action: Member_Action, decided: bool) {
	if !policy.has_proc_param {
		return {}, false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "procs")
	lua.getfield(L, -1, "param")
	lua.remove(L, -2)
	lua.createtable(L, 0, 3)
	push_string_field(L, "proc_name", proc_name)
	push_string_field(L, "name", param_name)
	push_string_field(L, "type", type_spelling)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config procs.param failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2)
	return policy_read_member_action_result(L, "procs.param", param_name, allow_tag = false, allow_default = true)
}

// procs.result(result) → nil | { type? }
// View fields: proc_name, type.
policy_proc_result_action :: proc(policy: ^Policy, proc_name, type_spelling: string) -> (action: Member_Action, decided: bool) {
	if !policy.has_proc_result {
		return {}, false
	}
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	lua.getfield(L, -1, "procs")
	lua.getfield(L, -1, "result")
	lua.remove(L, -2)
	lua.createtable(L, 0, 2)
	push_string_field(L, "proc_name", proc_name)
	push_string_field(L, "type", type_spelling)
	if lua.pcall(L, 1, 1, 0) != 0 {
		fmt.eprintfln("h2odin: config procs.result failed: %s", lua.tostring(L, -1))
		os.exit(1)
	}
	defer lua.pop(L, 2)
	return policy_read_member_action_result(L, "procs.result", proc_name, allow_tag = false, allow_default = false)
}

// Result at stack top; nil → decided=false. Table → action.
policy_read_member_action_result :: proc(
	L: ^lua.State,
	callback_path: string,
	subject: string,
	allow_tag: bool,
	allow_default: bool,
) -> (
	action: Member_Action,
	decided: bool,
) {
	if lua.isnil(L, -1) {
		return {}, false
	}
	if !lua.istable(L, -1) {
		fmt.eprintfln("h2odin: config %s for %q must return nil or a table", callback_path, subject)
		os.exit(1)
	}
	allowed := make([dynamic]cstring, context.temp_allocator)
	append(&allowed, "type")
	if allow_tag {
		append(&allowed, "tag")
	}
	if allow_default {
		append(&allowed, "default")
	}
	// Only allow known keys on the action table.
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			fmt.eprintfln("h2odin: config %s for %q: action keys must be strings", callback_path, subject)
			os.exit(1)
		}
		k := string(lua.tostring(L, -2))
		if !config_key_in(k, allowed[:]) {
			fmt.eprintfln("h2odin: config %s for %q: unknown action key %q", callback_path, subject, k)
			os.exit(1)
		}
		lua.pop(L, 1)
	}
	if lua.getfield(L, -1, "type"); !lua.isnil(L, -1) {
		if lua.type(L, -1) != .STRING {
			fmt.eprintfln("h2odin: config %s for %q: type must be a string", callback_path, subject)
			os.exit(1)
		}
		action.type = strings.clone(string(lua.tostring(L, -1)))
	}
	lua.pop(L, 1)
	if allow_tag {
		if lua.getfield(L, -1, "tag"); !lua.isnil(L, -1) {
			if lua.type(L, -1) != .STRING {
				fmt.eprintfln("h2odin: config %s for %q: tag must be a string", callback_path, subject)
				os.exit(1)
			}
			action.tag = strings.clone(string(lua.tostring(L, -1)))
		}
		lua.pop(L, 1)
	}
	if allow_default {
		if lua.getfield(L, -1, "default"); !lua.isnil(L, -1) {
			if lua.type(L, -1) != .STRING {
				fmt.eprintfln("h2odin: config %s for %q: default must be a string", callback_path, subject)
				os.exit(1)
			}
			action.default = strings.clone(string(lua.tostring(L, -1)))
		}
		lua.pop(L, 1)
	}
	if action.type == "" && action.tag == "" && action.default == "" {
		return {}, false
	}
	return action, true
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
