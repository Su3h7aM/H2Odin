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
	// When non-empty, package/import/foreign-import go into a separate
	// string (imports_text); the main body still has `package` so it is a
	// valid file, but omits the foreign import / core:c when split.
	imports_file:      string, // path hint only; empty means inline prelude
}

Emit_Result :: struct {
	main:    string, // primary generated Odin
	imports: string, // non-empty when imports_file is set
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

emit_write_prelude :: proc(b: ^strings.Builder, opts: Emit_Options, uses_core_c: bool) {
	fmt.sbprintfln(b, "package %s", opts.package_name)
	strings.write_string(b, "\n")
	if uses_core_c {
		strings.write_string(b, "import \"core:c\"\n")
		strings.write_string(b, "\n")
	}
	fmt.sbprintfln(b, "foreign import lib \"system:%s\"", opts.foreign_lib)
	strings.write_string(b, "\n")
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

emit :: proc(ir: ^IR, opts: Emit_Options) -> Emit_Result {
	// Declarations are emitted in ordering-list order so the output reads
	// like the original header. With procedures_at_end, types and macros
	// go to a types section and funcs/vars to a foreign block; otherwise
	// source order is preserved with foreign blocks opened as needed.
	types_body: strings.Builder
	foreign_body: strings.Builder
	interleaved: strings.Builder
	uses_core_c := false
	in_foreign := false

	if opts.procedures_at_end {
		for ref in ir.order {
			switch ref.kind {
			case .Invalid:
			case .Func:
				emit_func(&foreign_body, ir, ir.funcs[ref.index], opts.emit_comments, &uses_core_c)
			case .Record:
				emit_record(&types_body, ir, ir.records[ref.index], opts.emit_comments, &uses_core_c)
			case .Enum:
				emit_enum(&types_body, ir, ir.enums[ref.index], opts.emit_comments, &uses_core_c)
			case .Typedef:
				emit_typedef(&types_body, ir, ir.typedefs[ref.index], opts.emit_comments, &uses_core_c)
			case .Var:
				emit_var(&foreign_body, ir, ir.vars[ref.index], opts.emit_comments, &uses_core_c)
			case .Macro:
				emit_macro(&types_body, ir.macros[ref.index], opts.emit_comments)
			case .Bit_Set:
				emit_bit_set(&types_body, ir, ir.bit_sets[ref.index], opts.emit_comments, &uses_core_c)
			}
		}
	} else {
		for ref in ir.order {
			switch ref.kind {
			case .Invalid:
			case .Func:
				emit_open_foreign(&interleaved, &in_foreign, opts.link_prefix)
				emit_func(&interleaved, ir, ir.funcs[ref.index], opts.emit_comments, &uses_core_c)
			case .Var:
				emit_open_foreign(&interleaved, &in_foreign, opts.link_prefix)
				emit_var(&interleaved, ir, ir.vars[ref.index], opts.emit_comments, &uses_core_c)
			case .Record:
				emit_close_foreign(&interleaved, &in_foreign)
				emit_record(&interleaved, ir, ir.records[ref.index], opts.emit_comments, &uses_core_c)
			case .Enum:
				emit_close_foreign(&interleaved, &in_foreign)
				emit_enum(&interleaved, ir, ir.enums[ref.index], opts.emit_comments, &uses_core_c)
			case .Typedef:
				emit_close_foreign(&interleaved, &in_foreign)
				emit_typedef(&interleaved, ir, ir.typedefs[ref.index], opts.emit_comments, &uses_core_c)
			case .Macro:
				emit_close_foreign(&interleaved, &in_foreign)
				emit_macro(&interleaved, ir.macros[ref.index], opts.emit_comments)
			case .Bit_Set:
				emit_close_foreign(&interleaved, &in_foreign)
				emit_bit_set(&interleaved, ir, ir.bit_sets[ref.index], opts.emit_comments, &uses_core_c)
			}
		}
		emit_close_foreign(&interleaved, &in_foreign)
	}

	result: Emit_Result
	if opts.imports_file != "" {
		imports_b: strings.Builder
		emit_write_prelude(&imports_b, opts, uses_core_c)
		result.imports = strings.to_string(imports_b)

		// Main file still needs package (shared with imports_file). Foreign
		// import lives only in the imports file.
		main_b: strings.Builder
		fmt.sbprintfln(&main_b, "package %s", opts.package_name)
		strings.write_string(&main_b, "\n")
		if opts.procedures_at_end {
			strings.write_string(&main_b, strings.to_string(types_body))
			emit_write_foreign_block(&main_b, strings.to_string(foreign_body), opts.link_prefix)
		} else {
			strings.write_string(&main_b, strings.to_string(interleaved))
		}
		result.main = strings.to_string(main_b)
		return result
	}

	out: strings.Builder
	emit_write_prelude(&out, opts, uses_core_c)
	if opts.procedures_at_end {
		strings.write_string(&out, strings.to_string(types_body))
		emit_write_foreign_block(&out, strings.to_string(foreign_body), opts.link_prefix)
	} else {
		strings.write_string(&out, strings.to_string(interleaved))
	}
	result.main = strings.to_string(out)
	return result
}
