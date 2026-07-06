package h2odin

import "core:fmt"
import "core:mem/virtual"
import "core:os"
import "core:path/filepath"

// H2Odin is a pipeline: Extraction → Analysis → Transformation → Emission.
// main owns the generation arena and the stage order; the stages own
// everything else.
main :: proc() {
	if len(os.args) != 2 {
		fmt.eprintln("usage: h2odin <header.h>")
		os.exit(2)
	}
	header_path := os.args[1]

	// One named generation arena owns the IR and every long-lived string for
	// this run, and is freed once when the run ends. context.allocator is a
	// convenience pointing at it, not the owner.
	arena: virtual.Arena
	if err := virtual.arena_init_growing(&arena); err != nil {
		fmt.eprintln("h2odin: failed to initialise generation arena:", err)
		os.exit(1)
	}
	defer virtual.arena_destroy(&arena)
	context.allocator = virtual.arena_allocator(&arena)

	ir: IR
	ir_init(&ir)

	if !extract(header_path, &ir) {
		os.exit(1)
	}
	analyze(&ir)
	transform(&ir)

	// Until the configuration layer lands, the package and foreign library
	// names both default to the header's stem.
	stem := filepath.stem(filepath.base(header_path))
	code := emit(&ir, Emit_Options{package_name = stem, foreign_lib = stem})
	fmt.print(code)
}
