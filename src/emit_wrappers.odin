package h2odin

import "core:fmt"
import "core:strings"

Wrapper_Parameter_Lookup :: struct {
	result_name_by_parameter:   map[int]string,
	slice_by_pointer_parameter: map[int]int,
	slice_by_count_parameter:   map[int]int,
}

// Wrapper lookup maps are scratch indexes over arena-owned IR; they only live
// for the current emission run and avoid rediscovering relationships per use.
build_wrapper_parameter_lookup :: proc(wrapper: Wrapper_Decl) -> Wrapper_Parameter_Lookup {
	lookup := Wrapper_Parameter_Lookup {
		result_name_by_parameter   = make(map[int]string, context.temp_allocator),
		slice_by_pointer_parameter = make(map[int]int, context.temp_allocator),
		slice_by_count_parameter   = make(map[int]int, context.temp_allocator),
	}
	for out_parameter in wrapper.out_params {
		lookup.result_name_by_parameter[out_parameter.param_index] = out_parameter.result_name
	}
	for wrapper_slice, slice_index in wrapper.slices {
		lookup.slice_by_pointer_parameter[wrapper_slice.pointer_index] = slice_index
		lookup.slice_by_count_parameter[wrapper_slice.count_index] = slice_index
	}
	return lookup
}

// Emit a minimal idiomatic wrapper body. Reshape only — no runtime validation
// that generation could have done.
emit_wrapper :: proc(b: ^strings.Builder, ir: ^IR, wrapper: Wrapper_Decl, emit_comments: bool, imports: ^Emit_Imports) {
	function := ir.funcs[wrapper.target]
	parameter_lookup := build_wrapper_parameter_lookup(wrapper)
	keeps_c_return := wrapper.keep_c_return && function_has_result(ir, function)

	write_doc(b, wrapper.doc, 0, emit_comments)
	if wrapper.require_results {
		strings.write_string(b, "@(require_results)\n")
	}
	fmt.sbprintf(b, "%s :: proc(", wrapper.name)
	write_wrapper_parameters(b, ir, function, wrapper, parameter_lookup, emit_comments, imports)
	strings.write_string(b, ")")
	write_wrapper_results(b, ir, function, wrapper, keeps_c_return, emit_comments, imports)
	strings.write_string(b, " {\n")
	write_wrapper_body(b, ir, function, wrapper, parameter_lookup, keeps_c_return, emit_comments, imports)
	strings.write_string(b, "}\n\n")
}

write_wrapper_parameters :: proc(
	b: ^strings.Builder,
	ir: ^IR,
	function: Func_Decl,
	wrapper: Wrapper_Decl,
	lookup: Wrapper_Parameter_Lookup,
	emit_comments: bool,
	imports: ^Emit_Imports,
) {
	first_parameter := true
	for parameter, parameter_index in function.params {
		if parameter_index in lookup.result_name_by_parameter || parameter_index in lookup.slice_by_count_parameter {
			continue
		}
		if slice_index, is_slice_pointer := lookup.slice_by_pointer_parameter[parameter_index]; is_slice_pointer {
			if !first_parameter {
				strings.write_string(b, ", ")
			}
			first_parameter = false
			wrapper_slice := wrapper.slices[slice_index]
			fmt.sbprintf(b, "%s: []", wrapper_slice.public_name)
			write_wrapper_slice_element_type(b, ir, parameter, emit_comments, imports)
			continue
		}

		if !first_parameter {
			strings.write_string(b, ", ")
		}
		first_parameter = false
		write_parameter(b, ir, parameter, 0, emit_comments, imports)
	}
	if function.is_variadic {
		// Transformation rejects variadic wrappers; keep emission fail-closed.
		if !first_parameter {
			strings.write_string(b, ", ")
		}
		strings.write_string(b, "#c_vararg _: ..any")
	}
}

write_wrapper_results :: proc(
	b: ^strings.Builder,
	ir: ^IR,
	function: Func_Decl,
	wrapper: Wrapper_Decl,
	keeps_c_return: bool,
	emit_comments: bool,
	imports: ^Emit_Imports,
) {
	result_count := len(wrapper.out_params) + (1 if keeps_c_return else 0)
	if result_count == 0 {
		return
	}

	strings.write_string(b, " -> ")
	if result_count == 1 {
		if len(wrapper.out_params) == 1 {
			out_parameter := wrapper.out_params[0]
			write_peeled_pointer_type(b, ir, function.params[out_parameter.param_index], emit_comments, imports)
		} else {
			write_function_result_type(b, ir, function, 0, emit_comments, imports)
		}
		return
	}

	strings.write_string(b, "(")
	for out_parameter, result_index in wrapper.out_params {
		if result_index > 0 {
			strings.write_string(b, ", ")
		}
		fmt.sbprintf(b, "%s: ", out_parameter.result_name)
		write_peeled_pointer_type(b, ir, function.params[out_parameter.param_index], emit_comments, imports)
	}
	if keeps_c_return {
		if len(wrapper.out_params) > 0 {
			strings.write_string(b, ", ")
		}
		strings.write_string(b, "res: ")
		write_function_result_type(b, ir, function, 0, emit_comments, imports)
	}
	strings.write_string(b, ")")
}

write_wrapper_body :: proc(
	b: ^strings.Builder,
	ir: ^IR,
	function: Func_Decl,
	wrapper: Wrapper_Decl,
	lookup: Wrapper_Parameter_Lookup,
	keeps_c_return: bool,
	emit_comments: bool,
	imports: ^Emit_Imports,
) {
	if keeps_c_return {
		strings.write_string(b, "\tres = ")
	} else {
		strings.write_string(b, "\t")
	}
	fmt.sbprintf(b, "%s(", function.name)
	for parameter, parameter_index in function.params {
		if parameter_index > 0 {
			strings.write_string(b, ", ")
		}
		if result_name, is_out_parameter := lookup.result_name_by_parameter[parameter_index]; is_out_parameter {
			fmt.sbprintf(b, "&%s", result_name)
			continue
		}
		if slice_index, is_slice_pointer := lookup.slice_by_pointer_parameter[parameter_index]; is_slice_pointer {
			wrapper_slice := wrapper.slices[slice_index]
			fmt.sbprintf(b, "raw_data(%s)", wrapper_slice.public_name)
			continue
		}
		if slice_index, is_slice_count := lookup.slice_by_count_parameter[parameter_index]; is_slice_count {
			wrapper_slice := wrapper.slices[slice_index]
			// The foreign count type was validated while planning the wrapper.
			strings.write_string(b, "(")
			write_parameter_type(b, ir, parameter, 0, emit_comments, imports)
			fmt.sbprintf(b, ")(len(%s))", wrapper_slice.public_name)
			continue
		}

		parameter_name := parameter.name if parameter.name != "" else "_"
		strings.write_string(b, parameter_name)
	}
	strings.write_string(b, ")\n")
	strings.write_string(b, "\treturn\n")
}

// Result type for an out-param: peel one single-pointer level.
write_peeled_pointer_type :: proc(b: ^strings.Builder, ir: ^IR, parameter: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if parameter.type_spelling != "" {
		// "^T" → "T", "^^T" → "^T", "[^]T" should not appear for out-params.
		spelling := parameter.type_spelling
		if strings.has_prefix(spelling, "^") {
			note_imports_for_odin_expression(imports, spelling[1:])
			strings.write_string(b, spelling[1:])
			return
		}
		note_imports_for_odin_expression(imports, spelling)
		strings.write_string(b, spelling)
		return
	}
	lowered_pointer, is_lowered_pointer := ir_type(ir, parameter.type).variant.(Type_Lowered_Pointer)
	if !is_lowered_pointer {
		write_type(b, ir, parameter.type, 0, emit_comments, imports)
		return
	}
	write_type(b, ir, lowered_pointer.pointee, 0, emit_comments, imports)
}

write_wrapper_slice_element_type :: proc(b: ^strings.Builder, ir: ^IR, parameter: Param, emit_comments: bool, imports: ^Emit_Imports) {
	if parameter.type_spelling != "" {
		spelling := parameter.type_spelling
		if strings.has_prefix(spelling, "[^]") {
			note_imports_for_odin_expression(imports, spelling[3:])
			strings.write_string(b, spelling[3:])
			return
		}
		if strings.has_prefix(spelling, "^") {
			note_imports_for_odin_expression(imports, spelling[1:])
			strings.write_string(b, spelling[1:])
			return
		}
		note_imports_for_odin_expression(imports, spelling)
		strings.write_string(b, spelling)
		return
	}
	lowered_pointer, is_lowered_pointer := ir_type(ir, parameter.type).variant.(Type_Lowered_Pointer)
	if is_lowered_pointer {
		write_type(b, ir, lowered_pointer.pointee, 0, emit_comments, imports)
		return
	}
	write_type(b, ir, parameter.type, 0, emit_comments, imports)
}
