package h2odin

import "core:c"
import "core:fmt"
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
	state:            ^lua.State,

	// Declarative settings copied out of the config table; "" means the
	// field was absent and the generator default applies.
	package_name:     string,
	foreign_lib:      string,
	type_mode:        Type_Mode,
	type_mode_is_set: bool,
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
	return policy, true
}

policy_destroy :: proc(policy: ^Policy) {
	if policy.state != nil {
		lua.close(policy.state)
		policy.state = nil
	}
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
