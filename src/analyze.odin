package h2odin

// Analysis adds facts to the IR — things provably true about the C API
// regardless of any configuration. It reads and annotates; it decides
// nothing, and it consults no policy, so it is deterministic without caveats.
//
// Milestone 1: there are no facts to gather yet. The stage exists so the
// pipeline frame is complete; the first real facts (length-like parameter
// hints) arrive with pointer lowering.
analyze :: proc(ir: ^IR) {
	_ = ir
}
