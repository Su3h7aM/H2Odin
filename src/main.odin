// H2Odin generates Odin bindings from C headers.
//
// A generation run has four stages:
//
//	Extraction -> Analysis -> Transformation -> Emission
//
// Extraction is the only stage that uses libclang and copies all foreign-owned
// data into the generation arena. Analysis adds configuration-independent facts.
// Transformation is the only stage that consults the Lua-backed policy and makes
// decisions. Emission only serializes the decided IR into Odin source.
//
// Configuration is a sandboxed Lua program that requires `h2odin`, creates a
// sectioned value with `h2o.config()`, and returns it. Configuration selects
// behavior; generated Odin is always authored by H2Odin. The IR uses handles
// rather than pointers because its dense pools may grow during extraction and
// transformation.
//
// Long-lived data belongs to one generation arena. Temporary work uses
// `context.temp_allocator`, and strings received from libclang or Lua are copied
// at their boundary.
package h2odin

import "core:fmt"
import vmem "core:mem/virtual"
import "core:os"

// H2Odin is a pipeline: Extraction → Analysis → Transformation → Emission.
// main owns the generation arena and the stage order; the stages own
// everything else. Generation is steered by a Lua config — the CLI selects
// that config (directory/H2Odin.lua or -config:) and process-level knobs.
main :: proc() {
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
	defer free_all(context.temp_allocator)

	command_line, command_line_ok := parse_command_line(os.args[1:])
	if !command_line_ok {
		usage()
	}

	if !generate_bindings(command_line) {
		os.exit(1)
	}
}

// Run one complete generation after process-level options and memory ownership
// have been established by main.
generate_bindings :: proc(command_line: Command_Line_Options) -> bool {
	policy := policy_load(command_line.config_path) or_return
	defer policy_destroy(&policy)

	mode := Type_Mode.ABI
	if policy.type_mode_is_set {
		mode = policy.type_mode
	}

	input_headers := resolve_input_headers(&policy) or_return
	preprocess := resolve_extract_preprocess(&policy, command_line.resource_dir) or_return

	ir: IR
	ir_init(&ir)

	provenance: Clang_Provenance
	extract(input_headers, &ir, preprocess, &provenance) or_return
	if command_line.verbose {
		report_clang_provenance(provenance)
	}
	analyze(&ir)
	transform(&ir, mode, &policy)

	plan := plan_outputs(&ir, &policy) or_return
	emit_options := resolve_emit_options(&policy, input_headers[0]) or_return
	bit_field_plan := plan_bit_field_emission(&ir, context.temp_allocator)
	for diagnostic in bit_field_plan.diagnostics {
		append(&ir.diagnostics, diagnostic)
	}
	report_pointer_lowering_guesses(&ir, bit_field_plan.opaque_records)
	report_unsupported_calling_conventions(&ir)
	result := emit(&ir, plan, emit_options)

	write_emit_result(result, &policy, command_line.destination) or_return
	// Emit first, then report: errors still leave usable output on disk /
	// stdout when requested, but a non-zero exit marks the run as failed.
	return report_diagnostics(&ir, &policy, command_line.quiet, command_line.verbose)
}
