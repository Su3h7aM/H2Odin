package h2odin

import "core:fmt"
import "core:strings"

// Emit a minimal idiomatic wrapper body. Reshape only — no
// runtime validation that generation could have done.
emit_wrapper :: proc(b: ^strings.Builder, ir: ^IR, w: Wrapper_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	fn := ir.funcs[w.target]
	write_doc(b, w.doc, 0, emit_comments)
	if w.require_results {
		strings.write_string(b, "@(require_results)\n")
	}
	fmt.sbprintf(b, "%s :: proc(", w.name)

	// Public params: all foreign params except out_params and slice count/pointer pairs.
	// Slice pairs collapse to one []T parameter at the pointer's position.
	out_set := make(map[int]bool, context.temp_allocator)
	for op in w.out_params {
		out_set[op.param_index] = true
	}
	slice_ptr := make(map[int]int, context.temp_allocator) // pointer_index → slice index
	slice_count := make(map[int]bool, context.temp_allocator)
	for sl, i in w.slices {
		slice_ptr[sl.pointer_index] = i
		slice_count[sl.count_index] = true
	}

	first_param := true
	for i in 0 ..< len(fn.params) {
		if out_set[i] || slice_count[i] {
			continue
		}
		if si, is_slice_ptr := slice_ptr[i]; is_slice_ptr {
			if !first_param {
				strings.write_string(b, ", ")
			}
			first_param = false
			sl := w.slices[si]
			fmt.sbprintf(b, "%s: []", sl.public_name)
			write_wrapper_slice_elem_type(b, ir, fn.params[i], emit_comments, imports)
			continue
		}
		// Ordinary public param — same spelling as foreign surface.
		if !first_param {
			strings.write_string(b, ", ")
		}
		first_param = false
		write_one_param(b, ir, fn.params[i], emit_comments, imports)
	}
	if fn.is_variadic {
		// Should not plan wrappers for variadic; defensive.
		if !first_param {
			strings.write_string(b, ", ")
		}
		strings.write_string(b, "#c_vararg _: ..any")
	}
	strings.write_string(b, ")")

	// Results: out_params (peeled) then optional C return as `res`.
	has_c_ret := w.keep_c_return && !type_is_void(ir, fn.return_type)
	n_results := len(w.out_params) + (1 if has_c_ret else 0)
	if n_results == 1 && len(w.out_params) == 1 && !has_c_ret {
		strings.write_string(b, " -> ")
		write_peeled_pointer_type(b, ir, fn.params[w.out_params[0].param_index], emit_comments, imports)
	} else if n_results == 1 && has_c_ret && len(w.out_params) == 0 {
		strings.write_string(b, " -> ")
		if fn.return_type_spelling != "" {
			note_import_for_spelling(imports, fn.return_type_spelling)
			strings.write_string(b, fn.return_type_spelling)
		} else {
			write_type(b, ir, fn.return_type, 0, emit_comments, imports)
		}
	} else if n_results > 0 {
		strings.write_string(b, " -> (")
		for op, i in w.out_params {
			if i > 0 {
				strings.write_string(b, ", ")
			}
			fmt.sbprintf(b, "%s: ", op.result_name)
			write_peeled_pointer_type(b, ir, fn.params[op.param_index], emit_comments, imports)
		}
		if has_c_ret {
			if len(w.out_params) > 0 {
				strings.write_string(b, ", ")
			}
			strings.write_string(b, "res: ")
			if fn.return_type_spelling != "" {
				note_import_for_spelling(imports, fn.return_type_spelling)
				strings.write_string(b, fn.return_type_spelling)
			} else {
				write_type(b, ir, fn.return_type, 0, emit_comments, imports)
			}
		}
		strings.write_string(b, ")")
	}
	strings.write_string(b, " {\n")

	// Out-params are named results (zero-initialized); do not redeclare them.
	// Call faithful foreign.
	if has_c_ret {
		strings.write_string(b, "\tres = ")
	} else {
		strings.write_string(b, "\t")
	}
	fmt.sbprintf(b, "%s(", fn.name)
	first_arg := true
	for i in 0 ..< len(fn.params) {
		if !first_arg {
			strings.write_string(b, ", ")
		}
		first_arg = false
		if out_set[i] {
			// Find result name for this index.
			rname := ""
			for op in w.out_params {
				if op.param_index == i {
					rname = op.result_name
					break
				}
			}
			fmt.sbprintf(b, "&%s", rname)
			continue
		}
		if si, is_slice_ptr := slice_ptr[i]; is_slice_ptr {
			sl := w.slices[si]
			fmt.sbprintf(b, "raw_data(%s)", sl.public_name)
			continue
		}
		if slice_count[i] {
			// Count arg: find slice that owns this count index.
			for sl in w.slices {
				if sl.count_index == i {
					// Plain cast to the foreign count type (validated at plan time).
					strings.write_string(b, "(")
					write_param_type_only(b, ir, fn.params[i], emit_comments, imports)
					fmt.sbprintf(b, ")(len(%s))", sl.public_name)
					break
				}
			}
			continue
		}
		// Forward ordinary param by name.
		pname := fn.params[i].name if fn.params[i].name != "" else "_"
		strings.write_string(b, pname)
	}
	strings.write_string(b, ")\n")
	strings.write_string(b, "\treturn\n")
	strings.write_string(b, "}\n\n")
}

write_one_param :: proc(b: ^strings.Builder, ir: ^IR, param: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if param.by_ptr {
		strings.write_string(b, "#by_ptr ")
		if param.name != "" {
			fmt.sbprintf(b, "%s: ", param.name)
		} else {
			strings.write_string(b, "_: ")
		}
		if lowered, ok := ir_type(ir, param.type).variant.(Type_Lowered_Pointer); ok {
			write_type(b, ir, lowered.pointee, 0, emit_comments, imports)
		} else {
			write_type(b, ir, param.type, 0, emit_comments, imports)
		}
		return
	}
	if param.name != "" {
		fmt.sbprintf(b, "%s: ", param.name)
	} else {
		strings.write_string(b, "_: ")
	}
	write_param_type_only(b, ir, param, emit_comments, imports)
	if param.default != "" {
		fmt.sbprintf(b, " = %s", param.default)
	}
}

write_param_type_only :: proc(b: ^strings.Builder, ir: ^IR, param: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if param.type_spelling != "" {
		note_import_for_spelling(imports, param.type_spelling)
		strings.write_string(b, param.type_spelling)
		return
	}
	write_type(b, ir, param.type, 0, emit_comments, imports)
}

// Result type for an out-param: peel one single-pointer level.
write_peeled_pointer_type :: proc(b: ^strings.Builder, ir: ^IR, param: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if param.type_spelling != "" {
		// "^T" → "T", "^^T" → "^T", "[^]T" should not appear for out-params.
		s := param.type_spelling
		if strings.has_prefix(s, "^") {
			note_import_for_spelling(imports, s[1:])
			strings.write_string(b, s[1:])
			return
		}
		note_import_for_spelling(imports, s)
		strings.write_string(b, s)
		return
	}
	lowered, ok := ir_type(ir, param.type).variant.(Type_Lowered_Pointer)
	if !ok {
		write_type(b, ir, param.type, 0, emit_comments, imports)
		return
	}
	// Peel one level.
	write_type(b, ir, lowered.pointee, 0, emit_comments, imports)
}

write_wrapper_slice_elem_type :: proc(b: ^strings.Builder, ir: ^IR, param: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if param.type_spelling != "" {
		s := param.type_spelling
		if strings.has_prefix(s, "[^]") {
			note_import_for_spelling(imports, s[3:])
			strings.write_string(b, s[3:])
			return
		}
		if strings.has_prefix(s, "^") {
			note_import_for_spelling(imports, s[1:])
			strings.write_string(b, s[1:])
			return
		}
		note_import_for_spelling(imports, s)
		strings.write_string(b, s)
		return
	}
	lowered, ok := ir_type(ir, param.type).variant.(Type_Lowered_Pointer)
	if ok {
		write_type(b, ir, lowered.pointee, 0, emit_comments, imports)
		return
	}
	write_type(b, ir, param.type, 0, emit_comments, imports)
}
