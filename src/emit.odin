package h2odin

import "core:fmt"
import "core:strings"

// Emission turns the final IR into Odin text. Every decision has already
// been made by the time this runs, so emission only serializes — if
// something in here starts looking like a real decision, it belongs in an
// earlier stage.
// Assembly and the prelude live here; declaration and type serialization are
// split into emit_decls.odin and emit_types.odin.

Emit_Options :: struct {
	package_name:      string,
	foreign_lib:       string, // import_lib shorthand when foreign_targets is empty
	foreign_targets:   []Foreign_Target, // structured per-OS linkage
	link_prefix:       string, // foreign.link_prefix; "" = none
	procedures_at_end: bool, // true: types then foreign; false: source order
	emit_comments:     bool, // false: suppress doc-comment passthrough
}

// Imports the body may need; prelude writes only those that were used.
Emit_Imports :: struct {
	core_c: bool, // import "core:c"
	posix:  bool, // import "core:sys/posix" for posix.* spellings
	libc:   bool, // import "core:c/libc" for libc.* spellings
	win32:  bool, // import win32 "core:sys/windows" (for win32.* spellings)
}

// One self-contained generated Odin file (package + prelude + decls).
Generated_File :: struct {
	filename: string, // relative basename, e.g. "Index.odin"
	stem:     string, // for footer lookup
	content:  string,
}

Emit_Result :: struct {
	files: []Generated_File,
}

// Write @(link_prefix=…, require_results) when either is set.
write_foreign_block_attrs :: proc(b: ^strings.Builder, link_prefix: string, require_results: bool) {
	if link_prefix == "" && !require_results {
		return
	}
	strings.write_string(b, "@(")
	if link_prefix != "" {
		fmt.sbprintf(b, "link_prefix = %q", link_prefix)
		if require_results {
			strings.write_string(b, ", ")
		}
	}
	if require_results {
		strings.write_string(b, "require_results")
	}
	strings.write_string(b, ")\n")
}

emit_open_foreign :: proc(b: ^strings.Builder, in_foreign: ^bool, link_prefix: string, require_results := false) {
	if in_foreign^ {
		return
	}
	write_foreign_block_attrs(b, link_prefix, require_results)
	strings.write_string(b, "foreign lib {\n")
	in_foreign^ = true
}

emit_close_foreign :: proc(b: ^strings.Builder, in_foreign: ^bool) {
	if !in_foreign^ {
		return
	}
	strings.write_string(b, "}\n")
	in_foreign^ = false
}

emit_write_prelude :: proc(b: ^strings.Builder, options: Emit_Options, imports: Emit_Imports, needs_foreign: bool) {
	fmt.sbprintfln(b, "package %s", options.package_name)
	strings.write_string(b, "\n")
	if imports.core_c {
		strings.write_string(b, "import \"core:c\"\n")
	}
	if imports.libc {
		// Package name is the last path segment: spellings use libc.T.
		strings.write_string(b, "import \"core:c/libc\"\n")
	}
	if imports.posix {
		strings.write_string(b, "import \"core:sys/posix\"\n")
	}
	if imports.win32 {
		// Alias matches vendor:curl / core:sys/windows usage: win32.sockaddr.
		strings.write_string(b, "import win32 \"core:sys/windows\"\n")
	}
	if imports.core_c || imports.libc || imports.posix || imports.win32 {
		strings.write_string(b, "\n")
	}
	// Type-only / empty units must not declare an unused foreign import:
	// -vet treats that as an error and per_header layout emits one file per
	// input (macros-only headers become package-only files).
	if needs_foreign {
		emit_write_foreign_import(b, options)
	}
}

// True when every Func in decls has require_results and there is at least one.
// Used for block-level @(require_results) compression.
foreign_decls_all_require_results :: proc(ir: ^IR, decls: []Decl_Ref) -> bool {
	procedure_count := 0
	for declaration in decls {
		if declaration.kind != .Func {
			continue
		}
		procedure_count += 1
		if !ir.funcs[declaration.index].require_results {
			return false
		}
	}
	return procedure_count > 0
}

// Per-index flag: the contiguous Func/Var foreign segment containing this
// decl has block-level require_results (every Func in the segment sets it).
compute_foreign_segment_require_results :: proc(ir: ^IR, decls: []Decl_Ref) -> []bool {
	require_results := make([]bool, len(decls), context.temp_allocator)
	segment_start := 0
	for segment_start < len(decls) {
		kind := decls[segment_start].kind
		if kind != .Func && kind != .Var {
			segment_start += 1
			continue
		}
		segment_end := segment_start
		for segment_end < len(decls) {
			segment_kind := decls[segment_end].kind
			if segment_kind != .Func && segment_kind != .Var {
				break
			}
			segment_end += 1
		}
		all_require_results := foreign_decls_all_require_results(ir, decls[segment_start:segment_end])
		for declaration_index in segment_start ..< segment_end {
			require_results[declaration_index] = all_require_results
		}
		segment_start = segment_end
	}
	return require_results
}

// Serialize each planned output unit. Decl placement is already decided.
emit :: proc(ir: ^IR, plan: Output_Plan, options: Emit_Options) -> Emit_Result {
	files := make([]Generated_File, len(plan.units))
	for unit, unit_index in plan.units {
		body: strings.Builder
		strings.builder_init(&body, context.temp_allocator)
		imports, needs_foreign := emit_unit_body(&body, ir, unit.decls, options)

		file_builder: strings.Builder
		emit_write_prelude(&file_builder, options, imports, needs_foreign)
		strings.write_string(&file_builder, strings.to_string(body))
		files[unit_index] = Generated_File {
			// Output planning is scratch-owned; the result must not retain it.
			filename = strings.clone(unit.filename),
			stem     = strings.clone(unit.stem),
			content  = strings.to_string(file_builder),
		}
	}
	return Emit_Result{files = files}
}

// Build one unit's declaration body into caller-owned scratch storage. Returns
// the imports and foreign state needed to prepend the unit's final prelude.
emit_unit_body :: proc(body: ^strings.Builder, ir: ^IR, decls: []Decl_Ref, options: Emit_Options) -> (imports: Emit_Imports, needs_foreign: bool) {
	imports = {}
	in_foreign := false
	needs_foreign = false

	if options.procedures_at_end {
		block_require_results := foreign_decls_all_require_results(ir, decls)
		// Types and constants retain their relative order at the front.
		for ref in decls {
			switch ref.kind {
			case .Invalid, .Func, .Var, .Wrapper:
			case .Record:
				emit_record(body, ir, ir.records[ref.index], options.emit_comments, &imports)
			case .Enum:
				emit_enum(body, ir, ir.enums[ref.index], options.emit_comments, &imports)
			case .Typedef:
				emit_typedef(body, ir, ir.typedefs[ref.index], options.emit_comments, &imports)
			case .Macro:
				emit_macro(body, ir.macros[ref.index], options.emit_comments)
			case .Bit_Set:
				emit_bit_set(body, ir, ir.bit_sets[ref.index], options.emit_comments, &imports)
			}
		}

		// Foreign declarations share one block after the types.
		for ref in decls {
			switch ref.kind {
			case .Func:
				needs_foreign = true
				emit_open_foreign(body, &in_foreign, options.link_prefix, block_require_results)
				emit_function(body, ir, ir.funcs[ref.index], options.emit_comments, &imports, block_require_results)
			case .Var:
				needs_foreign = true
				emit_open_foreign(body, &in_foreign, options.link_prefix, block_require_results)
				emit_variable(body, ir, ir.vars[ref.index], options.emit_comments, &imports)
			case .Invalid, .Record, .Enum, .Typedef, .Macro, .Bit_Set, .Wrapper:
			}
		}
		emit_close_foreign(body, &in_foreign)

		// Wrappers are ordinary Odin procedures and follow the foreign block so
		// they can call its internal declaration names.
		for ref in decls {
			if ref.kind == .Wrapper {
				emit_wrapper(body, ir, ir.wrappers[ref.index], options.emit_comments, &imports)
			}
		}
		return imports, needs_foreign
	}

	segment_require_results := compute_foreign_segment_require_results(ir, decls)
	for ref, declaration_index in decls {
		switch ref.kind {
		case .Invalid:
		case .Func:
			needs_foreign = true
			emit_open_foreign(body, &in_foreign, options.link_prefix, segment_require_results[declaration_index])
			emit_function(body, ir, ir.funcs[ref.index], options.emit_comments, &imports, segment_require_results[declaration_index])
		case .Var:
			needs_foreign = true
			emit_open_foreign(body, &in_foreign, options.link_prefix, segment_require_results[declaration_index])
			emit_variable(body, ir, ir.vars[ref.index], options.emit_comments, &imports)
		case .Record:
			emit_close_foreign(body, &in_foreign)
			emit_record(body, ir, ir.records[ref.index], options.emit_comments, &imports)
		case .Enum:
			emit_close_foreign(body, &in_foreign)
			emit_enum(body, ir, ir.enums[ref.index], options.emit_comments, &imports)
		case .Typedef:
			emit_close_foreign(body, &in_foreign)
			emit_typedef(body, ir, ir.typedefs[ref.index], options.emit_comments, &imports)
		case .Macro:
			emit_close_foreign(body, &in_foreign)
			emit_macro(body, ir.macros[ref.index], options.emit_comments)
		case .Bit_Set:
			emit_close_foreign(body, &in_foreign)
			emit_bit_set(body, ir, ir.bit_sets[ref.index], options.emit_comments, &imports)
		case .Wrapper:
			emit_close_foreign(body, &in_foreign)
			emit_wrapper(body, ir, ir.wrappers[ref.index], options.emit_comments, &imports)
		}
	}
	emit_close_foreign(body, &in_foreign)
	return imports, needs_foreign
}
