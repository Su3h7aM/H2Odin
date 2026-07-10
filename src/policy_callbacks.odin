package h2odin

import "core:fmt"
import "core:os"
import "core:strings"

import lua "vendor:lua/5.4"

// Runtime callback dispatch consulted by Transformation. Views are small
// read-only tables; return values are decisions, never IR handles.

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
