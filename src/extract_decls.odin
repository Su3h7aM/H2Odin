package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"

import clang "vendored:libclang"

extract_macro :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	if clang.Cursor_isMacroBuiltin(cursor) != 0 {
		return
	}

	tokens: [^]clang.Token
	num_tokens: c.uint
	clang.tokenize(state.tu, clang.getCursorExtent(cursor), &tokens, &num_tokens)
	// disposeTokens must outlive the replacement loop below. A defer inside
	// `if num_tokens > 0` would free the array at the end of that if-block
	// (Odin defer is block-scoped), which is a use-after-free.
	defer if num_tokens > 0 {
		clang.disposeTokens(state.tu, tokens, num_tokens)
	}

	replacement_count := max(int(num_tokens) - 1, 0)
	replacement := make([]Macro_Token, replacement_count)
	for i in 0 ..< replacement_count {
		token := tokens[i + 1]
		replacement[i] = Macro_Token {
			spelling = clone_clang_string(clang.getTokenSpelling(state.tu, token)),
			kind     = macro_token_kind_from_clang(clang.getTokenKind(token)),
		}
	}

	ir_add_macro(
		state.ir,
		Macro_Decl {
			name = clone_clang_string(clang.getCursorSpelling(cursor)),
			tokens = replacement,
			is_function_like = clang.Cursor_isMacroFunctionLike(cursor) != 0,
			doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor)),
		},
	)
}

macro_token_kind_from_clang :: proc(kind: clang.Token_Kind) -> Macro_Token_Kind {
	#partial switch kind {
	case .Punctuation:
		return .Punctuation
	case .Keyword:
		return .Keyword
	case .Identifier:
		return .Identifier
	case .Literal:
		return .Literal
	case .Comment:
		return .Comment
	}
	return .Punctuation
}

extract_var :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	name := clone_clang_string(clang.getCursorSpelling(cursor))

	// static file-scope variables have no linkable symbol to bind.
	if clang.Cursor_getStorageClass(cursor) == .Static {
		fmt.eprintfln("h2odin: skipping %q: static variables have no external symbol", name)
		return
	}

	type, type_ok := capture_type(state, clang.getCursorType(cursor))
	if !type_ok {
		fmt.eprintfln("h2odin: skipping %q: unsupported type", name)
		return
	}
	// C permits extern arrays with unknown bounds. Odin has no incomplete
	// array type, so preserve the array object shape as [0]T: callers can
	// take its address, but no bound is invented.
	if array, is_array := ir_type(state.ir, type).variant.(Type_Array); is_array && array.is_incomplete {
		ir_diag(state.ir, .Incomplete_Extern_Array, "extern array %q has unknown size; emitted as [0]T", name)
	}

	ir_add_var(state.ir, Var_Decl{name = name, type = type, doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))})
}

// Get or create the IR declaration for a typedef cursor. The underlying type
// is captured immediately; the decl is mapped first so a recursive mention —
// typedef struct N { TD *p; } TD; — resolves to this decl instead of
// recursing forever.
typedef_decl_for_cursor :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Decl_Handle {
	usr := clone_clang_string(clang.getCursorUSR(cursor))
	if ref, found := state.decl_map[usr]; usr != "" && found {
		return Decl_Handle(ref.index)
	}

	decl := Typedef_Decl {
		name = clone_clang_string(clang.getCursorSpelling(cursor)),
		doc  = clone_clang_string(clang.Cursor_getRawCommentText(cursor)),
	}
	handle := ir_add_typedef(state.ir, decl)
	if usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Typedef,
			index = u32(handle),
		}
	}

	aliased, aliased_ok := capture_type(state, clang.getTypedefDeclUnderlyingType(cursor))
	if !aliased_ok {
		state.ir.typedefs[int(handle)].is_unresolvable = true
		fmt.eprintfln("h2odin: typedef %q aliases an unsupported type; skipped along with its uses", decl.name)
		return handle
	}
	state.ir.typedefs[int(handle)].aliased = aliased

	// When the typedef names an anonymous tag — typedef struct { … } Name —
	// remember that on the tag: the tag's only Odin spelling will be the
	// body emitted at this typedef.
	#partial switch target in ir_type(state.ir, aliased).variant {
	case Type_Record_Ref:
		if state.ir.records[int(target.decl)].name == "" {
			state.ir.records[int(target.decl)].is_typedef_named = true
		}
	case Type_Enum_Ref:
		if state.ir.enums[int(target.decl)].name == "" {
			state.ir.enums[int(target.decl)].is_typedef_named = true
		}
	}
	return handle
}

// Get or create the IR declaration for an enum cursor; fill its members when
// this cursor is the definition. Mirrors record_decl_for_cursor.
enum_decl_for_cursor :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Decl_Handle {
	usr := clone_clang_string(clang.getCursorUSR(cursor))
	if ref, found := state.decl_map[usr]; usr != "" && found {
		handle := Decl_Handle(ref.index)
		if state.ir.enums[int(handle)].doc == "" {
			state.ir.enums[int(handle)].doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))
		}
		if clang.isCursorDefinition(cursor) != 0 && state.ir.enums[int(handle)].members == nil {
			fill_enum(state, handle, cursor)
		}
		return handle
	}

	decl: Enum_Decl
	if clang.Cursor_isAnonymous(cursor) == 0 {
		decl.name = clone_clang_string(clang.getCursorSpelling(cursor))
	}
	decl.doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))
	// The backing integer type is known for any enum cursor — clang answers
	// with the target's ABI choice — so capture it even for a declaration
	// that never gets a definition in this header.
	decl.backing, _ = capture_type(state, clang.getEnumDeclIntegerType(cursor))
	handle := ir_add_enum(state.ir, decl)
	if usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Enum,
			index = u32(handle),
		}
	}
	if clang.isCursorDefinition(cursor) != 0 {
		fill_enum(state, handle, cursor)
	}
	return handle
}

Enum_Fill :: struct {
	ctx:     runtime.Context,
	state:   ^Extract_State,
	members: [dynamic]Enum_Member,
}

fill_enum :: proc(state: ^Extract_State, handle: Decl_Handle, cursor: clang.Cursor) {
	fill := Enum_Fill {
		ctx   = context,
		state = state,
	}
	clang.visitChildren(cursor, visit_enum_child, &fill)
	state.ir.enums[int(handle)].members = fill.members[:]
}

visit_enum_child :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	fill := cast(^Enum_Fill)client_data
	context = fill.ctx

	#partial switch clang.getCursorKind(cursor) {
	case .EnumConstantDecl:
		member := Enum_Member {
			name  = clone_clang_string(clang.getCursorSpelling(cursor)),
			value = i64(clang.getEnumConstantDeclValue(cursor)),
			doc   = clone_clang_string(clang.Cursor_getRawCommentText(cursor)),
		}
		append(&fill.members, member)
	}
	return .Continue
}

// Get or create the IR declaration for a struct/union cursor, and fill in
// its fields when this cursor is the definition. Placeholders created for a
// forward declaration (or a first mention inside another type) are completed
// later when the definition shows up.
record_decl_for_cursor :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Decl_Handle {
	usr := clone_clang_string(clang.getCursorUSR(cursor))
	if ref, found := state.decl_map[usr]; usr != "" && found {
		handle := Decl_Handle(ref.index)
		if state.ir.records[int(handle)].doc == "" {
			state.ir.records[int(handle)].doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))
		}
		if clang.isCursorDefinition(cursor) != 0 && !state.ir.records[int(handle)].is_complete {
			fill_record(state, handle, cursor)
		}
		return handle
	}

	record := Record_Decl {
		is_union = clang.getCursorKind(cursor) == .UnionDecl,
	}
	// Anonymous records keep "" as their name: recent libclang spells them
	// as "struct (unnamed at file:line)", which is a description, not a name.
	if clang.Cursor_isAnonymous(cursor) == 0 {
		record.name = clone_clang_string(clang.getCursorSpelling(cursor))
	}
	record.doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))
	handle := ir_add_record(state.ir, record)
	if usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Record,
			index = u32(handle),
		}
	}
	if clang.isCursorDefinition(cursor) != 0 {
		fill_record(state, handle, cursor)
	}
	return handle
}

Record_Fill :: struct {
	ctx:           runtime.Context,
	state:         ^Extract_State,
	fields:        [dynamic]Field,
	is_packed:     bool,
	has_bitfields: bool,
	failed_field:  string, // first field with an unsupported type; "" if none
}

fill_record :: proc(state: ^Extract_State, handle: Decl_Handle, cursor: clang.Cursor) {
	// Mark complete before walking the fields: a self-referential field
	// (struct Node { struct Node *next; }) resolves back to this record and
	// must not re-enter the fill.
	state.ir.records[int(handle)].is_complete = true

	fill := Record_Fill {
		ctx   = context,
		state = state,
	}
	clang.visitChildren(cursor, visit_record_child, &fill)

	// Written back by handle: the records pool may have grown while nested
	// types were captured, so no pointer into it was held across the visit.
	record := state.ir.records[int(handle)]
	record.is_complete = true
	record.is_packed = fill.is_packed
	record.fields = fill.fields[:]
	if fill.has_bitfields {
		record.has_unrepresentable_fields = true
		ir_diag(state.ir, .Opaque_Layout_Fallback, "%q uses bit-fields; emitted opaque — by-value use of it would be wrong", record_display_name(record))
	}
	if fill.failed_field != "" {
		record.has_unrepresentable_fields = true
		ir_diag(
			state.ir,
			.Opaque_Layout_Fallback,
			"%q field %q has an unsupported type; emitted opaque — by-value use of it would be wrong",
			record_display_name(record),
			fill.failed_field,
		)
	}
	state.ir.records[int(handle)] = record
}

record_display_name :: proc(record: Record_Decl) -> string {
	if record.name == "" {
		return "(anonymous record)"
	}
	return record.name
}

visit_record_child :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	fill := cast(^Record_Fill)client_data
	context = fill.ctx

	#partial switch clang.getCursorKind(cursor) {
	case .FieldDecl:
		name := clone_clang_string(clang.getCursorSpelling(cursor))
		if clang.Cursor_isBitField(cursor) != 0 {
			fill.has_bitfields = true
			return .Continue
		}
		type, type_ok := capture_type(fill.state, clang.getCursorType(cursor))
		if !type_ok {
			if fill.failed_field == "" {
				fill.failed_field = name
			}
			return .Continue
		}
		append(&fill.fields, Field{name = name, type = type, doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))})
	case .PackedAttr:
		fill.is_packed = true
	case .StructDecl, .UnionDecl, .EnumDecl:
		// A C11 anonymous member (union { ... }; with no declarator) never
		// gets a FieldDecl — the bare tag declaration is the member, so it
		// must become a field here or the record's layout silently shrinks.
		// Named tag declarations are captured lazily when a field's type
		// references them; nothing to do for those.
		if clang.Cursor_isAnonymousRecordDecl(cursor) != 0 {
			type, type_ok := capture_type(fill.state, clang.getCursorType(cursor))
			if !type_ok {
				if fill.failed_field == "" {
					fill.failed_field = "(anonymous member)"
				}
				return .Continue
			}
			append(&fill.fields, Field{name = "", type = type, doc = clone_clang_string(clang.Cursor_getRawCommentText(cursor))})
		}
	}
	return .Continue
}

extract_func :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	name := clone_clang_string(clang.getCursorSpelling(cursor))

	// static (usually static inline) functions have no linkable symbol.
	if clang.Cursor_getStorageClass(cursor) == .Static {
		fmt.eprintfln("h2odin: skipping %q: static functions have no external symbol", name)
		return
	}

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
		doc         = clone_clang_string(clang.Cursor_getRawCommentText(cursor)),
	}
	ir_add_func(state.ir, func)
}

// Copy a libclang-owned string into the generation arena and release the
// original. This is the boundary habit that keeps foreign lifetimes out of
// the IR.
