package h2odin

import "core:c"

import clang "vendored:libclang"

capture_param_type :: proc(state: ^Extract_State, type: clang.Type) -> (handle: Type_Handle, ok: bool) {
	handle = capture_type(state, type) or_return
	if array, is_array := ir_type(state.ir, handle).variant.(Type_Array); is_array {
		handle = ir_add_type(state.ir, Type_Info{variant = Type_Pointer{pointee = array.element}})
	}
	return handle, true
}

// Map a clang type onto the IR type pool, recursively. Capturing a type is
// faithful identity, not a judgment call — anything the IR cannot yet
// represent is reported as unsupported rather than approximated.
capture_type :: proc(state: ^Extract_State, type: clang.Type) -> (handle: Type_Handle, ok: bool) {
	ir := state.ir
	is_const := clang.is_const_qualified_type(type) != 0

	#partial switch type.kind {
	case .Elaborated:
		// "struct Foo"-style sugar: capture what it names, keeping any
		// qualifier that sits on the sugar node itself.
		handle = capture_type(state, clang.type_get_named_type(type)) or_return
		if is_const && !ir_type(ir, handle).is_const {
			info := ir_type(ir, handle)
			info.is_const = true
			handle = ir_add_type(ir, info)
		}
		return handle, true

	case .Pointer:
		pointee := capture_type(state, clang.get_pointee_type(type)) or_return
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Pointer{pointee = pointee}}), true

	case .Constant_Array:
		element := capture_type(state, clang.get_array_element_type(type)) or_return
		array := Type_Array {
			element = element,
			count   = i64(clang.get_array_size(type)),
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = array}), true

	case .Incomplete_Array:
		element := capture_type(state, clang.get_array_element_type(type)) or_return
		array := Type_Array {
			element       = element,
			is_incomplete = true,
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = array}), true

	case .Function_Proto, .Function_No_Proto:
		return_type := capture_type(state, clang.get_result_type(type)) or_return
		num_params := max(int(clang.get_num_arg_types(type)), 0)
		params := make([]Param, num_params)
		for i in 0 ..< num_params {
			// Parameter names do not exist at the type level; only types.
			params[i].type = capture_param_type(state, clang.get_arg_type(type, c.uint(i))) or_return
		}
		proc_type := Type_Proc {
			return_type = return_type,
			params      = params,
			is_variadic = clang.is_function_type_variadic(type) != 0,
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = proc_type}), true

	case .Record:
		decl := record_decl_for_cursor(state, clang.get_type_declaration(type))
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Record_Ref{decl = decl}}), true

	case .Enum:
		decl := enum_decl_for_cursor(state, clang.get_type_declaration(type))
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Enum_Ref{decl = decl}}), true

	case .Typedef:
		decl_cursor := clang.get_type_declaration(type)
		// C standard names stay recognizable via core:c (Type_Std). Every
		// other typedef — ours or foreign — is captured with its name and its
		// underlying type; whether a foreign name survives as posix.off_t,
		// as a config spelling, or peels away to c.long is Transformation's
		// decision (spec 0010), not a fact Extraction may destroy here.
		if !location_is_ours(state, clang.get_cursor_location(decl_cursor)) {
			name := clone_clang_string(clang.get_cursor_spelling(decl_cursor))
			if is_std_c_type(name) {
				return ir_add_type(
						ir,
						Type_Info {
							is_const = is_const,
							variant = Type_Std{name = name, size = measured_size_of(type), unsigned = is_unsigned_integer_type(type)},
						},
					),
					true
			}
		}
		decl := typedef_decl_for_cursor(state, decl_cursor)
		if ir.typedefs[int(decl)].is_unresolvable {
			return 0, false
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Typedef_Ref{decl = decl}}), true
	}

	// Builtins; anything else is not yet representable.
	kind := builtin_kind_from_clang(type.kind) or_return
	size := measured_size_of(type)
	handle = ir_builtin_type(ir, kind)
	if shared, is_builtin := &ir.types[int(handle)].variant.(Type_Builtin); is_builtin && shared.size == -1 {
		// The pre-seeded entry starts with an unknown size; the first use on
		// this target measures it. Filling the shared entry keeps the
		// one-entry-per-kind interning model intact, since a builtin's size
		// cannot vary within a single extraction target.
		shared.size = size
	}
	if is_const {
		// Pre-seeded builtin entries are unqualified; a const-qualified use
		// gets its own pool entry so the qualifier is not lost.
		handle = ir_add_type(ir, Type_Info{is_const = true, variant = Type_Builtin{kind = kind, size = size}})
	}
	return handle, true
}

// The size of a Clang type in bytes on the extraction target. Extraction is
// the only stage allowed to ask libclang, so the answer is stored in the IR
// for later stages to read. clang_Type_getSizeOf returns a negative error
// code for incomplete or invalid types; that becomes -1, and downstream code
// must treat -1 as "unknown, cannot prove a substitution".
measured_size_of :: proc(type: clang.Type) -> int {
	size := clang.type_get_size_of(type)
	if size < 0 {
		return -1
	}
	return int(size)
}

// The alignment of a Clang type in bytes on the extraction target. It has
// the same negative-error contract as measured_size_of.
measured_alignment_of :: proc(type: clang.Type) -> int {
	alignment := clang.type_get_align_of(type)
	if alignment < 0 {
		return -1
	}
	return int(alignment)
}

// Signedness of an integer type's canonical (typedef-resolved) form, as
// libclang reports it on the extraction target — never guessed from the
// type's name. Used to derive a native spelling for std typedefs whose
// signedness is not otherwise decided by the type table (e.g. wchar_t,
// which is unsigned on Windows but a signed int on glibc).
is_unsigned_integer_type :: proc(type: clang.Type) -> bool {
	canonical := clang.get_canonical_type(type)
	#partial switch canonical.kind {
	case .Bool, .Char_U, .U_Char, .U_Short, .U_Int, .U_Long, .U_Long_Long, .U_Int128:
		return true
	}
	return false
}

builtin_kind_from_clang :: proc(clang_kind: clang.Type_Kind) -> (kind: Builtin_Kind, ok: bool) {
	#partial switch clang_kind {
	case .Void:
		return .Void, true
	case .Bool:
		return .Bool, true
	case .Char_S:
		return .Char_Signed, true
	case .Char_U:
		return .Char_Unsigned, true
	case .S_Char:
		return .S_Char, true
	case .U_Char:
		return .U_Char, true
	case .Short:
		return .Short, true
	case .U_Short:
		return .U_Short, true
	case .Int:
		return .Int, true
	case .U_Int:
		return .U_Int, true
	case .Long:
		return .Long, true
	case .U_Long:
		return .U_Long, true
	case .Long_Long:
		return .Long_Long, true
	case .U_Long_Long:
		return .U_Long_Long, true
	case .Float:
		return .Float, true
	case .Double:
		return .Double, true
	}
	return {}, false
}
