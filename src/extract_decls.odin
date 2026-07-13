package h2odin

import "base:runtime"
import "core:c"

import clang "vendored:libclang"

extract_macro :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	if clang.cursor_is_macro_builtin(cursor) != 0 {
		return
	}
	// Skip when this macro was already captured from a sibling input's TU
	// (or earlier in this walk). Macros have USRs in modern libclang.
	if already_captured(state, cursor) {
		return
	}

	tokens: [^]clang.Token
	num_tokens: c.uint
	clang.tokenize(state.tu, clang.get_cursor_extent(cursor), &tokens, &num_tokens)
	// disposeTokens must outlive the replacement loop below. A defer inside
	// `if num_tokens > 0` would free the array at the end of that if-block
	// (Odin defer is block-scoped), which is a use-after-free.
	defer if num_tokens > 0 {
		clang.dispose_tokens(state.tu, tokens, num_tokens)
	}

	replacement_count := max(int(num_tokens) - 1, 0)
	replacement := make([]Macro_Token, replacement_count)
	for i in 0 ..< replacement_count {
		token := tokens[i + 1]
		replacement[i] = Macro_Token {
			spelling = clone_clang_string(clang.get_token_spelling(state.tu, token)),
			kind     = macro_token_kind_from_clang(clang.get_token_kind(token)),
		}
	}

	deprecated, deprecated_message := cursor_deprecation(cursor)
	ir_add_macro(
		state.ir,
		Macro_Decl {
			name = clone_clang_string(clang.get_cursor_spelling(cursor)),
			tokens = replacement,
			is_function_like = clang.cursor_is_macro_function_like(cursor) != 0,
			deprecated = deprecated,
			deprecated_message = deprecated_message,
			doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
			home = cursor_home(state, cursor),
		},
	)
	remember_captured(state, cursor, .Macro, u32(len(state.ir.macros) - 1))
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
	if already_captured(state, cursor) {
		return
	}
	name := clone_clang_string(clang.get_cursor_spelling(cursor))

	// static file-scope variables have no linkable symbol to bind.
	if clang.cursor_get_storage_class(cursor) == .Static {
		user_errorf("h2odin: skipping %q: static variables have no external symbol", name)
		return
	}

	type, type_ok := capture_type(state, clang.get_cursor_type(cursor))
	if !type_ok {
		user_errorf("h2odin: skipping %q: unsupported type", name)
		return
	}
	// C permits extern arrays with unknown bounds. Odin has no incomplete
	// array type, so preserve the array object shape as [0]T: callers can
	// take its address, but no bound is invented.
	if array, is_array := ir_type(state.ir, type).variant.(Type_Array); is_array && array.is_incomplete {
		ir_diag(state.ir, .Incomplete_Extern_Array, "extern array %q has unknown size; emitted as [0]T", name)
	}

	deprecated, deprecated_message := cursor_deprecation(cursor)
	ir_add_var(
		state.ir,
		Var_Decl {
			name = name,
			type = type,
			deprecated = deprecated,
			deprecated_message = deprecated_message,
			doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
			home = cursor_home(state, cursor),
		},
	)
	remember_captured(state, cursor, .Var, u32(len(state.ir.vars) - 1))
}

// Get or create the IR declaration for a typedef cursor. The underlying type
// is captured immediately; the decl is mapped first so a recursive mention —
// typedef struct N { TD *p; } TD; — resolves to this decl instead of
// recursing forever.
typedef_decl_for_cursor :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Decl_Handle {
	usr := clone_clang_string(clang.get_cursor_usr(cursor))
	if ref, found := state.decl_map[usr]; usr != "" && found {
		return Decl_Handle(ref.index)
	}

	deprecated, deprecated_message := cursor_deprecation(cursor)
	is_foreign := cursor_is_foreign(cursor)
	decl := Typedef_Decl {
		name               = clone_clang_string(clang.get_cursor_spelling(cursor)),
		deprecated         = deprecated,
		deprecated_message = deprecated_message,
		doc                = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
		home               = cursor_home(state, cursor),
		is_foreign         = is_foreign,
	}
	// System-header typedefs enter the pool so the type graph resolves and the
	// C name survives for Transformation, but not the ordering list: their
	// declaration is not ours to emit. Transformation resolves every reference
	// to one — built-in map, config, or peel (see resolve_foreign_typedefs) —
	// so no dangling name can reach Emission.
	handle := ir_create_typedef(state.ir, decl) if is_foreign else ir_add_typedef(state.ir, decl)
	if usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Typedef,
			index = u32(handle),
		}
	}

	aliased, aliased_ok := capture_type(state, clang.get_typedef_decl_underlying_type(cursor))
	if !aliased_ok {
		state.ir.typedefs[int(handle)].is_unresolvable = true
		user_errorf("h2odin: typedef %q aliases an unsupported type; skipped along with its uses", decl.name)
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
	usr := clone_clang_string(clang.get_cursor_usr(cursor))
	if ref, found := state.decl_map[usr]; usr != "" && found {
		handle := Decl_Handle(ref.index)
		if state.ir.enums[int(handle)].doc == "" {
			state.ir.enums[int(handle)].doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor))
		}
		// Definition may carry the attribute when the forward decl did not.
		if !state.ir.enums[int(handle)].deprecated {
			state.ir.enums[int(handle)].deprecated, state.ir.enums[int(handle)].deprecated_message = cursor_deprecation(cursor)
		}
		if clang.is_cursor_definition(cursor) != 0 && state.ir.enums[int(handle)].members == nil {
			if !cursor_is_foreign(cursor) {
				if home := cursor_home(state, cursor); home != 0 {
					state.ir.enums[int(handle)].home = home
				}
				ir_promote_enum(state.ir, handle)
				fill_enum(state, handle, cursor)
			}
			// System-header enum definitions are not filled into emission.
		}
		return handle
	}

	home := cursor_home(state, cursor)
	is_foreign := cursor_is_foreign(cursor)
	decl: Enum_Decl
	if clang.cursor_is_anonymous(cursor) == 0 {
		decl.name = clone_clang_string(clang.get_cursor_spelling(cursor))
	}
	decl.deprecated, decl.deprecated_message = cursor_deprecation(cursor)
	decl.doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor))
	decl.home = home
	decl.is_foreign = is_foreign
	// The backing integer type is known for any enum cursor — clang answers
	// with the target's ABI choice — so capture it even for a declaration
	// that never gets a definition in this header.
	decl.backing, _ = capture_type(state, clang.get_enum_decl_integer_type(cursor))
	// System-header enums enter the pool for type-graph resolution but not the
	// ordering list — mirrors record_decl_for_cursor.
	handle := ir_create_enum(state.ir, decl)
	if !is_foreign {
		ir_promote_enum(state.ir, handle)
	}
	if usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Enum,
			index = u32(handle),
		}
	}
	if clang.is_cursor_definition(cursor) != 0 && !is_foreign {
		fill_enum(state, handle, cursor)
	}
	return handle
}

Enum_Fill :: struct {
	ctx:             runtime.Context,
	state:           ^Extract_State,
	members:         [dynamic]Enum_Member,
	// When true, capture via get_enum_constant_decl_unsigned_value so values
	// like 0xFFFFFFFF stay bit-correct for unsigned-backed enums (spec note
	// signed-only capture stored -1 for those).
	unsigned_values: bool,
}

fill_enum :: proc(state: ^Extract_State, handle: Decl_Handle, cursor: clang.Cursor) {
	fill := Enum_Fill {
		ctx             = context,
		state           = state,
		unsigned_values = enum_backing_is_unsigned(state.ir, state.ir.enums[int(handle)].backing),
	}
	clang.visit_children(cursor, visit_enum_child, clang.Client_Data(rawptr(&fill)))
	state.ir.enums[int(handle)].members = fill.members[:]
}

visit_enum_child :: proc "c" (cursor: clang.Cursor, _: clang.Cursor, client_data: clang.Client_Data) -> clang.Child_Visit_Result {
	fill := cast(^Enum_Fill)rawptr(client_data)
	context = fill.ctx

	#partial switch clang.get_cursor_kind(cursor) {
	case .Enum_Constant_Decl:
		value: i64
		if fill.unsigned_values {
			// Store the unsigned magnitude as i64 bit pattern; emission
			// reinterprets via u64 when the backing is unsigned.
			value = i64(clang.get_enum_constant_decl_unsigned_value(cursor))
		} else {
			value = i64(clang.get_enum_constant_decl_value(cursor))
		}
		member := Enum_Member {
			name  = clone_clang_string(clang.get_cursor_spelling(cursor)),
			value = value,
			doc   = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
		}
		append(&fill.members, member)
	}
	return .Continue
}

// Follow typedefs to the underlying builtin and ask whether it is unsigned.
// Non-builtin / unknown → signed capture (the historical default).
enum_backing_is_unsigned :: proc(ir: ^IR, backing: Type_Handle) -> bool {
	handle := backing
	for {
		info := ir_type(ir, handle)
		#partial switch v in info.variant {
		case Type_Builtin:
			return builtin_is_unsigned(v.kind)
		case Type_Typedef_Ref:
			handle = ir.typedefs[v.decl].aliased
		case:
			return false
		}
	}
}

// Get or create the IR declaration for a struct/union cursor, and fill in
// its fields when this cursor is the definition. Placeholders created for a
// forward declaration (or a first mention inside another type) are completed
// later when the definition shows up.
record_decl_for_cursor :: proc(state: ^Extract_State, cursor: clang.Cursor) -> Decl_Handle {
	// libclang gives every anonymous union/struct nested in the same parent
	// the same USR (e.g. c:@S@Node@Ua for both unions in a TreeNode). Sharing
	// by USR would collapse distinct layouts into one IR decl — Box3D's
	// TreeNode is the dogfood case. Anonymous records are never shared.
	is_anonymous := clang.cursor_is_anonymous(cursor) != 0
	usr := clone_clang_string(clang.get_cursor_usr(cursor))
	if !is_anonymous {
		if ref, found := state.decl_map[usr]; usr != "" && found {
			handle := Decl_Handle(ref.index)
			if state.ir.records[int(handle)].doc == "" {
				state.ir.records[int(handle)].doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor))
			}
			// Definition may carry the attribute when the forward decl did not.
			if !state.ir.records[int(handle)].deprecated {
				state.ir.records[int(handle)].deprecated, state.ir.records[int(handle)].deprecated_message = cursor_deprecation(cursor)
			}
			if clang.is_cursor_definition(cursor) != 0 && !state.ir.records[int(handle)].is_complete {
				if cursor_is_foreign(cursor) {
					// A system header's layout is not ours to copy into the IR
					// as if we had bound it. Stays a pool-only,
					// incomplete entry for Transformation to resolve.
				} else {
					// Ours: the definition site wins for output placement, and
					// a record first seen through another type now becomes a
					// real emitted declaration with its layout.
					if home := cursor_home(state, cursor); home != 0 {
						state.ir.records[int(handle)].home = home
					}
					ir_promote_record(state.ir, handle)
					fill_record(state, handle, cursor)
				}
			}
			return handle
		}
	}

	home := cursor_home(state, cursor)
	is_foreign := cursor_is_foreign(cursor)
	record := Record_Decl {
		is_union   = clang.get_cursor_kind(cursor) == .Union_Decl,
		home       = home,
		is_foreign = is_foreign,
	}
	// Anonymous records keep "" as their name: recent libclang spells them
	// as "struct (unnamed at file:line)", which is a description, not a name.
	if !is_anonymous {
		record.name = clone_clang_string(clang.get_cursor_spelling(cursor))
	}
	record.deprecated, record.deprecated_message = cursor_deprecation(cursor)
	record.doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor))
	// System-header records enter the pool for type-graph resolution but not
	// the ordering list — they must not be emitted as full standalone decls.
	// Transformation maps them (posix.sockaddr) or promotes an incomplete stub.
	handle := ir_create_record(state.ir, record)
	if !is_foreign {
		ir_promote_record(state.ir, handle)
	}
	// Only named records enter decl_map. Anonymous ones must not: shared USRs
	// would alias distinct nested types (see is_anonymous note above).
	if !is_anonymous && usr != "" {
		state.decl_map[usr] = Decl_Ref {
			kind  = .Record,
			index = u32(handle),
		}
	}
	// Only fill layout for records that are ours. System tags stay incomplete
	// so we never claim a system header's field list as our binding.
	if clang.is_cursor_definition(cursor) != 0 && !is_foreign {
		fill_record(state, handle, cursor)
	}
	return handle
}

Record_Fill :: struct {
	ctx:                  runtime.Context,
	state:                ^Extract_State,
	fields:               [dynamic]Field,
	is_packed:            bool,
	failed_field:         string, // first field with an unsupported type; "" if none
	failed_bitfield_fact: string, // first bit-field whose width/offset is unavailable
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
	clang.visit_children(cursor, visit_record_child, clang.Client_Data(rawptr(&fill)))

	// Written back by handle: the records pool may have grown while nested
	// types were captured, so no pointer into it was held across the visit.
	record := state.ir.records[int(handle)]
	record.is_complete = true
	record.is_packed = fill.is_packed
	record_type := clang.get_cursor_type(cursor)
	record.size = measured_size_of(record_type)
	record.alignment = measured_alignment_of(record_type)
	if fill.failed_field != "" || fill.failed_bitfield_fact != "" {
		// An opaque record must not retain a misleading partial field list.
		record.fields = nil
		record.has_unrepresentable_fields = true
	} else {
		record.fields = fill.fields[:]
	}
	if fill.failed_field != "" {
		ir_diag(
			state.ir,
			.Opaque_Layout_Fallback,
			"%q field %q has an unsupported type; emitted opaque — by-value use of it would be wrong",
			record_display_name(record),
			fill.failed_field,
		)
	}
	if fill.failed_bitfield_fact != "" {
		ir_diag(
			state.ir,
			.Bit_Field_Layout_Fallback,
			"%q bit-field %q has an unknown width or offset; emitted opaque",
			record_display_name(record),
			fill.failed_bitfield_fact,
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
	fill := cast(^Record_Fill)rawptr(client_data)
	context = fill.ctx

	#partial switch clang.get_cursor_kind(cursor) {
	case .Field_Decl:
		name := clone_clang_string(clang.get_cursor_spelling(cursor))
		clang_type := clang.get_cursor_type(cursor)
		type, type_ok := capture_type(fill.state, clang_type)
		if !type_ok {
			if fill.failed_field == "" {
				fill.failed_field = name
			}
			return .Continue
		}
		is_bitfield := clang.cursor_is_bit_field(cursor) != 0
		bit_width: i64
		if is_bitfield {
			bit_width = i64(clang.get_field_decl_bit_width(cursor))
		}
		bit_offset := i64(clang.cursor_get_offset_of_field(cursor))
		if is_bitfield && (bit_width < 0 || bit_offset < 0) {
			if fill.failed_bitfield_fact == "" {
				fill.failed_bitfield_fact = name if name != "" else "(anonymous)"
			}
			return .Continue
		}
		append(
			&fill.fields,
			Field {
				name = name,
				type = type,
				is_bitfield = is_bitfield,
				bit_width = bit_width,
				bit_offset = bit_offset,
				size = measured_size_of(clang_type),
				alignment = measured_alignment_of(clang_type),
				doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
			},
		)
	case .Packed_Attr:
		fill.is_packed = true
	case .Struct_Decl, .Union_Decl, .Enum_Decl:
		// A C11 anonymous member (union { ... }; with no declarator) never
		// gets a FieldDecl — the bare tag declaration is the member, so it
		// must become a field here or the record's layout silently shrinks.
		// Named tag declarations are captured lazily when a field's type
		// references them; nothing to do for those.
		if clang.cursor_is_anonymous_record_decl(cursor) != 0 {
			clang_type := clang.get_cursor_type(cursor)
			type, type_ok := capture_type(fill.state, clang_type)
			if !type_ok {
				if fill.failed_field == "" {
					fill.failed_field = "(anonymous member)"
				}
				return .Continue
			}
			append(
				&fill.fields,
				Field {
					name = "",
					type = type,
					bit_offset = i64(clang.cursor_get_offset_of_field(cursor)),
					size = measured_size_of(clang_type),
					alignment = measured_alignment_of(clang_type),
					doc = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
				},
			)
		}
	}
	return .Continue
}

extract_func :: proc(state: ^Extract_State, cursor: clang.Cursor) {
	if already_captured(state, cursor) {
		return
	}
	name := clone_clang_string(clang.get_cursor_spelling(cursor))

	// static (usually static inline) functions have no linkable symbol.
	if clang.cursor_get_storage_class(cursor) == .Static {
		user_errorf("h2odin: skipping %q: static functions have no external symbol", name)
		return
	}

	return_type, return_ok := capture_type(state, clang.get_cursor_result_type(cursor))
	if !return_ok {
		user_errorf("h2odin: skipping %q: unsupported return type", name)
		return
	}

	num_params := int(clang.cursor_get_num_arguments(cursor))
	params := make([]Param, num_params)
	for i in 0 ..< num_params {
		arg := clang.cursor_get_argument(cursor, c.uint(i))
		param_type, param_ok := capture_param_type(state, clang.get_cursor_type(arg))
		if !param_ok {
			user_errorf("h2odin: skipping %q: unsupported type of parameter %d", name, i)
			return
		}
		params[i] = Param {
			name = clone_clang_string(clang.get_cursor_spelling(arg)),
			type = param_type,
		}
	}

	deprecated, deprecated_message := cursor_deprecation(cursor)
	// Calling convention is a property of the function *type*, not the cursor.
	func_type := clang.get_cursor_type(cursor)
	func := Func_Decl {
		name               = name,
		return_type        = return_type,
		params             = params,
		is_variadic        = clang.cursor_is_variadic(cursor) != 0,
		calling_conv       = calling_conv_from_clang(clang.get_function_type_calling_conv(func_type)),
		deprecated         = deprecated,
		deprecated_message = deprecated_message,
		doc                = clone_clang_string(clang.cursor_get_raw_comment_text(cursor)),
		home               = cursor_home(state, cursor),
	}
	ir_add_func(state.ir, func)
	remember_captured(state, cursor, .Func, u32(len(state.ir.funcs) - 1))
}

// Deprecation is a header fact. Availability reports Deprecated;
// platform availability recovers the attribute message (empty when none).
cursor_deprecation :: proc(cursor: clang.Cursor) -> (deprecated: bool, message: string) {
	if clang.get_cursor_availability(cursor) != .Deprecated {
		return false, ""
	}
	always_deprecated: c.int
	deprecated_message: clang.String
	always_unavailable: c.int
	unavailable_message: clang.String
	_ = clang.get_cursor_platform_availability(cursor, &always_deprecated, &deprecated_message, &always_unavailable, &unavailable_message, nil, 0)
	// always_* flags are not needed once availability is Deprecated; still
	// release both CXStrings the call may fill.
	_ = always_deprecated
	_ = always_unavailable
	message = clone_clang_string(deprecated_message)
	clang.dispose_string(unavailable_message)
	return true, message
}

// True when this cursor's USR is already in decl_map (captured from another
// input TU or an earlier include of the same sibling). Empty USR means the
// entity cannot be shared; treat it as not-yet-captured.
already_captured :: proc(state: ^Extract_State, cursor: clang.Cursor) -> bool {
	usr := clone_clang_string(clang.get_cursor_usr(cursor))
	if usr == "" {
		return false
	}
	_, found := state.decl_map[usr]
	return found
}

remember_captured :: proc(state: ^Extract_State, cursor: clang.Cursor, kind: Decl_Kind, index: u32) {
	usr := clone_clang_string(clang.get_cursor_usr(cursor))
	if usr == "" {
		return
	}
	state.decl_map[usr] = Decl_Ref {
		kind  = kind,
		index = index,
	}
}

// Copy a libclang-owned string into the generation arena and release the
// original. This is the boundary habit that keeps foreign lifetimes out of
// the IR.
