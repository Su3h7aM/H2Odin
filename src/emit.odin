package h2odin

import "core:fmt"
import "core:strings"

// Emission turns the final IR into Odin text. Every decision has already
// been made by the time this runs, so emission only serializes — if
// something in here starts looking like a real decision, it belongs in an
// earlier stage.
//
// File layout (see docs/source-layout.md): emit.odin is assembly/prelude;
// emit_decls.odin holds per-declaration emitters; emit_types.odin holds
// write_type / write_params.

Emit_Options :: struct {
	package_name:      string,
	foreign_lib:       string,
	link_prefix:       string, // foreign.link_prefix; "" = none
	procedures_at_end: bool, // true: types then foreign; false: source order
	emit_comments:     bool, // false: suppress doc-comment passthrough
}

// Imports the body may need; prelude writes only those that were used.
Emit_Imports :: struct {
	core_c: bool, // import "core:c"
	posix:  bool, // import "core:sys/posix" (for posix.* spellings, spec 0010)
	libc:   bool, // import "core:c/libc"    (for libc.* spellings, spec 0010)
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

emit_open_foreign :: proc(b: ^strings.Builder, in_foreign: ^bool, link_prefix: string) {
	if in_foreign^ {
		return
	}
	if link_prefix != "" {
		fmt.sbprintfln(b, "@(link_prefix = %q)", link_prefix)
	}
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

emit_write_prelude :: proc(b: ^strings.Builder, opts: Emit_Options, imports: Emit_Imports, needs_foreign: bool) {
	fmt.sbprintfln(b, "package %s", opts.package_name)
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
	if imports.core_c || imports.libc || imports.posix {
		strings.write_string(b, "\n")
	}
	// Type-only / empty units must not declare an unused foreign import:
	// -vet treats that as an error and per_header layout emits one file per
	// input (macros-only headers become package-only files).
	if needs_foreign {
		// %q escapes the full system: path so foreign.import_lib content
		// cannot break out of the string literal.
		fmt.sbprintfln(b, "foreign import lib %q", fmt.tprintf("system:%s", opts.foreign_lib))
		strings.write_string(b, "\n")
	}
}

emit_write_foreign_block :: proc(b: ^strings.Builder, foreign_body: string, link_prefix: string) {
	if len(foreign_body) == 0 {
		return
	}
	if link_prefix != "" {
		fmt.sbprintfln(b, "@(link_prefix = %q)", link_prefix)
	}
	strings.write_string(b, "foreign lib {\n")
	strings.write_string(b, foreign_body)
	strings.write_string(b, "}\n")
}

// Serialize each planned output unit. Decl placement is already decided.
emit :: proc(ir: ^IR, plan: Output_Plan, opts: Emit_Options) -> Emit_Result {
	files := make([]Generated_File, len(plan.units))
	for unit, ui in plan.units {
		content, imports, needs_foreign := emit_unit_body(ir, unit.decls, opts)
		out: strings.Builder
		emit_write_prelude(&out, opts, imports, needs_foreign)
		strings.write_string(&out, content)
		files[ui] = Generated_File {
			filename = unit.filename,
			stem     = unit.stem,
			content  = strings.to_string(out),
		}
	}
	return Emit_Result{files = files}
}

// Build the declaration body for one unit (no package/prelude). Returns
// which imports the body needs and whether it declares foreign symbols
// (so the prelude can omit an unused `foreign import` under -vet).
emit_unit_body :: proc(ir: ^IR, decls: []Decl_Ref, opts: Emit_Options) -> (body: string, imports: Emit_Imports, needs_foreign: bool) {
	types_body: strings.Builder
	foreign_body: strings.Builder
	interleaved: strings.Builder
	imports = {}
	in_foreign := false
	needs_foreign = false

	if opts.procedures_at_end {
		for ref in decls {
			switch ref.kind {
			case .Invalid:
			case .Func:
				needs_foreign = true
				emit_func(&foreign_body, ir, ir.funcs[ref.index], opts.emit_comments, &imports)
			case .Record:
				emit_record(&types_body, ir, ir.records[ref.index], opts.emit_comments, &imports)
			case .Enum:
				emit_enum(&types_body, ir, ir.enums[ref.index], opts.emit_comments, &imports)
			case .Typedef:
				emit_typedef(&types_body, ir, ir.typedefs[ref.index], opts.emit_comments, &imports)
			case .Var:
				needs_foreign = true
				emit_var(&foreign_body, ir, ir.vars[ref.index], opts.emit_comments, &imports)
			case .Macro:
				emit_macro(&types_body, ir.macros[ref.index], opts.emit_comments)
			case .Bit_Set:
				emit_bit_set(&types_body, ir, ir.bit_sets[ref.index], opts.emit_comments, &imports)
			}
		}
		out: strings.Builder
		strings.write_string(&out, strings.to_string(types_body))
		emit_write_foreign_block(&out, strings.to_string(foreign_body), opts.link_prefix)
		return strings.to_string(out), imports, needs_foreign
	}

	for ref in decls {
		switch ref.kind {
		case .Invalid:
		case .Func:
			needs_foreign = true
			emit_open_foreign(&interleaved, &in_foreign, opts.link_prefix)
			emit_func(&interleaved, ir, ir.funcs[ref.index], opts.emit_comments, &imports)
		case .Var:
			needs_foreign = true
			emit_open_foreign(&interleaved, &in_foreign, opts.link_prefix)
			emit_var(&interleaved, ir, ir.vars[ref.index], opts.emit_comments, &imports)
		case .Record:
			emit_close_foreign(&interleaved, &in_foreign)
			emit_record(&interleaved, ir, ir.records[ref.index], opts.emit_comments, &imports)
		case .Enum:
			emit_close_foreign(&interleaved, &in_foreign)
			emit_enum(&interleaved, ir, ir.enums[ref.index], opts.emit_comments, &imports)
		case .Typedef:
			emit_close_foreign(&interleaved, &in_foreign)
			emit_typedef(&interleaved, ir, ir.typedefs[ref.index], opts.emit_comments, &imports)
		case .Macro:
			emit_close_foreign(&interleaved, &in_foreign)
			emit_macro(&interleaved, ir.macros[ref.index], opts.emit_comments)
		case .Bit_Set:
			emit_close_foreign(&interleaved, &in_foreign)
			emit_bit_set(&interleaved, ir, ir.bit_sets[ref.index], opts.emit_comments, &imports)
		}
	}
	emit_close_foreign(&interleaved, &in_foreign)
	return strings.to_string(interleaved), imports, needs_foreign
}
