package h2odin

import "core:strings"

// Analysis adds facts to the IR — things provably true about the C API
// regardless of any configuration. It reads and annotates; it decides
// nothing, and it consults no policy, so it is deterministic without caveats.
analyze :: proc(ir: ^IR) {
	for i in 0 ..< len(ir.funcs) {
		analyze_func_params(ir, &ir.funcs[i])
	}
}

analyze_func_params :: proc(ir: ^IR, func: ^Func_Decl) {
	for i in 0 ..< len(func.params) {
		param := &func.params[i]
		param.facts.is_length_like = name_is_length_like(param.name) && type_is_integer_like(ir, param.type)
	}

	for i in 0 ..< len(func.params) {
		param := &func.params[i]
		if !type_is_data_pointer(ir, param.type) {
			continue
		}
		if i > 0 && func.params[i - 1].facts.is_length_like {
			mark_length_neighbour(func, i, i - 1)
		} else if i + 1 < len(func.params) && func.params[i + 1].facts.is_length_like {
			mark_length_neighbour(func, i, i + 1)
		}
	}
}

mark_length_neighbour :: proc(func: ^Func_Decl, pointer_index, length_index: int) {
	func.params[pointer_index].facts.has_length_like_neighbour = true
	func.params[pointer_index].facts.length_param_index = i32(length_index)
	func.params[length_index].facts.length_for_pointer_index = i32(pointer_index)
}

name_is_length_like :: proc(name: string) -> bool {
	if name == "" {
		return false
	}
	lower, err := strings.to_lower(name, context.temp_allocator)
	if err != nil {
		return false
	}
	switch lower {
	case "n", "len", "length", "count", "size", "num":
		return true
	}
	if strings.has_suffix(lower, "_len") ||
	   strings.has_suffix(lower, "_length") ||
	   strings.has_suffix(lower, "_count") ||
	   strings.has_suffix(lower, "_size") ||
	   strings.has_suffix(lower, "_num") {
		return true
	}
	return false
}

type_is_data_pointer :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	pointer, is_pointer := ir_type(ir, handle).variant.(Type_Pointer)
	if !is_pointer {
		return false
	}
	_, is_proc := ir_type(ir, pointer.pointee).variant.(Type_Proc)
	return !is_proc
}

type_is_integer_like :: proc(ir: ^IR, handle: Type_Handle) -> bool {
	#partial switch variant in ir_type(ir, handle).variant {
	case Type_Builtin:
		#partial switch variant.kind {
		case .Char, .S_Char, .U_Char, .Short, .U_Short, .Int, .U_Int, .Long, .U_Long, .Long_Long, .U_Long_Long:
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
	case Type_Typedef_Ref:
		decl := ir.typedefs[variant.decl]
		if !decl.is_unresolvable {
			return type_is_integer_like(ir, decl.aliased)
		}
	}
	return false
}
