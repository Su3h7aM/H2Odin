package h2odin

import "core:fmt"
import "core:strings"

// Structured per-target foreign linkage.
// Config selects library values and closed target keys; Emission authors the
// `when` / `foreign import` source. foreign.import_lib remains the
// single-library shorthand when targets is absent.

// Closed set of target keys. Enum order is not emit order —
// FOREIGN_TARGET_EMIT_ORDER defines the deterministic when-chain.
Foreign_Target_Key :: enum u8 {
	Fallback,
	Windows,
	Windows_Amd64,
	Windows_I386,
	Windows_Arm64,
	Linux,
	Linux_Amd64,
	Linux_Arm64,
	Darwin,
	Darwin_Amd64,
	Darwin_Arm64,
	Wasm32,
	Wasm64p32,
}

// One target arm: key plus ordered foreign-import path strings ready to emit
// (e.g. "lib/foo.a", "system:pthread"). Paths are already validated.
Foreign_Target :: struct {
	key:   Foreign_Target_Key,
	paths: []string,
}

// Most-specific OS/ARCH first; fallback always last when present.
@(rodata)
FOREIGN_TARGET_EMIT_ORDER := [?]Foreign_Target_Key {
	.Windows_Arm64,
	.Windows_Amd64,
	.Windows_I386,
	.Windows,
	.Linux_Arm64,
	.Linux_Amd64,
	.Linux,
	.Darwin_Arm64,
	.Darwin_Amd64,
	.Darwin,
	.Wasm64p32,
	.Wasm32,
	.Fallback,
}

foreign_target_key_name :: proc(key: Foreign_Target_Key) -> string {
	switch key {
	case .Fallback:
		return "fallback"
	case .Windows:
		return "windows"
	case .Windows_Amd64:
		return "windows_amd64"
	case .Windows_I386:
		return "windows_i386"
	case .Windows_Arm64:
		return "windows_arm64"
	case .Linux:
		return "linux"
	case .Linux_Amd64:
		return "linux_amd64"
	case .Linux_Arm64:
		return "linux_arm64"
	case .Darwin:
		return "darwin"
	case .Darwin_Amd64:
		return "darwin_amd64"
	case .Darwin_Arm64:
		return "darwin_arm64"
	case .Wasm32:
		return "wasm32"
	case .Wasm64p32:
		return "wasm64p32"
	}
	return "unknown"
}

foreign_target_key_from_name :: proc(name: string) -> (Foreign_Target_Key, bool) {
	switch name {
	case "fallback":
		return .Fallback, true
	case "windows":
		return .Windows, true
	case "windows_amd64":
		return .Windows_Amd64, true
	case "windows_i386":
		return .Windows_I386, true
	case "windows_arm64":
		return .Windows_Arm64, true
	case "linux":
		return .Linux, true
	case "linux_amd64":
		return .Linux_Amd64, true
	case "linux_arm64":
		return .Linux_Arm64, true
	case "darwin":
		return .Darwin, true
	case "darwin_amd64":
		return .Darwin_Amd64, true
	case "darwin_arm64":
		return .Darwin_Arm64, true
	case "wasm32":
		return .Wasm32, true
	case "wasm64p32":
		return .Wasm64p32, true
	}
	return {}, false
}

// Odin `when` condition for a non-fallback key. Fallback is only used as `else`.
foreign_target_condition :: proc(key: Foreign_Target_Key) -> string {
	switch key {
	case .Fallback:
		return ""
	case .Windows:
		return "ODIN_OS == .Windows"
	case .Windows_Amd64:
		return "ODIN_OS == .Windows && ODIN_ARCH == .amd64"
	case .Windows_I386:
		return "ODIN_OS == .Windows && ODIN_ARCH == .i386"
	case .Windows_Arm64:
		return "ODIN_OS == .Windows && ODIN_ARCH == .arm64"
	case .Linux:
		return "ODIN_OS == .Linux"
	case .Linux_Amd64:
		return "ODIN_OS == .Linux && ODIN_ARCH == .amd64"
	case .Linux_Arm64:
		return "ODIN_OS == .Linux && ODIN_ARCH == .arm64"
	case .Darwin:
		return "ODIN_OS == .Darwin"
	case .Darwin_Amd64:
		return "ODIN_OS == .Darwin && ODIN_ARCH == .amd64"
	case .Darwin_Arm64:
		return "ODIN_OS == .Darwin && ODIN_ARCH == .arm64"
	case .Wasm32:
		return "ODIN_ARCH == .wasm32"
	case .Wasm64p32:
		return "ODIN_ARCH == .wasm64p32"
	}
	return ""
}

// Validate one foreign-import string, whether it is a shorthand system name,
// local path, or system: path. Empty and control/quote characters would emit
// invalid or surprising Odin source.
is_safe_foreign_path :: proc(path: string) -> bool {
	if path == "" {
		return false
	}
	for character_index in 0 ..< len(path) {
		character := path[character_index]
		if character < 0x20 || character == 0x7f || character == '"' || character == '\\' {
			return false
		}
	}
	return true
}

// Turn a system dependency name into a foreign-import path. Already-prefixed
// values are left alone so config can write either "m" or "system:m".
normalize_system_lib_path :: proc(name: string, allocator := context.allocator) -> string {
	if strings.has_prefix(name, "system:") {
		return strings.clone(name, allocator)
	}
	return fmt.aprintf("system:%s", name, allocator = allocator)
}

// Sort targets into FOREIGN_TARGET_EMIT_ORDER. Unknown keys are already rejected
// at load time. Returns a new slice.
sort_foreign_targets :: proc(targets: []Foreign_Target, allocator := context.allocator) -> []Foreign_Target {
	if len(targets) == 0 {
		return nil
	}
	dyn: [dynamic]Foreign_Target
	dyn.allocator = allocator
	for key in FOREIGN_TARGET_EMIT_ORDER {
		for t in targets {
			if t.key == key {
				append(&dyn, t)
			}
		}
	}
	return dyn[:]
}

// Write a foreign import for the given ordered path list. Single path uses
// the one-string form; multiple paths use a block.
write_foreign_import_paths :: proc(b: ^strings.Builder, paths: []string, indent: int) {
	pad := strings.repeat("\t", indent, context.temp_allocator)
	if len(paths) == 0 {
		return
	}
	if len(paths) == 1 {
		fmt.sbprintfln(b, "%sforeign import lib %q", pad, paths[0])
		return
	}
	fmt.sbprintfln(b, "%sforeign import lib {{", pad)
	for p, i in paths {
		comma := "," if i + 1 < len(paths) else ""
		fmt.sbprintfln(b, "%s\t%q%s", pad, p, comma)
	}
	fmt.sbprintfln(b, "%s}}", pad)
}

// Emit the foreign import section: either the import_lib shorthand or a
// deterministic when-chain from foreign.targets.
emit_write_foreign_import :: proc(b: ^strings.Builder, opts: Emit_Options) {
	if len(opts.foreign_targets) == 0 {
		// Shorthand: single system library (pre-M16 behaviour).
		fmt.sbprintfln(b, "foreign import lib %q", fmt.tprintf("system:%s", opts.foreign_lib))
		strings.write_string(b, "\n")
		return
	}

	targets := opts.foreign_targets
	// Sole fallback always applies — no when wrapper.
	if len(targets) == 1 && targets[0].key == .Fallback {
		write_foreign_import_paths(b, targets[0].paths, 0)
		strings.write_string(b, "\n")
		return
	}

	for target, i in targets {
		is_last := i + 1 == len(targets)
		is_fallback := target.key == .Fallback
		switch {
		case i == 0:
			cond := foreign_target_condition(target.key)
			if cond == "" {
				// sort_foreign_targets puts fallback last; first arm must be conditional.
				user_error("h2odin: internal: foreign.targets when-chain started with fallback")
				return
			}
			fmt.sbprintfln(b, "when %s {{", cond)
		case is_fallback && is_last:
			strings.write_string(b, "} else {\n")
		case:
			cond := foreign_target_condition(target.key)
			fmt.sbprintfln(b, "} else when %s {{", cond)
		}
		write_foreign_import_paths(b, target.paths, 1)
	}
	strings.write_string(b, "}\n\n")
}
