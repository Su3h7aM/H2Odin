package h2odin

import "core:fmt"
import "core:mem/virtual"

import clang "vendored:libclang"

// Milestone 0: prove the foundations.
//   - libclang links and a call succeeds (print its version).
//   - the generation arena is created, installed as context.allocator for the
//     run scope, and freed at the end.
main :: proc() {
	// One named arena owns all long-lived memory for a generation run.
	arena: virtual.Arena
	if err := virtual.arena_init_growing(&arena); err != nil {
		fmt.eprintln("failed to initialise generation arena:", err)
		return
	}
	defer virtual.arena_destroy(&arena)

	// context.allocator is a convenience over the arena, not the owner.
	context.allocator = virtual.arena_allocator(&arena)

	// First real libclang call: proves the binding links end-to-end.
	// The CXString is foreign-owned, so dispose it once we are done.
	version := clang.getClangVersion()
	defer clang.disposeString(version)

	fmt.println(clang.getCString(version))
}
