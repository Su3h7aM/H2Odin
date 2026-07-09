package h2odin

import "core:fmt"

// Record a non-certain decision or honesty note for the end-of-run report.
// The message is formatted into the generation arena (context.allocator).
ir_diag :: proc(ir: ^IR, format: string, args: ..any) {
	append(&ir.diagnostics, fmt.aprintf(format, ..args))
}

// Print every collected non-certain item once, as a single report on stderr.
// Quiet when the run was fully certain — no empty header.
report_diagnostics :: proc(ir: ^IR) {
	n := len(ir.diagnostics)
	if n == 0 {
		return
	}
	label := "decision" if n == 1 else "decisions"
	fmt.eprintfln("h2odin: %d non-certain %s:", n, label)
	for msg in ir.diagnostics {
		fmt.eprintfln("  - %s", msg)
	}
}
