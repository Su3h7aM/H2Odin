package h2odin

import "core:fmt"
import "core:path/filepath"
import "core:strings"

// Output planning is Transformation's last decision: which live declarations
// go into which generated Odin file. Emission only serializes the plan.

Output_Unit :: struct {
	filename: string, // relative basename, e.g. "Index.odin"
	stem:     string, // basename stem for footer lookup
	decls:    []Decl_Ref, // relative order preserved from ir.order
}

Output_Plan :: struct {
	units: []Output_Unit,
}

// Partition the final ordering list into output units according to
// policy.output_layout. Fails before any write on collisions, missing homes,
// or option combinations incompatible with the layout.
plan_outputs :: proc(ir: ^IR, policy: ^Policy) -> (plan: Output_Plan, ok: bool) {
	switch policy.output_layout {
	case .Merged:
		return plan_merged(ir, policy)
	case .Per_Header:
		return plan_per_header(ir, policy)
	}
	user_error("h2odin: internal error: unknown output layout")
	return {}, false
}

plan_merged :: proc(ir: ^IR, policy: ^Policy) -> (plan: Output_Plan, ok: bool) {
	if len(ir.input_headers) < 2 {
		user_error("h2odin: internal error: no input headers registered for output planning")
		return {}, false
	}
	// First real header (slot 0 is the empty sentinel).
	first_path := ir.input_headers[1]
	stem := filepath.stem(filepath.base(first_path))
	decls := make([]Decl_Ref, len(ir.order))
	for ref, i in ir.order {
		decls[i] = ref
	}
	unit := Output_Unit {
		filename = strings.clone(fmt.tprintf("%s.odin", stem)),
		stem     = strings.clone(stem),
		decls    = decls,
	}
	units := make([]Output_Unit, 1)
	units[0] = unit
	return Output_Plan{units = units}, true
}

plan_per_header :: proc(ir: ^IR, policy: ^Policy) -> (plan: Output_Plan, ok: bool) {
	if policy.output_folder == "" {
		user_error("h2odin: output.layout = \"per_header\" requires config.output_folder")
		return {}, false
	}
	// Real headers: slots 1..n-1 of input_headers.
	n := len(ir.input_headers) - 1
	if n < 1 {
		user_error("h2odin: internal error: no input headers registered for per_header planning")
		return {}, false
	}

	// Collision check: stem → first input path that claimed it.
	stem_owner := make(map[string]string, context.temp_allocator)
	stems := make([]string, n, context.temp_allocator)
	for i in 0 ..< n {
		path := ir.input_headers[i + 1]
		stem := filepath.stem(filepath.base(path))
		stems[i] = stem
		if prev, found := stem_owner[stem]; found {
			user_errorf("h2odin: duplicate output filename %q.odin from inputs %q and %q", stem, prev, path)
			return {}, false
		}
		stem_owner[stem] = path
	}

	// Bucket decls by home, preserving ir.order relative order.
	buckets := make([][dynamic]Decl_Ref, n, context.temp_allocator)
	for ref in ir.order {
		if ref.kind == .Invalid {
			continue
		}
		home := ir_decl_home(ir, ref)
		if home == 0 {
			name := decl_ref_name(ir, ref)
			user_errorf("h2odin: live declaration %q has no home input header (cannot place in per_header layout)", name if name != "" else "(anonymous)")
			return {}, false
		}
		idx := int(home) - 1
		if idx < 0 || idx >= n {
			user_errorf("h2odin: declaration home handle %d is out of range for %d input headers", int(home), n)
			return {}, false
		}
		append(&buckets[idx], ref)
	}

	units := make([]Output_Unit, n)
	for i in 0 ..< n {
		stem := stems[i]
		bucket := buckets[i]
		decls := make([]Decl_Ref, len(bucket))
		for ref, j in bucket {
			decls[j] = ref
		}
		units[i] = Output_Unit {
			filename = strings.clone(fmt.tprintf("%s.odin", stem)),
			stem     = strings.clone(stem),
			decls    = decls,
		}
	}
	return Output_Plan{units = units}, true
}

decl_ref_name :: proc(ir: ^IR, ref: Decl_Ref) -> string {
	switch ref.kind {
	case .Invalid:
		return ""
	case .Func:
		return ir.funcs[ref.index].name
	case .Record:
		return ir.records[ref.index].name
	case .Enum:
		return ir.enums[ref.index].name
	case .Typedef:
		return ir.typedefs[ref.index].name
	case .Var:
		return ir.vars[ref.index].name
	case .Macro:
		return ir.macros[ref.index].name
	case .Bit_Set:
		return ir.bit_sets[ref.index].name
	case .Wrapper:
		return ir.wrappers[ref.index].name
	}
	return ""
}
