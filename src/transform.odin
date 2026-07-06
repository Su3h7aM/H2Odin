package h2odin

// Transformation is where decisions are made. It reads the analyzed IR
// together with the configuration policy and records the choices — renames,
// drops, type picks, conversions. It is the only stage that consults policy.
//
// Milestone 1: no policy layer exists yet (Lua arrives in Milestone 5) and
// ABI mode has no decisions to make for builtin types, so this is a
// pass-through.
transform :: proc(ir: ^IR) {
	_ = ir
}
