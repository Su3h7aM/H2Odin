package h2odin

import "base:runtime"
import "core:c"
import "core:fmt"
import "core:os"
import "core:strings"

import clang "vendored:libclang"

// Extraction is the only stage that talks to libclang. It walks the parsed
// header and copies what the header contains into the IR — faithfully,
// completely, and deciding nothing. Every libclang-owned string is copied
// into the generation arena at this boundary, so nothing downstream depends
// on libclang's lifetime; the library could be shut down the moment this
// stage returns.

Extract_State :: struct {
	ctx:      runtime.Context,
	ir:       ^IR,
	tu:       clang.Translation_Unit,

	// USR → already-created declaration, so every mention of a tagged type
	// resolves to one IR decl. Anonymous declarations have no USR and are
	// never shared, so they skip the map.
	decl_map: map[string]Decl_Ref,
}

extract :: proc(header_path: string, ir: ^IR) -> bool {
	index := clang.createIndex(0, 1) // 1: let libclang print parse diagnostics to stderr
	defer clang.disposeIndex(index)

	path := strings.clone_to_cstring(header_path, context.temp_allocator)
	// -fparse-all-comments: attach any comment adjacent to a declaration as
	// its documentation, not only doc-style ones (/** */, ///) — headers like
	// sqlite3.h document everything in plain /* */ blocks.
	args := make([dynamic]cstring, context.temp_allocator)
	append(&args, "-fparse-all-comments")
	if resource_arg, found := clang_resource_dir_arg(); found {
		append(&args, resource_arg)
	}
	tu := clang.parseTranslationUnit(index, path, raw_data(args[:]), c.int(len(args)), nil, 0, {.DetailedPreprocessingRecord})
	if tu == nil {
		fmt.eprintfln("h2odin: failed to parse %q", header_path)
		return false
	}
	defer clang.disposeTranslationUnit(tu)

	state := Extract_State {
		ctx      = context,
		ir       = ir,
		tu       = tu,
		decl_map = make(map[string]Decl_Ref),
	}
	clang.visitChildren(clang.getTranslationUnitCursor(tu), visit_top_level, &state)
	return true
}

// The location of clang's builtin headers (stddef.h, stdbool.h, …). This
// binding does not expose it, but the clang driver knows it exactly. Without
// the right resource dir those headers are missing and clang error-recovers
// size_t to int — a silently wrong ABI, the worst failure mode there is.
// When the driver is unavailable the flag is simply omitted; the parse
// diagnostics then report whatever actually breaks.
clang_resource_dir_arg :: proc() -> (arg: cstring, ok: bool) {
	state, stdout, _, err := os.process_exec({command = {"clang", "-print-resource-dir"}}, context.temp_allocator)
	if err != nil || !state.exited || state.exit_code != 0 {
		return "", false
	}
	dir := strings.trim_space(string(stdout))
	if dir == "" {
		return "", false
	}
	return strings.clone_to_cstring(fmt.tprintf("-resource-dir=%s", dir), context.temp_allocator), true
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
	case .StructDecl, .UnionDecl:
		record_decl_for_cursor(state, cursor)
	case .EnumDecl:
		enum_decl_for_cursor(state, cursor)
	case .TypedefDecl:
		typedef_decl_for_cursor(state, cursor)
	case .VarDecl:
		extract_var(state, cursor)
	case .MacroDefinition:
		extract_macro(state, cursor)
	}
	return .Continue
}

extract_macro :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	if clang.Cursor_isMacroBuiltin(cursor) != 0 {
		return
	}

	tokens: [^]clang.Token
	num_tokens: c.uint
	clang.tokenize(state.tu, clang.getCursorExtent(cursor), &tokens, &num_tokens)
	if num_tokens > 0 {
		defer clang.disposeTokens(state.tu, tokens, num_tokens)
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
		fmt.eprintfln("h2odin: extern array %q has unknown size; emitted as [0]T", name)
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
		fmt.eprintfln("h2odin: %q uses bit-fields; emitted opaque — by-value use of it would be wrong", record_display_name(record))
	}
	if fill.failed_field != "" {
		record.has_unrepresentable_fields = true
		fmt.eprintfln(
			"h2odin: %q field %q has an unsupported type; emitted opaque — by-value use of it would be wrong",
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
clone_clang_string :: proc(s: clang.String) -> string {
	defer clang.disposeString(s)
	c_str := clang.getCString(s)
	if c_str == nil {
		return ""
	}
	return strings.clone_from_cstring(c_str)
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

	case .Record:
		decl := record_decl_for_cursor(state, clang.getTypeDeclaration(type))
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Record_Ref{decl = decl}}), true

	case .Enum:
		decl := enum_decl_for_cursor(state, clang.getTypeDeclaration(type))
		return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Enum_Ref{decl = decl}}), true

	case .Typedef:
		decl_cursor := clang.getTypeDeclaration(type)
		// Typedefs declared in included headers are not ours to re-declare.
		// The C standard ones keep their familiar name via core:c; anything
		// else resolves transparently to its underlying type — an alias adds
		// no ABI information, only a name we must not claim.
		if clang.Location_isFromMainFile(clang.getCursorLocation(decl_cursor)) == 0 {
			name := clone_clang_string(clang.getCursorSpelling(decl_cursor))
			if is_std_c_type(name) {
				return ir_add_type(ir, Type_Info{is_const = is_const, variant = Type_Std{name = name, size = measured_size_of(type)}}), true
			}
			return capture_type(state, clang.getTypedefDeclUnderlyingType(decl_cursor))
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
	size := clang.Type_getSizeOf(type)
	if size < 0 {
		return -1
	}
	return int(size)
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
