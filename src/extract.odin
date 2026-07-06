package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:strings"

import clang "vendored:libclang"

// Extraction is the only stage that talks to libclang. It walks the parsed
// header and copies what the header contains into the IR — faithfully,
// completely, and deciding nothing. Every libclang-owned string is copied
// into the generation arena at this boundary, so nothing downstream depends
// on libclang's lifetime; the library could be shut down the moment this
// stage returns.

Extract_State :: struct {
	ctx: runtime.Context,
	ir:  ^IR,
}

extract :: proc(header_path: string, ir: ^IR) -> bool {
	index := clang.createIndex(0, 1) // 1: let libclang print parse diagnostics to stderr
	defer clang.disposeIndex(index)

	path := strings.clone_to_cstring(header_path, context.temp_allocator)
	tu := clang.parseTranslationUnit(index, path, nil, 0, nil, 0, {})
	if tu == nil {
		fmt.eprintfln("h2odin: failed to parse %q", header_path)
		return false
	}
	defer clang.disposeTranslationUnit(tu)

	state := Extract_State {
		ctx = context,
		ir  = ir,
	}
	clang.visitChildren(clang.getTranslationUnitCursor(tu), visit_top_level, &state)
	return true
}

visit_top_level :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	state := cast(^Extract_State)client_data
	context = state.ctx

	// Only bind what the given header itself declares; declarations pulled
	// in from included files (system headers and friends) are ignored.
	if clang.Location_isFromMainFile(clang.getCursorLocation(cursor)) == 0 {
		return .Continue
	}

	#partial switch clang.getCursorKind(cursor) {
	case .FunctionDecl:
		extract_func(state, cursor)
	}
	return .Continue
}

extract_func :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	name := clone_clang_string(clang.getCursorSpelling(cursor))

	return_type, return_ok := capture_type(state, clang.getCursorResultType(cursor))
	if !return_ok {
		fmt.eprintfln("h2odin: skipping %q: unsupported return type", name)
		return
	}

	num_params := int(clang.Cursor_getNumArguments(cursor))
	params := make([]Param, num_params)
	for i in 0 ..< num_params {
		arg := clang.Cursor_getArgument(cursor, c.uint(i))
		param_type, param_ok := capture_param_type(state, clang.getCursorType(arg))
		if !param_ok {
			fmt.eprintfln("h2odin: skipping %q: unsupported type of parameter %d", name, i)
			return
		}
		params[i] = Param {
			name = clone_clang_string(clang.getCursorSpelling(arg)),
			type = param_type,
		}
	}

	func := Func_Decl {
		name        = name,
		return_type = return_type,
		params      = params,
		is_variadic = clang.Cursor_isVariadic(cursor) != 0,
	}
	ir_add_func(state.ir, func)
}

// Copy a libclang-owned string into the generation arena and release the
// original. This is the boundary habit that keeps foreign lifetimes out of
// the IR.
clone_clang_string :: proc(s: clang.String) -> string {
	defer clang.disposeString(s)
	return strings.clone_from_cstring(clang.getCString(s))
}

// A C parameter of array or function type is really a pointer — decay it
// explicitly at capture so the IR never lies about the ABI, whatever spelling
// the header used.
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
	is_const := clang.isConstQualifiedType(type) != 0

	#partial switch type.kind {
	case .Elaborated:
		// "struct Foo"-style sugar: capture what it names, keeping any
		// qualifier that sits on the sugar node itself.
		handle = capture_type(state, clang.Type_getNamedType(type)) or_return
		if is_const && !ir_type(ir, handle).is_const {
			info := ir_type(ir, handle)
			info.is_const = true
			handle = ir_add_type(ir, info)
		}
		return handle, true

	case .Pointer:
		pointee := capture_type(state, clang.getPointeeType(type)) or_return
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Pointer{pointee = pointee}}), true

	case .ConstantArray:
		element := capture_type(state, clang.getArrayElementType(type)) or_return
		array := Type_Array {
			element = element,
			count   = i64(clang.getArraySize(type)),
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = array}), true

	case .IncompleteArray:
		element := capture_type(state, clang.getArrayElementType(type)) or_return
		array := Type_Array {
			element       = element,
			is_incomplete = true,
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = array}), true

	case .FunctionProto, .FunctionNoProto:
		return_type := capture_type(state, clang.getResultType(type)) or_return
		num_params := max(int(clang.getNumArgTypes(type)), 0)
		params := make([]Param, num_params)
		for i in 0 ..< num_params {
			// Parameter names do not exist at the type level; only types.
			params[i].type = capture_param_type(state, clang.getArgType(type, c.uint(i))) or_return
		}
		proc_type := Type_Proc {
			return_type = return_type,
			params      = params,
			is_variadic = clang.isFunctionTypeVariadic(type) != 0,
		}
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = proc_type}), true
	}

	// Builtins; anything else is not yet representable.
	kind := builtin_kind_from_clang(type.kind) or_return
	handle = ir_builtin_type(ir, kind)
	if is_const {
		// Pre-seeded builtin entries are unqualified; a const-qualified use
		// gets its own pool entry so the qualifier is not lost.
		handle = ir_add_type(ir, Type_Info{is_const = true, variant = Type_Builtin{kind = kind}})
	}
	return handle, true
}

builtin_kind_from_clang :: proc(clang_kind: clang.Type_Kind) -> (kind: Builtin_Kind, ok: bool) {
	#partial switch clang_kind {
	case .Void:
		return .Void, true
	case .Bool:
		return .Bool, true
	case .Char_S, .Char_U:
		return .Char, true
	case .SChar:
		return .S_Char, true
	case .UChar:
		return .U_Char, true
	case .Short:
		return .Short, true
	case .UShort:
		return .U_Short, true
	case .Int:
		return .Int, true
	case .UInt:
		return .U_Int, true
	case .Long:
		return .Long, true
	case .ULong:
		return .U_Long, true
	case .LongLong:
		return .Long_Long, true
	case .ULongLong:
		return .U_Long_Long, true
	case .Float:
		return .Float, true
	case .Double:
		return .Double, true
	}
	return {}, false
}
