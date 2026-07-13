package h2odin

import "core:c"
import "core:fmt"
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
// Config is a Lua program that `require "h2odin"` and
// builds a sectioned object via `h2o.config()`. Flat legacy keys are
// rejected with migration messages rather than accepted alongside the new
// surface.
//
// File layout:
//   policy.odin           — Policy, load/destroy, top-level orchestration
//   policy_sandbox.odin   — sandboxed VM, require, path_is_under
//   policy_helpers.odin   — Odin→Lua helper shims (h2o.str / naming / macro views)
//   policy_lua.odin       — generic Lua↔Odin marshalling
//   policy_sections.odin  — per-section config readers
//   policy_callbacks.odin — runtime callback dispatch for Transformation

CONFIG_REGISTRY_KEY :: "h2odin.config"
CONFIG_DIR_REGISTRY_KEY :: "h2odin.config_dir"


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
	"comments",
	"diagnostics",
}

// Pre-M8 flat keys — rejected by name (keep's polarity must not dual-exist).
@(rodata)
CONFIG_LEGACY_KEYS := [?]cstring{"foreign_lib", "strip_prefixes", "type_map", "rename", "keep"}

@(rodata)
CONFIG_UNSUPPORTED_KEYS := [?]cstring{"headers", "include_dirs", "defines", "wrappers"}

@(rodata)
STRIP_KIND_KEYS := [?]cstring{"proc", "type", "const", "enum_value"}

// Sections h2o.config() creates but that have no wired fields yet. Empty
// tables / nil are fine; any real content fails the load.
@(rodata)
CONFIG_UNWIRED_SECTIONS := [?]cstring{}

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
	// Local diagnostics overrides beat config.diagnostics for this group.
	diag_overrides:       Diag_Local_Overrides,
}

Enum_Anonymous_Rule :: struct {
	name:         string, // Odin name to give the anonymous enum
	first_member: string, // match by first member's C name
}

Enum_Bit_Set_Rule :: struct {
	enum_name:      string, // C enum to transform
	name:           string, // Odin bit_set type name
	mode:           string, // must be "log2" today
	// Local diagnostics overrides beat config.diagnostics for this rule.
	diag_overrides: Diag_Local_Overrides,
}

// A type/tag/default/pointer action from structs.fields / procs.params.
// Empty strings mean "not set"; callbacks may refine further.
Member_Action :: struct {
	type:    string,
	tag:     string, // structs only
	default: string, // procs only
	// procs only: "" | "multi" — foreign multipointer [^]T (ABI-identical).
	pointer: string,
	// procs only, idiomatic mode: emit #by_ptr (call-borrowed non-null).
	by_ptr:  bool,
}

// One pointer+count pair selected for an input-slice conversion.
Wrapper_Slice_Rule :: struct {
	pointer: string, // C param name
	count:   string, // C param name
	name:    string, // public slice name; "" → use pointer name
}

// Declarative procs.wrappers entry (config names the conversion only).
Wrapper_Rule :: struct {
	out_params:        []string, // C param names → named results
	slices:            []Wrapper_Slice_Rule,
	// Default true: keep the C return as a named result when non-void.
	keep_c_return:     bool,
	// True when keep_return was set explicitly in config.
	keep_c_return_set: bool,
}

// config.output.layout — closed enum; unknown strings fail config loading.
Output_Layout :: enum {
	Merged, // one Odin file (default; preserves pre-M14 behavior)
	Per_Header, // one Odin file per config.inputs header
}

// Policy is the arena-owned, Odin-side view of a loaded Lua configuration.
// Transformation reads this data instead of knowing about Lua. Declarative
// sections are copied into fields; callback booleans indicate which stable,
// read-only symbol/member views should be dispatched through the policy layer.
// Lua callbacks return decisions or nil to keep H2Odin's default.
Policy :: struct {
	// Private to the policy_* procedures. nil when no config was given.
	state:               ^lua.State,

	// Directory containing the config file (absolute). Used to resolve
	// relative inputs and preprocess paths. Empty when no config was given.
	config_dir:          string,

	// Declarative settings copied out of the config; "" means absent.
	package_name:        string,
	foreign_lib:         string, // foreign.import_lib (shorthand; mutually exclusive with targets)
	// foreign.targets — ordered after load via sort_foreign_targets. Empty when
	// using the import_lib shorthand.
	foreign_targets:     []Foreign_Target,
	foreign_link_prefix: string, // foreign.link_prefix — C symbol prefix
	type_mode:           Type_Mode,
	type_mode_is_set:    bool,

	// Multi-header inputs and clang preprocess knobs.
	inputs:              []string,
	include_paths:       []string,
	defines:             map[string]string, // NAME → value ("" when -DNAME alone)
	// preprocess.resource_dir — explicit -resource-dir for builtin headers.
	// Empty: query the clang driver (see clang_executable).
	resource_dir:        string,
	// preprocess.clang — driver used only for `-print-resource-dir` when
	// resource_dir is empty. Empty → "clang" on PATH.
	clang_executable:    string,

	// Output layout.
	output_folder:       string,
	output_layout:       Output_Layout, // config.output.layout; default .Merged
	procedures_at_end:   bool, // default true when output section absent
	footer_per_header:   bool,
	emit_comments:       bool, // config.comments; default true

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

	// types.map rewrites references; types.overrides rewrites the declaration
	// (typedef → named alias; record/enum → drop + inline spelling).
	type_map:            map[string]string,
	type_overrides:      map[string]string,
	// types.distinct: void* typedef C names that opt into `distinct rawptr`
	// (incomplete-record handles are distinct automatically).
	types_distinct:      []string,
	// types.opaque: per-name override for incomplete tag handle style
	// (true = force handle, false = force faithful; mode supplies default).
	types_opaque:        map[string]bool,

	// symbols.remove declarative tiers.
	remove_names:        []string,
	remove_patterns:     []string,
	// Drop C-deprecated declarations (fourth declarative tier).
	remove_deprecated:   bool,

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
	// procs.require_results: C proc names that get @(require_results).
	require_results:     []string,
	// procs.wrappers: C proc name → closed conversion plan (idiomatic only).
	proc_wrappers:       map[string]Wrapper_Rule,

	// Callbacks present in the config (checked once at load).
	has_rename:          bool, // naming.override
	has_remove_where:    bool, // symbols.remove.where
	has_enum_member:     bool, // enums.member
	has_struct_field:    bool, // structs.field
	has_proc_param:      bool, // procs.param
	has_proc_result:     bool, // procs.result

	// config.diagnostics: per-category severity. Zero value is Warn for
	// every category (default posture). Local constructor overrides beat
	// these when present on a rule.
	diag_severity:       [Diag_Category]Diag_Severity,
}

Symbol_Kind :: enum {
	Func,
	Type, // struct/union/enum/typedef names
	Var,
	Const, // macro constants
	Enum_Member,
	Field,
	Param, // procedure parameter names
}

// Kind names as Lua sees them — Odin vocabulary.
@(rodata)
symbol_kind_names := [Symbol_Kind]cstring {
	.Func        = "proc",
	.Type        = "type",
	.Var         = "var",
	.Const       = "const",
	.Enum_Member = "enum_value",
	.Field       = "field",
	.Param       = "param",
}

Symbol_Context :: struct {
	name:         string, // original C name
	default_name: string, // generator's default choice
	kind:         Symbol_Kind,
	parent:       string, // owning declaration for members/fields; "" otherwise
	// C deprecation fact for symbols.remove.where / naming views.
	deprecated:   bool,
}

// Load and execute the Lua configuration once, at startup. Declarative
// fields are copied into the Policy; the table stays in the registry for
// callback queries. Failure leaves no live Lua state for the caller.
policy_load :: proc(path: string) -> (policy: Policy, ok: bool) {
	if path == "" {
		// Same emission defaults as a config with empty sections.
		empty := Policy {
			procedures_at_end = true,
			emit_comments     = true,
		}
		policy_set_diag_defaults(&empty)
		return empty, true
	}

	L := lua.L_newstate()
	if L == nil {
		user_error("h2odin: failed to create the Lua state")
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
		user_errorf("h2odin: config error: %s", lua.tostring(L, -1))
		lua.close(L)
		return {}, false
	}
	if !lua.istable(L, -1) {
		user_errorf("h2odin: config %q must return a table", path)
		lua.close(L)
		return {}, false
	}

	policy.state = L
	lua.setfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)

	// Defaults before reading config so config.diagnostics can override.
	policy_set_diag_defaults(&policy)

	if !policy_validate_keys(&policy) || !policy_read_config(&policy) {
		// Partial declarative fields may already be allocated on the caller's
		// allocator (tests use the tracking allocator; main uses the generation
		// arena). Free them before closing Lua so failed loads do not leak.
		policy_free_owned(&policy)
		policy_destroy(&policy)
		return {}, false
	}
	// Clone only after a successful load so failed validation does not leak.
	policy.config_dir = strings.clone(config_dir)
	return policy, true
}

// Free every owned string/map/slice on the policy except the Lua state.
// Callers that used a generation arena may skip this (arena destroy covers it);
// tests and policy_load's failure path must call it.
policy_free_owned :: proc(policy: ^Policy) {
	if policy.config_dir != "" {
		delete(policy.config_dir)
		policy.config_dir = ""
	}
	if policy.package_name != "" {
		delete(policy.package_name)
		policy.package_name = ""
	}
	if policy.foreign_lib != "" {
		delete(policy.foreign_lib)
		policy.foreign_lib = ""
	}
	free_foreign_targets(policy.foreign_targets)
	policy.foreign_targets = nil
	if policy.foreign_link_prefix != "" {
		delete(policy.foreign_link_prefix)
		policy.foreign_link_prefix = ""
	}
	if policy.output_folder != "" {
		delete(policy.output_folder)
		policy.output_folder = ""
	}
	if policy.resource_dir != "" {
		delete(policy.resource_dir)
		policy.resource_dir = ""
	}
	if policy.clang_executable != "" {
		delete(policy.clang_executable)
		policy.clang_executable = ""
	}
	policy_free_string_slice(&policy.inputs)
	policy_free_string_slice(&policy.include_paths)
	policy_free_string_slice(&policy.require_results)
	policy_free_string_map(&policy.defines)
	policy_free_string_slice(&policy.strip_prefix_proc)
	policy_free_string_slice(&policy.strip_prefix_type)
	policy_free_string_slice(&policy.strip_prefix_const)
	policy_free_string_slice(&policy.strip_prefix_enum)
	policy_free_string_slice(&policy.strip_suffix_proc)
	policy_free_string_slice(&policy.strip_suffix_type)
	policy_free_string_slice(&policy.strip_suffix_const)
	policy_free_string_slice(&policy.strip_suffix_enum)
	policy_free_string_slice(&policy.remove_names)
	policy_free_string_slice(&policy.remove_patterns)
	policy_free_string_map(&policy.known_tokens)
	policy_free_string_map(&policy.naming_overrides)
	policy_free_string_map(&policy.type_map)
	policy_free_string_map(&policy.type_overrides)
	policy_free_string_slice(&policy.types_distinct)
	policy_free_string_bool_map(&policy.types_opaque)
	for g in policy.macro_groups {
		delete(g.id)
		delete(g.name)
		delete(g.base_type)
		delete(g.prefix)
		delete(g.member_strip_prefix)
		for s in g.exclude_prefixes {
			delete(s)
		}
		delete(g.exclude_prefixes)
	}
	delete(policy.macro_groups)
	policy.macro_groups = nil
	for r in policy.enum_anonymous {
		delete(r.name)
		delete(r.first_member)
	}
	delete(policy.enum_anonymous)
	policy.enum_anonymous = nil
	for r in policy.enum_bit_sets {
		delete(r.enum_name)
		delete(r.name)
		delete(r.mode)
	}
	delete(policy.enum_bit_sets)
	policy.enum_bit_sets = nil
	policy_free_member_action_map(&policy.struct_fields)
	policy_free_int_map(&policy.struct_align)
	policy_free_member_action_map(&policy.proc_params)
	policy_free_member_action_map(&policy.proc_results)
	policy_free_wrapper_rules(&policy.proc_wrappers)
}

policy_free_wrapper_rules :: proc(m: ^map[string]Wrapper_Rule) {
	if m^ == nil {
		return
	}
	for key, rule in m^ {
		delete(key)
		for s in rule.out_params {
			delete(s)
		}
		delete(rule.out_params)
		for sl in rule.slices {
			delete(sl.pointer)
			delete(sl.count)
			delete(sl.name)
		}
		delete(rule.slices)
	}
	delete(m^)
	m^ = nil
}

policy_free_string_slice :: proc(list: ^[]string) {
	for s in list^ {
		delete(s)
	}
	delete(list^)
	list^ = nil
}

policy_free_string_map :: proc(m: ^map[string]string) {
	if m^ == nil {
		return
	}
	for key, value in m^ {
		delete(key)
		delete(value)
	}
	delete(m^)
	m^ = nil
}

policy_free_string_bool_map :: proc(m: ^map[string]bool) {
	if m^ == nil {
		return
	}
	for key in m^ {
		delete(key)
	}
	delete(m^)
	m^ = nil
}

policy_free_member_action_map :: proc(m: ^map[string]Member_Action) {
	if m^ == nil {
		return
	}
	for key, action in m^ {
		delete(key)
		delete(action.type)
		delete(action.tag)
		delete(action.default)
		delete(action.pointer)
	}
	delete(m^)
	m^ = nil
}

policy_free_int_map :: proc(m: ^map[string]int) {
	if m^ == nil {
		return
	}
	for key in m^ {
		delete(key)
	}
	delete(m^)
	m^ = nil
}

// Categories whose default posture is error rather than warn.
policy_set_diag_defaults :: proc(policy: ^Policy) {
	// types.opaque applied to a complete record would change layout.
	policy.diag_severity[.Opaque_Record_Complete] = .Error
	// Colliding or self-shadowing Odin names produce broken output.
	policy.diag_severity[.Symbol_Collision] = .Error
	// Unrepresentable calling conventions must not silently become `"c"`.
	policy.diag_severity[.Unsupported_Calling_Conv] = .Error
	// Explicit wrapper config that cannot apply is a generation failure.
	policy.diag_severity[.Wrapper_Plan_Failed] = .Error
}

policy_config_dir :: proc(path: string) -> (dir: string, ok: bool) {
	abs_path, abs_err := filepath.abs(path, context.temp_allocator)
	if abs_err != nil {
		user_errorf("h2odin: cannot resolve config path %q", path)
		return "", false
	}
	dir_part := filepath.dir(abs_path)
	if dir_part == "" {
		dir_part = "."
	}
	return dir_part, true
}

// Reject unknown, legacy, and unsupported top-level keys up front.
policy_validate_keys :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) != .STRING {
			user_error("h2odin: config: keys must be strings")
			lua.pop(L, 2)
			return false
		}
		key := string(lua.tostring(L, -2))
		switch {
		case config_key_in(key, CONFIG_KNOWN_KEYS[:]):
			lua.pop(L, 1)
		case config_key_in(key, CONFIG_LEGACY_KEYS[:]):
			user_errorf("h2odin: config: %s", legacy_key_message(key))
			lua.pop(L, 2)
			return false
		case config_key_in(key, CONFIG_UNSUPPORTED_KEYS[:]):
			user_errorf("h2odin: config: %q is not yet supported", key)
			lua.pop(L, 2)
			return false
		case:
			user_errorf("h2odin: config: unknown key %q (use h2o.config() sections: package, type_mode, naming, types, symbols, foreign, …)", key)
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
	// Default: pass through C doc comments into the generated Odin.
	policy.emit_comments = true

	package_name, package_ok := policy_optional_string_top(policy, "package")
	if !package_ok {
		return false
	}
	policy.package_name = package_name

	mode, mode_ok := policy_optional_string_top(policy, "type_mode")
	if !mode_ok {
		return false
	}
	defer delete(mode)
	switch mode {
	case "":
	case "abi":
		policy.type_mode = .ABI
		policy.type_mode_is_set = true
	case "idiomatic":
		policy.type_mode = .Idiomatic
		policy.type_mode_is_set = true
	case:
		user_errorf("h2odin: config: type_mode must be \"abi\" or \"idiomatic\", got %q", mode)
		return false
	}

	return(
		policy_read_inputs(policy) &&
		policy_read_output_folder(policy) &&
		policy_read_comments(policy) &&
		policy_read_preprocess(policy) &&
		policy_read_foreign(policy) &&
		policy_read_naming(policy) &&
		policy_read_types(policy) &&
		policy_read_symbols(policy) &&
		policy_read_macros(policy) &&
		policy_read_enums(policy) &&
		policy_read_structs(policy) &&
		policy_read_procs(policy) &&
		policy_read_output(policy) &&
		policy_read_diagnostics(policy) \
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
	user_errorf("h2odin: config: %s is not yet supported", key)
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

policy_destroy :: proc(policy: ^Policy) {
	if policy.state != nil {
		lua.close(policy.state)
		policy.state = nil
	}
}
