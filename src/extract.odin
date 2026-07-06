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
		extract_func(state.ir, cursor)
	}
	return .Continue
}

extract_func :: proc(ir: ^IR, cursor: clang.Cursor) {
	name := clone_clang_string(clang.getCursorSpelling(cursor))

	return_type, return_ok := intern_clang_type(ir, clang.getCursorResultType(cursor))
	if !return_ok {
		fmt.eprintfln("h2odin: skipping %q: unsupported return type", name)
		return
	}

	num_params := int(clang.Cursor_getNumArguments(cursor))
	params := make([]Param, num_params)
	for i in 0 ..< num_params {
		arg := clang.Cursor_getArgument(cursor, c.uint(i))
		param_type, param_ok := intern_clang_type(ir, clang.getCursorType(arg))
		if !param_ok {
			fmt.eprintfln("h2odin: skipping %q: unsupported type of parameter %d", name, i)
			return
		}
		params[i] = Param {
			name = clone_clang_string(clang.getCursorSpelling(arg)),
			type = param_type,
		}
	}

	ir_add_func(ir, Func_Decl{name = name, return_type = return_type, params = params})
}

// Copy a libclang-owned string into the generation arena and release the
// original. This is the boundary habit that keeps foreign lifetimes out of
// the IR.
clone_clang_string :: proc(s: clang.String) -> string {
	defer clang.disposeString(s)
	return strings.clone_from_cstring(clang.getCString(s))
}

// Map a clang type onto a type already in the IR pool. Capturing the type is
// faithful identity, not a judgment call — anything the IR cannot yet
// represent is reported as unsupported rather than approximated.
intern_clang_type :: proc(ir: ^IR, type: clang.Type) -> (handle: Type_Handle, ok: bool) {
	kind := builtin_kind_from_clang(type.kind)
	if kind == .Invalid {
		return 0, false
	}
	return ir_builtin_type(ir, kind), true
}

builtin_kind_from_clang :: proc(kind: clang.Type_Kind) -> Builtin_Kind {
	#partial switch kind {
	case .Void:
		return .Void
	case .Bool:
		return .Bool
	case .Char_S, .Char_U:
		return .Char
	case .SChar:
		return .S_Char
	case .UChar:
		return .U_Char
	case .Short:
		return .Short
	case .UShort:
		return .U_Short
	case .Int:
		return .Int
	case .UInt:
		return .U_Int
	case .Long:
		return .Long
	case .ULong:
		return .U_Long
	case .LongLong:
		return .Long_Long
	case .ULongLong:
		return .U_Long_Long
	case .Float:
		return .Float
	case .Double:
		return .Double
	}
	return .Invalid
}
