package h2odin

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"
import "core:path/filepath"
import "core:strings"

// H2Odin is a pipeline: Extraction → Analysis → Transformation → Emission.
// main owns the generation arena and the stage order; the stages own
// everything else.
main :: proc() {
	mode := Type_Mode.ABI
	mode_from_cli := false
	header_path: string
	config_path: string
	for arg in os.args[1:] {
		if strings.has_prefix(arg, "-mode:") {
			switch arg[len("-mode:"):] {
			case "abi":
				mode = .ABI
			case "idiomatic":
				mode = .Idiomatic
			case:
				usage()
			}
			mode_from_cli = true
		} else if strings.has_prefix(arg, "-config:") {
			config_path = arg[len("-config:"):]
		} else if header_path == "" {
			header_path = arg
		} else {
			usage()
		}
	}
	if header_path == "" {
		usage()
	}

	// One named generation arena owns the IR and every long-lived string for
	// this run, and is freed once when the run ends. context.allocator is a
	// convenience pointing at it, not the owner.
	arena: vmem.Arena
	if err := vmem.arena_init_growing(&arena); err != nil {
		fmt.eprintln("h2odin: failed to initialise generation arena:", err)
		os.exit(1)
	}
	defer vmem.arena_destroy(&arena)
	context.allocator = vmem.arena_allocator(&arena)

	policy, policy_ok := policy_load(config_path)
	if !policy_ok {
		os.exit(1)
	}
	defer policy_destroy(&policy)

	// An explicit CLI mode wins; otherwise the config decides; otherwise ABI.
	if !mode_from_cli && policy.type_mode_is_set {
		mode = policy.type_mode
	}

	ir: IR
	ir_init(&ir)

	if !extract(header_path, &ir) {
		os.exit(1)
	}
	analyze(&ir)
	transform(&ir, mode)

	// The package and foreign library names default to the header's stem;
	// the config may override either.
	stem := filepath.stem(filepath.base(header_path))
	opts := Emit_Options {
		package_name = policy.package_name if policy.package_name != "" else stem,
		foreign_lib  = policy.foreign_lib if policy.foreign_lib != "" else stem,
	}
	code := emit(&ir, opts)
	fmt.print(code)
}

usage :: proc() -> ! {
	fmt.eprintln("usage: h2odin [-mode:abi|idiomatic] [-config:file.lua] <header.h>")
	os.exit(2)
}
