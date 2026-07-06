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
	header_path: string
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

	ir: IR
	ir_init(&ir)

	if !extract(header_path, &ir) {
		os.exit(1)
	}
	analyze(&ir)
	transform(&ir, mode)

	// Until the configuration layer lands, the package and foreign library
	// names both default to the header's stem.
	stem := filepath.stem(filepath.base(header_path))
	code := emit(&ir, Emit_Options{package_name = stem, foreign_lib = stem})
	fmt.print(code)
}

usage :: proc() -> ! {
	fmt.eprintln("usage: h2odin [-mode:abi|idiomatic] <header.h>")
	os.exit(2)
}
