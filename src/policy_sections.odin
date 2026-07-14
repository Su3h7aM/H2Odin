package h2odin

import "core:c"
import "core:fmt"
import "core:strings"

import lua "vendor:lua/5.4"

// Per-section config readers. Called from policy_read_config in order.

// config.comments: boolean. Absent/nil → true (emit docs). false suppresses
// doc-comment passthrough at emission time; extraction still captures them.
policy_read_comments :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "comments")
	#partial switch lua.Type(field_type) {
	case .NIL:
		lua.pop(L, 1)
		return true
	case .BOOLEAN:
		policy.emit_comments = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
		return true
	case:
		user_error("h2odin: config: comments must be a boolean")
		lua.pop(L, 1)
		return false
	}
}

// config.diagnostics: category → "warn" | "error". Absent categories stay
// warn (the default posture). Unknown category names fail the load.
policy_read_diagnostics :: proc(policy: ^Policy) -> bool {
	L := policy.state
	lua.getfield(L, lua.REGISTRYINDEX, CONFIG_REGISTRY_KEY)
	defer lua.pop(L, 1)

	field_type := lua.getfield(L, -1, "diagnostics")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		user_error("h2odin: config: diagnostics must be a table of category → \"warn\"|\"error\"")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	overrides, ok := policy_parse_diag_severity_table(L, -1, "diagnostics")
	if !ok {
		return false
	}
	for cat in Diag_Category {
		if sev, has := overrides.set[cat].?; has {
			policy.diag_severity[cat] = sev
		}
	}
	return true
}

// Table is at `index`. Keys must be known category names; values "warn"/"error".
// Returns a local-overrides shape (Some only for keys that were present).
policy_parse_diag_severity_table :: proc(L: ^lua.State, index: c.int, path: string) -> (out: Diag_Local_Overrides, ok: bool) {
	idx := lua.absindex(L, index)
	lua.pushnil(L)
	for lua.next(L, idx) != 0 {
		// stack: key, value
		if lua.type(L, -2) != .STRING {
			user_errorf("h2odin: config: %s keys must be category name strings", path)
			lua.pop(L, 2)
			return {}, false
		}
		key := string(lua.tostring(L, -2))
		cat, cat_ok := diag_category_from_name(key)
		if !cat_ok {
			user_errorf("h2odin: config: %s: unknown category %q (known: %s)", path, key, diag_known_category_list())
			lua.pop(L, 2)
			return {}, false
		}
		if lua.type(L, -1) != .STRING {
			user_errorf("h2odin: config: %s[%q] must be \"warn\" or \"error\"", path, key)
			lua.pop(L, 2)
			return {}, false
		}
		sev_name := string(lua.tostring(L, -1))
		sev, sev_ok := diag_severity_from_name(sev_name)
		if !sev_ok {
			user_errorf("h2odin: config: %s[%q] must be \"warn\" or \"error\", got %q", path, key, sev_name)
			lua.pop(L, 2)
			return {}, false
		}
		out.set[cat] = sev
		lua.pop(L, 1) // keep key for next
	}
	return out, true
}

// Read optional field "diagnostics" from the table at stack top into local
// overrides. Absent/nil → empty overrides (ok).
policy_read_local_diag_overrides :: proc(L: ^lua.State, path: string) -> (out: Diag_Local_Overrides, ok: bool) {
	field_type := lua.getfield(L, -1, "diagnostics")
	#partial switch lua.Type(field_type) {
	case .NIL:
		lua.pop(L, 1)
		return {}, true
	case .TABLE:
		overrides, parse_ok := policy_parse_diag_severity_table(L, -1, path)
		lua.pop(L, 1)
		if !parse_ok {
			return {}, false
		}
		return overrides, true
	case:
		user_errorf("h2odin: config: %s.diagnostics must be a table", path)
		lua.pop(L, 1)
		return {}, false
	}
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
		user_error("h2odin: config: foreign must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "foreign", []cstring{"import_lib", "link_prefix", "targets"}) {
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

	targets, targets_ok := policy_read_foreign_targets(L)
	if !targets_ok {
		return false
	}
	policy.foreign_targets = targets

	if policy.foreign_lib != "" && len(policy.foreign_targets) > 0 {
		user_error(
			"h2odin: config: foreign.import_lib and foreign.targets are mutually exclusive (use import_lib for a single system library, or targets for per-OS linkage)",
		)
		return false
	}
	return true
}

// Free a partially built foreign.targets list (owned path strings + slice).
free_foreign_targets :: proc(targets: []Foreign_Target) {
	for t in targets {
		for p in t.paths {
			delete(p)
		}
		delete(t.paths)
	}
	delete(targets)
}

free_foreign_targets_dyn :: proc(raw: ^[dynamic]Foreign_Target) {
	free_foreign_targets(raw[:])
	raw^ = nil
}

// Read foreign.targets from the foreign table at stack top. Returns nil when
// the field is absent. Paths are validated; keys must be from the closed set.
// On success, path strings and the returned slice are owned by the caller.
policy_read_foreign_targets :: proc(L: ^lua.State) -> (targets: []Foreign_Target, ok: bool) {
	field_type := lua.getfield(L, -1, "targets")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		user_error("h2odin: config: foreign.targets must be a table keyed by target name")
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	raw: [dynamic]Foreign_Target
	seen: [Foreign_Target_Key]bool

	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		// key at -2, value at -1
		if lua.type(L, -2) != .STRING {
			user_error("h2odin: config: foreign.targets keys must be strings (closed set of target names)")
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		key_name := string(lua.tostring(L, -2))
		key, key_ok := foreign_target_key_from_name(key_name)
		if !key_ok {
			user_errorf(
				"h2odin: config: foreign.targets[%q] is not a known target key (want windows[_amd64|_i386|_arm64], linux[_amd64|_arm64], darwin[_amd64|_arm64], wasm32, wasm64p32, fallback)",
				key_name,
			)
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		if seen[key] {
			user_errorf("h2odin: config: foreign.targets[%q] specified more than once", key_name)
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		seen[key] = true

		if lua.type(L, -1) != .TABLE {
			user_errorf("h2odin: config: foreign.targets[%q] must be a table with libraries / system lists", key_name)
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		if !policy_reject_unknown_subkeys(L, fmt.tprintf("foreign.targets.%s", key_name), []cstring{"libraries", "system"}) {
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}

		paths: [dynamic]string
		libs, libs_ok := policy_string_list_field(L, fmt.tprintf("foreign.targets.%s", key_name), "libraries")
		if !libs_ok {
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		// Transfer ownership of list strings into paths (no second clone).
		for lib in libs {
			if !is_safe_foreign_path(lib) {
				user_errorf(
					"h2odin: config: foreign.targets[%q].libraries entry %q is empty or contains a quote, backslash, or control character",
					key_name,
					lib,
				)
				for p in paths {
					delete(p)
				}
				delete(paths)
				for s in libs {
					delete(s)
				}
				delete(libs)
				lua.pop(L, 2)
				free_foreign_targets_dyn(&raw)
				return nil, false
			}
			append(&paths, lib)
		}
		delete(libs) // free slice header only; strings moved into paths

		sys_list, sys_ok := policy_string_list_field(L, fmt.tprintf("foreign.targets.%s", key_name), "system")
		if !sys_ok {
			for p in paths {
				delete(p)
			}
			delete(paths)
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}
		for sys in sys_list {
			if !is_safe_foreign_path(sys) {
				user_errorf("h2odin: config: foreign.targets[%q].system entry %q is empty or contains a quote, backslash, or control character", key_name, sys)
				for p in paths {
					delete(p)
				}
				delete(paths)
				for s in sys_list {
					delete(s)
				}
				delete(sys_list)
				lua.pop(L, 2)
				free_foreign_targets_dyn(&raw)
				return nil, false
			}
			// normalize allocates; free the raw list string.
			append(&paths, normalize_system_lib_path(sys))
			delete(sys)
		}
		delete(sys_list)

		if len(paths) == 0 {
			user_errorf("h2odin: config: foreign.targets[%q] needs at least one libraries or system entry", key_name)
			delete(paths)
			lua.pop(L, 2)
			free_foreign_targets_dyn(&raw)
			return nil, false
		}

		append(&raw, Foreign_Target{key = key, paths = paths[:]})
		lua.pop(L, 1) // value; keep key for next
	}

	if len(raw) == 0 {
		user_error("h2odin: config: foreign.targets is empty (omit the field or list at least one target)")
		return nil, false
	}

	// sort allocates a new ordered slice; free the unsorted dynamic header.
	sorted := sort_foreign_targets(raw[:])
	delete(raw)
	return sorted, true
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
		user_error("h2odin: config: naming must be a table")
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
		user_error("h2odin: config: naming.override must be a function (plural naming.overrides is the data map)")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: naming.override must be a function")
		lua.pop(L, 1)
		return false
	}

	if lua.Type(lua.getfield(L, -1, "overrides")) == .FUNCTION {
		user_error("h2odin: config: naming.overrides must be a table (plural is data; singular naming.override is the callback)")
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
		user_error("h2odin: config: types must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "types", []cstring{"map", "overrides", "override", "distinct", "opaque"}) {
		return false
	}
	if !policy_reject_nested_if_set(L, "types", "override") {
		return false
	}

	// Plural is data.
	if lua.Type(lua.getfield(L, -1, "overrides")) == .FUNCTION {
		user_error("h2odin: config: types.overrides must be a table (plural is data; singular types.override is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)
	if lua.Type(lua.getfield(L, -1, "map")) == .FUNCTION {
		user_error("h2odin: config: types.map must be a table")
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

	distinct_list, distinct_ok := policy_string_list_field(L, "types", "distinct")
	if !distinct_ok {
		return false
	}
	policy.types_distinct = distinct_list

	opaque_map, opaque_ok := policy_bool_map_nested(L, "types", "opaque")
	if !opaque_ok {
		return false
	}
	policy.types_opaque = opaque_map
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
		user_error("h2odin: config: symbols must be a table")
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
		user_error("h2odin: config: symbols.remove must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "symbols.remove", []cstring{"where", "names", "patterns", "deprecated"}) {
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

	// symbols.remove.deprecated = true → drop every C-deprecated declaration.
	dep_type := lua.Type(lua.getfield(L, -1, "deprecated"))
	#partial switch dep_type {
	case .NIL:
		lua.pop(L, 1)
	case .BOOLEAN:
		policy.remove_deprecated = bool(lua.toboolean(L, -1))
		lua.pop(L, 1)
	case:
		user_error("h2odin: config: symbols.remove.deprecated must be a boolean")
		lua.pop(L, 1)
		return false
	}

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
		user_error("h2odin: config: symbols.remove.where must be a function (predicate callback)")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: symbols.remove.where must be a function")
		lua.pop(L, 1)
		return false
	}
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
		user_error("h2odin: config: macros must be a table")
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
		user_error("h2odin: config: macros.groups must be a list of group tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	groups := make([dynamic]Macro_Group_Enum, 0, n)
	groups_owned := true
	defer if groups_owned {
		for &group in groups {
			policy_free_macro_group(&group)
		}
		delete(groups)
	}
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			user_errorf("h2odin: config: macros.groups[%d] must be a table (use h2o.macro_group.enum{{...}})", i + 1)
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
	groups_owned = false
	return true
}

// Group table is at stack top.
policy_read_macro_group_enum :: proc(L: ^lua.State, lua_index: int) -> (group: Macro_Group_Enum, ok: bool) {
	group_owned := true
	defer if group_owned {
		policy_free_macro_group(&group)
	}
	allowed := []cstring{"id", "name", "base_type", "prefix", "exclude_prefixes", "include", "member_strip_prefix", "emit_original_consts", "diagnostics"}
	if !policy_reject_unknown_subkeys(L, "macros.groups[]", allowed) {
		return group, false
	}

	name, name_ok := policy_optional_string_field(L, "macros.groups[]", "name")
	if !name_ok || name == "" {
		user_error("h2odin: config: macros.groups[] requires name")
		return group, false
	}
	group.name = name
	group.lua_index = lua_index

	id, id_ok := policy_optional_string_field(L, "macros.groups[]", "id")
	if !id_ok {
		return group, false
	}
	group.id = id

	base, base_ok := policy_optional_string_field(L, "macros.groups[]", "base_type")
	if !base_ok {
		return group, false
	}
	group.base_type = base
	if base != "" {
		if _, supported := enum_backing_spelling_signedness(base); !supported {
			user_errorf("h2odin: config: macros.groups[].base_type %q is not a supported integer backing", base)
			return group, false
		}
	}

	prefix, prefix_ok := policy_optional_string_field(L, "macros.groups[]", "prefix")
	if !prefix_ok {
		return group, false
	}
	group.prefix = prefix

	member_strip, member_strip_ok := policy_optional_string_field(L, "macros.groups[]", "member_strip_prefix")
	if !member_strip_ok {
		return group, false
	}
	group.member_strip_prefix = member_strip

	// exclude_prefixes: string or list
	excl, excl_ok := policy_string_or_list_field(L, "macros.groups[]", "exclude_prefixes")
	if !excl_ok {
		return group, false
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
		user_error("h2odin: config: macros.groups[].emit_original_consts must be a boolean")
		lua.pop(L, 1)
		return group, false
	}

	inc_type := lua.Type(lua.getfield(L, -1, "include"))
	#partial switch inc_type {
	case .NIL:
		lua.pop(L, 1)
	case .FUNCTION:
		lua.pop(L, 1)
		group.has_include = true
	case:
		user_error("h2odin: config: macros.groups[].include must be a function")
		lua.pop(L, 1)
		return group, false
	}

	local_diags, local_ok := policy_read_local_diag_overrides(L, "macros.groups[]")
	if !local_ok {
		return group, false
	}
	group.diag_overrides = local_diags

	group_owned = false
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
		user_error("h2odin: config: enums must be a table")
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
		user_error("h2odin: config: enums.member must be a function")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: enums.member must be a function")
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
		user_error("h2odin: config: enums.anonymous must be a list of tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	rules := make([dynamic]Enum_Anonymous_Rule, 0, n)
	rules_owned := true
	defer if rules_owned {
		for &rule in rules {
			policy_free_anonymous_enum_rule(&rule)
		}
		delete(rules)
	}
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			user_errorf("h2odin: config: enums.anonymous[%d] must be a table", i + 1)
			lua.pop(L, 1)
			return false
		}
		rule, rule_ok := policy_read_anonymous_enum_rule(L)
		lua.pop(L, 1)
		if !rule_ok {
			return false
		}
		append(&rules, rule)
	}
	policy.enum_anonymous = rules[:]
	rules_owned = false
	return true
}

// Rule table is at stack top.
policy_read_anonymous_enum_rule :: proc(L: ^lua.State) -> (rule: Enum_Anonymous_Rule, ok: bool) {
	rule_owned := true
	defer if rule_owned {
		policy_free_anonymous_enum_rule(&rule)
	}
	if !policy_reject_unknown_subkeys(L, "enums.anonymous[]", []cstring{"name", "first_member"}) {
		return rule, false
	}
	rule.name, ok = policy_optional_string_field(L, "enums.anonymous[]", "name")
	if !ok {
		return rule, false
	}
	rule.first_member, ok = policy_optional_string_field(L, "enums.anonymous[]", "first_member")
	if !ok {
		return rule, false
	}
	if rule.name == "" || rule.first_member == "" {
		user_error("h2odin: config: enums.anonymous[] requires name and first_member")
		return rule, false
	}
	rule_owned = false
	return rule, true
}

policy_read_enum_bit_sets :: proc(L: ^lua.State, policy: ^Policy) -> bool {
	field_type := lua.getfield(L, -1, "bit_sets")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return true
	}
	if field_type != c.int(lua.Type.TABLE) {
		user_error("h2odin: config: enums.bit_sets must be a list of tables")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if n == 0 {
		return true
	}
	rules := make([dynamic]Enum_Bit_Set_Rule, 0, n)
	rules_owned := true
	defer if rules_owned {
		for &rule in rules {
			policy_free_bit_set_rule(&rule)
		}
		delete(rules)
	}
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			user_errorf("h2odin: config: enums.bit_sets[%d] must be a table", i + 1)
			lua.pop(L, 1)
			return false
		}
		rule, rule_ok := policy_read_bit_set_rule(L)
		lua.pop(L, 1)
		if !rule_ok {
			return false
		}
		append(&rules, rule)
	}
	policy.enum_bit_sets = rules[:]
	rules_owned = false
	return true
}

// Rule table is at stack top.
policy_read_bit_set_rule :: proc(L: ^lua.State) -> (rule: Enum_Bit_Set_Rule, ok: bool) {
	rule_owned := true
	defer if rule_owned {
		policy_free_bit_set_rule(&rule)
	}
	if !policy_reject_unknown_subkeys(L, "enums.bit_sets[]", []cstring{"enum", "name", "mode", "diagnostics"}) {
		return rule, false
	}
	// "enum" is a Lua keyword-friendly field name in the constructor table.
	rule.enum_name, ok = policy_optional_string_field(L, "enums.bit_sets[]", "enum")
	if !ok {
		return rule, false
	}
	rule.name, ok = policy_optional_string_field(L, "enums.bit_sets[]", "name")
	if !ok {
		return rule, false
	}
	rule.mode, ok = policy_optional_string_field(L, "enums.bit_sets[]", "mode")
	if !ok {
		return rule, false
	}
	if rule.enum_name == "" || rule.name == "" {
		user_error("h2odin: config: enums.bit_sets[] requires enum, name, and mode")
		return rule, false
	}
	if rule.mode != "log2" {
		user_errorf("h2odin: config: enums.bit_sets[].mode must be \"log2\", got %q", rule.mode)
		return rule, false
	}
	rule.diag_overrides, ok = policy_read_local_diag_overrides(L, "enums.bit_sets[]")
	if !ok {
		return rule, false
	}
	rule_owned = false
	return rule, true
}

// ---------------------------------------------------------------- Inputs and output

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
		user_error("h2odin: config: preprocess must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "preprocess", []cstring{"include_paths", "defines", "resource_dir", "clang"}) {
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

	resource_dir, resource_ok := policy_optional_string_field(L, "preprocess", "resource_dir")
	if !resource_ok {
		return false
	}
	policy.resource_dir = resource_dir

	clang_exe, clang_ok := policy_optional_string_field(L, "preprocess", "clang")
	if !clang_ok {
		return false
	}
	policy.clang_executable = clang_exe
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
		user_error("h2odin: config: structs must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "structs", []cstring{"fields", "field", "align"}) {
		return false
	}

	// Plural is data; singular is callback.
	if lua.Type(lua.getfield(L, -1, "fields")) == .FUNCTION {
		user_error("h2odin: config: structs.fields must be a table (plural is data; singular structs.field is the callback)")
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
		user_error("h2odin: config: structs.field must be a function (plural structs.fields is the data map)")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: structs.field must be a function")
		lua.pop(L, 1)
		return false
	}

	fields, fields_ok := policy_member_action_map(L, "structs", "fields", allow_tag = true, allow_default = false, allow_pointer = true)
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
		user_error("h2odin: config: procs must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "procs", []cstring{"params", "param", "results", "result", "require_results", "wrappers"}) {
		return false
	}

	if lua.Type(lua.getfield(L, -1, "params")) == .FUNCTION {
		user_error("h2odin: config: procs.params must be a table (plural is data; singular procs.param is the callback)")
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)
	if lua.Type(lua.getfield(L, -1, "results")) == .FUNCTION {
		user_error("h2odin: config: procs.results must be a table (plural is data; singular procs.result is the callback)")
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
		user_error("h2odin: config: procs.param must be a function (plural procs.params is the data map)")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: procs.param must be a function")
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
		user_error("h2odin: config: procs.result must be a function (plural procs.results is the data map)")
		lua.pop(L, 1)
		return false
	case:
		user_error("h2odin: config: procs.result must be a function")
		lua.pop(L, 1)
		return false
	}

	params, params_ok := policy_member_action_map(L, "procs", "params", allow_tag = false, allow_default = true, allow_pointer = true, allow_by_ptr = true)
	if !params_ok {
		return false
	}
	policy.proc_params = params

	results, results_ok := policy_member_action_map(L, "procs", "results", allow_tag = false, allow_default = false)
	if !results_ok {
		return false
	}
	policy.proc_results = results

	if !policy_read_require_results(L, policy) {
		return false
	}

	wrappers, wrappers_ok := policy_read_proc_wrappers(L, policy)
	if !wrappers_ok {
		return false
	}
	policy.proc_wrappers = wrappers
	return true
}

// procs.require_results accepts:
//   - a mode string: "non_void"
//   - a pure list of C procedure names (including {} as a no-op)
//   - a table { mode = "non_void"?, names = { ... }? } for both
// Mode and names compose (union): a procedure gets the attribute if either matches.
// List form and structured form must not be mixed in one table.
// Mode strings are matched in place (Lua-owned until pop); only name lists are
// cloned into the generation arena.
policy_read_require_results :: proc(L: ^lua.State, policy: ^Policy) -> bool {
	field_type := lua.getfield(L, -1, "require_results")
	#partial switch lua.Type(field_type) {
	case .NIL:
		lua.pop(L, 1)
		return true
	case .STRING:
		mode, mode_ok := policy_parse_require_results_mode(string(lua.tostring(L, -1)))
		if !mode_ok {
			lua.pop(L, 1)
			return false
		}
		policy.require_results_mode = mode
		lua.pop(L, 1)
		return true
	case .TABLE:
	// fall through
	case:
		user_error("h2odin: config: procs.require_results must be \"non_void\", a list of names, or { mode, names }")
		lua.pop(L, 1)
		return false
	}
	// Table: pure name list, or structured { mode?, names? }.
	defer lua.pop(L, 1)

	// Classify keys once: pure list (integer keys only) vs structured (string
	// keys only). A hybrid of both forms is rejected with an explicit message.
	has_string_key := false
	has_array_key := false
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		if lua.type(L, -2) == .STRING {
			has_string_key = true
		} else if bool(lua.isinteger(L, -2)) {
			has_array_key = true
		} else {
			user_error("h2odin: config: procs.require_results table keys must be strings or array indices")
			lua.pop(L, 2)
			return false
		}
		lua.pop(L, 1) // value; leave key for next
	}

	if has_string_key && has_array_key {
		user_error("h2odin: config: procs.require_results must not mix a name list with mode/names fields")
		return false
	}

	if !has_string_key {
		// Pure list (or {}). Empty list is a no-op, matching absent config.
		names, names_ok := policy_read_string_list_at_top(L, "procs", "require_results")
		if !names_ok {
			return false
		}
		policy.require_results = names
		return true
	}

	if !policy_reject_unknown_subkeys(L, "procs.require_results", []cstring{"mode", "names"}) {
		return false
	}

	mode, mode_ok := policy_read_require_results_mode_field(L)
	if !mode_ok {
		return false
	}
	policy.require_results_mode = mode

	names, names_ok := policy_string_list_field(L, "procs.require_results", "names")
	if !names_ok {
		return false
	}
	policy.require_results = names

	// Structured form with neither mode nor names is empty config noise.
	// Pure {} is the no-op list form above; require at least one selection here.
	if policy.require_results_mode == .None && len(policy.require_results) == 0 {
		user_error("h2odin: config: procs.require_results table requires mode and/or names")
		return false
	}
	return true
}

// mode field of a structured procs.require_results table. Absent → .None.
// Matches the Lua string without cloning; only the closed enum is stored.
policy_read_require_results_mode_field :: proc(L: ^lua.State) -> (Require_Results_Mode, bool) {
	field_type := lua.getfield(L, -1, "mode")
	#partial switch lua.Type(field_type) {
	case .NIL:
		lua.pop(L, 1)
		return .None, true
	case .STRING:
		parsed, parse_ok := policy_parse_require_results_mode(string(lua.tostring(L, -1)))
		lua.pop(L, 1)
		if !parse_ok {
			return .None, false
		}
		return parsed, true
	case:
		user_error("h2odin: config: procs.require_results.mode must be a string")
		lua.pop(L, 1)
		return .None, false
	}
}

policy_parse_require_results_mode :: proc(mode: string) -> (Require_Results_Mode, bool) {
	switch mode {
	case "non_void":
		return .Non_Void, true
	case:
		user_errorf("h2odin: config: procs.require_results mode must be \"non_void\", got %q", mode)
		return .None, false
	}
}

// procs.wrappers: map C proc name → h2o.proc.wrapper { out_params?, slices?, keep_return? }.
// Idiomatic-only; empty map when absent.
policy_read_proc_wrappers :: proc(L: ^lua.State, policy: ^Policy) -> (result: map[string]Wrapper_Rule, ok: bool) {
	field_type := lua.getfield(L, -1, "wrappers")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		user_error("h2odin: config: procs.wrappers must be a table keyed by C procedure name")
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	// Reject in ABI mode (or when type_mode is unset — defaults to ABI at run).
	if !policy.type_mode_is_set || policy.type_mode != .Idiomatic {
		user_error("h2odin: config: procs.wrappers requires type_mode = \"idiomatic\" (ABI mode never emits procedure bodies)")
		return nil, false
	}

	result = make(map[string]Wrapper_Rule)
	lua.pushnil(L)
	for lua.next(L, -2) != 0 {
		// key at -2, value at -1
		if lua.type(L, -2) != .STRING {
			user_error("h2odin: config: procs.wrappers keys must be C procedure name strings")
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}
		proc_name := strings.clone(string(lua.tostring(L, -2)))
		if lua.type(L, -1) != .TABLE {
			user_errorf("h2odin: config: procs.wrappers[%q] must be a table (use h2o.proc.wrapper {{ … }})", proc_name)
			delete(proc_name)
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}
		if !policy_reject_unknown_subkeys(L, "procs.wrappers[]", []cstring{"out_params", "slices", "keep_return"}) {
			delete(proc_name)
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}

		rule: Wrapper_Rule
		rule.keep_c_return = true // default

		out_list, out_ok := policy_string_list_field(L, "procs.wrappers[]", "out_params")
		if !out_ok {
			delete(proc_name)
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}
		rule.out_params = out_list

		// keep_return optional bool
		keep_ty := lua.getfield(L, -1, "keep_return")
		#partial switch lua.Type(keep_ty) {
		case .NIL:
			lua.pop(L, 1)
		case .BOOLEAN:
			rule.keep_c_return = bool(lua.toboolean(L, -1))
			rule.keep_c_return_set = true
			lua.pop(L, 1)
		case:
			user_error("h2odin: config: procs.wrappers[].keep_return must be a boolean")
			lua.pop(L, 1) // keep_return value
			delete(proc_name)
			for s in rule.out_params {
				delete(s)
			}
			delete(rule.out_params)
			lua.pop(L, 2) // wrapper value + map key
			policy_free_wrapper_rules(&result)
			return nil, false
		}

		slices, slices_ok := policy_read_wrapper_slices(L)
		if !slices_ok {
			delete(proc_name)
			for s in rule.out_params {
				delete(s)
			}
			delete(rule.out_params)
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}
		rule.slices = slices

		if len(rule.out_params) == 0 && len(rule.slices) == 0 {
			user_errorf("h2odin: config: procs.wrappers[%q] needs at least one of out_params or slices", proc_name)
			delete(proc_name)
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
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}

		if proc_name in result {
			user_errorf("h2odin: config: procs.wrappers[%q] specified more than once", proc_name)
			delete(proc_name)
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
			lua.pop(L, 2)
			policy_free_wrapper_rules(&result)
			return nil, false
		}
		result[proc_name] = rule
		lua.pop(L, 1) // value; keep key for next
	}
	return result, true
}

// Read slices list from the wrapper table at stack top.
policy_read_wrapper_slices :: proc(L: ^lua.State) -> (slices: []Wrapper_Slice_Rule, ok: bool) {
	field_type := lua.getfield(L, -1, "slices")
	if field_type == c.int(lua.Type.NIL) {
		lua.pop(L, 1)
		return nil, true
	}
	if field_type != c.int(lua.Type.TABLE) {
		user_error("h2odin: config: procs.wrappers[].slices must be a list of tables")
		lua.pop(L, 1)
		return nil, false
	}
	defer lua.pop(L, 1)

	n := int(lua.L_len(L, -1))
	if !policy_require_pure_list(L, "procs.wrappers[]", "slices", n) {
		return nil, false
	}
	if n == 0 {
		return nil, true
	}
	out := make([dynamic]Wrapper_Slice_Rule, 0, n)
	for i in 0 ..< n {
		elem_type := lua.geti(L, -1, lua.Integer(i + 1))
		if elem_type != c.int(lua.Type.TABLE) {
			user_errorf("h2odin: config: procs.wrappers[].slices[%d] must be a table", i + 1)
			lua.pop(L, 1)
			for sl in out {
				delete(sl.pointer)
				delete(sl.count)
				delete(sl.name)
			}
			delete(out)
			return nil, false
		}
		if !policy_reject_unknown_subkeys(L, "procs.wrappers[].slices[]", []cstring{"pointer", "count", "name"}) {
			lua.pop(L, 1)
			for sl in out {
				delete(sl.pointer)
				delete(sl.count)
				delete(sl.name)
			}
			delete(out)
			return nil, false
		}
		pointer, p_ok := policy_optional_string_field(L, "procs.wrappers[].slices[]", "pointer")
		count, c_ok := policy_optional_string_field(L, "procs.wrappers[].slices[]", "count")
		name, n_ok := policy_optional_string_field(L, "procs.wrappers[].slices[]", "name")
		if !p_ok || !c_ok || !n_ok {
			delete(pointer)
			delete(count)
			delete(name)
			lua.pop(L, 1)
			for sl in out {
				delete(sl.pointer)
				delete(sl.count)
				delete(sl.name)
			}
			delete(out)
			return nil, false
		}
		if pointer == "" || count == "" {
			user_errorf("h2odin: config: procs.wrappers[].slices[%d] requires pointer and count strings", i + 1)
			delete(pointer)
			delete(count)
			delete(name)
			lua.pop(L, 1)
			for sl in out {
				delete(sl.pointer)
				delete(sl.count)
				delete(sl.name)
			}
			delete(out)
			return nil, false
		}
		append(&out, Wrapper_Slice_Rule{pointer = pointer, count = count, name = name})
		lua.pop(L, 1)
	}
	return out[:], true
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
		user_error("h2odin: config: output must be a table")
		lua.pop(L, 1)
		return false
	}
	defer lua.pop(L, 1)

	// Reject removed nested keys with a migration message before
	// the generic unknown-key check.
	removed_type := lua.getfield(L, -1, "imports_file")
	if removed_type != c.int(lua.Type.NIL) {
		user_error(
			`h2odin: config: "output.imports_file" was removed; Odin import and foreign import names are file-local, so a split imports file never compiled`,
		)
		lua.pop(L, 1)
		return false
	}
	lua.pop(L, 1)

	if !policy_reject_unknown_subkeys(L, "output", []cstring{"layout", "procedures_at_end", "footer_per_header"}) {
		return false
	}

	// An absent layout derives from root count during output planning.
	layout_type := lua.getfield(L, -1, "layout")
	#partial switch lua.Type(layout_type) {
	case .NIL:
		lua.pop(L, 1)
	case .STRING:
		layout_str := string(lua.tostring(L, -1))
		lua.pop(L, 1)
		switch layout_str {
		case "merged":
			policy.output_layout = .Merged
		case "per_header":
			policy.output_layout = .Per_Header
		case:
			user_errorf("h2odin: config: output.layout must be \"merged\" or \"per_header\", got %q", layout_str)
			return false
		}
	case:
		user_error("h2odin: config: output.layout must be a string")
		lua.pop(L, 1)
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
		user_error("h2odin: config: output.procedures_at_end must be a boolean")
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
		user_error("h2odin: config: output.footer_per_header must be a boolean")
		lua.pop(L, 1)
		return false
	}

	return true
}
