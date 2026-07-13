package h2odin

import "core:strings"

LENGTH_PARAMETER_NAMES :: [?]string{"n", "len", "length", "count", "size", "num"}
LENGTH_PARAMETER_SUFFIXES :: [?]string{"_len", "_length", "_count", "_size", "_num"}

// Analysis adds facts to the IR — things provably true about the C API
// regardless of any configuration. It reads and annotates; it decides
// nothing, and it consults no policy, so it is deterministic without caveats.
analyze :: proc(ir: ^IR) {
	for &function in ir.funcs {
		analyze_pointer_length_relationships(ir, &function)
	}
}

analyze_pointer_length_relationships :: proc(ir: ^IR, function: ^Func_Decl) {
	for &parameter in function.params {
		parameter.facts = {}
	}

	for &parameter, pointer_index in function.params {
		if !type_is_data_pointer(ir, parameter.type) {
			continue
		}

		length_parameter_index := -1
		if pointer_index > 0 && parameter_is_length_like(ir, function.params[pointer_index - 1]) {
			length_parameter_index = pointer_index - 1
		} else if pointer_index + 1 < len(function.params) && parameter_is_length_like(ir, function.params[pointer_index + 1]) {
			length_parameter_index = pointer_index + 1
		}
		if length_parameter_index >= 0 {
			parameter.facts.has_length_like_neighbour = true
			parameter.facts.length_param_index = length_parameter_index
		}
	}
}

parameter_is_length_like :: proc(ir: ^IR, parameter: Param) -> bool {
	return name_is_length_like(parameter.name) && type_is_integer_like(ir, parameter.type)
}

name_is_length_like :: proc(name: string) -> bool {
	for candidate in LENGTH_PARAMETER_NAMES {
		if strings.equal_fold(name, candidate) {
			return true
		}
	}
	for suffix in LENGTH_PARAMETER_SUFFIXES {
		if len(name) >= len(suffix) && strings.equal_fold(name[len(name) - len(suffix):], suffix) {
			return true
		}
	}
	return false
}

type_is_data_pointer :: proc(ir: ^IR, type_handle: Type_Handle) -> bool {
	pointer, is_pointer := ir_type(ir, type_handle).variant.(Type_Pointer)
	if !is_pointer {
		return false
	}
	_, is_proc := ir_type(ir, pointer.pointee).variant.(Type_Proc)
	return !is_proc
}

type_is_integer_like :: proc(ir: ^IR, type_handle: Type_Handle) -> bool {
	#partial switch variant in ir_type(ir, type_handle).variant {
	case Type_Builtin:
		#partial switch variant.kind {
		case .Char_Signed, .Char_Unsigned, .S_Char, .U_Char, .Short, .U_Short, .Int, .U_Int, .Long, .U_Long, .Long_Long, .U_Long_Long:
			return true
		}
	case Type_Std:
		switch variant.name {
		case "size_t",
		     "ssize_t",
		     "ptrdiff_t",
		     "int8_t",
		     "int16_t",
		     "int32_t",
		     "int64_t",
		     "uint8_t",
		     "uint16_t",
		     "uint32_t",
		     "uint64_t",
		     "intptr_t",
		     "uintptr_t",
		     "intmax_t",
		     "uintmax_t":
			return true
		}
	case Type_Idiomatic_Leaf:
		// After idiomatic leaf sub, ints become i32/u32/… spellings.
		spelling := variant.spelling
		if strings.has_prefix(spelling, "i") || strings.has_prefix(spelling, "u") {
			return true
		}
		if strings.contains(spelling, "int") || strings.contains(spelling, "size") {
			return true
		}
	case Type_Typedef_Ref:
		typedef := ir.typedefs[variant.decl]
		if !typedef.is_unresolvable {
			return type_is_integer_like(ir, typedef.aliased)
		}
	}
	return false
}
