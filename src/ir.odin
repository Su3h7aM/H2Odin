package h2odin

// The IR is H2Odin's own description of a C API.
//
// Declarations live in dense pools. References between pieces of the IR are
// handles (indices), never pointers — pool growth invalidates pointers. A
// separate ordering list remembers source order so the output reads like the
// original header; dropping a declaration later just removes it from the
// ordering list.
//
// Every pool and every string in the IR belongs to the generation arena.

// ---------------------------------------------------------------- Types

// Handle into the IR type pool. Slot 0 holds the invalid type (nil variant),
// so a zero-valued handle means "no type" rather than silently naming a real
// one.
Type_Handle :: distinct u32

// Handle into one of the declaration pools; which pool is known from the
// context where the handle is stored (Type_Record_Ref points into records,
// and so on).
Decl_Handle :: distinct u32

// Handle into IR.input_headers. Slot 0 is empty (no home); real input headers
// are 1-based. Extraction records provenance; Transformation places decls.
Input_Header_Handle :: distinct u32

// The C builtin types the IR knows.
Builtin_Kind :: enum {
	Void,
	Bool,
	// Plain C char — distinct from schar/uchar. Its signedness is
	// implementation-defined by the C standard, but not ambiguous: libclang
	// reports which one the extraction target actually uses, split here into
	// two kinds so that fact survives instead of being discarded.
	Char_Signed,
	Char_Unsigned,
	S_Char,
	U_Char,
	Short,
	U_Short,
	Int,
	U_Int,
	Long,
	U_Long,
	Long_Long,
	U_Long_Long,
	Float,
	Double,
}

Type_Info :: struct {
	// Top-level const qualification, captured faithfully. Pointer lowering
	// needs it (const char * vs char *); nothing else reads it yet.
	is_const: bool,
	variant:  Type_Variant,
}

// nil variant == the invalid type.
Type_Variant :: union {
	Type_Builtin,
	Type_Std,
	Type_Idiomatic_Leaf,
	Type_Pointer,
	Type_Lowered_Pointer,
	Type_Array,
	Type_Proc,
	Type_Record_Ref,
	Type_Enum_Ref,
	Type_Typedef_Ref,
	Type_Bit_Set,
}

Type_Builtin :: struct {
	kind: Builtin_Kind,

	// Size in bytes as reported by libclang on the extraction target — a
	// measured fact, not an assumption, and the basis for later proving
	// idiomatic substitutions ABI-safe. -1 means libclang could not size
	// the type; downstream must treat -1 as "unknown, cannot prove a
	// substitution", never substitute a plausible-looking value.
	size: int,
}

// A well-known C standard typedef (stdint.h / stddef.h) from an included
// header, kept under its familiar name via core:c — uint32_t stays
// c.uint32_t instead of dragging libc-internal typedef chains into the
// output.
Type_Std :: struct {
	name:     string,

	// Same contract as Type_Builtin.size: measured by libclang on the
	// extraction target, -1 when unknown.
	size:     int,

	// Signedness of the typedef's canonical type, as libclang reports it on
	// the extraction target — a measured fact, never guessed from the name.
	// Needed to derive a native spelling for typedefs whose width and sign
	// both vary by target (wchar_t, the *_fast*_t family).
	unsigned: bool,
}

Idiomatic_Reason :: enum {
	// The type table names a semantic preference for this C type (e.g.
	// size_t -> uint) and the size libclang measured on the target confirms
	// it — the confirmation is a honesty check, not a real expectation of
	// failure.
	Table_Preference,
	// No table preference applies; the native spelling was derived directly
	// from the measured size and signedness (e.g. an unsigned 2-byte type
	// becomes u16). Complete for any integer leaf whose size was measured.
	Derived_From_Measurement,
	// The config's type_map named this type explicitly.
	Config_Override,
	// Opaque handle: typedef of a pointer to an incomplete record (automatic)
	// or a void* typedef opted in via types.distinct. Spelling is
	// `distinct rawptr`.
	Opaque_Handle,
	// Foreign C type mapped to its Odin defining package: POSIX
	// names to core:sys/posix (sockaddr → posix.sockaddr), ISO C library
	// names to core:c/libc (time_t → libc.time_t). Emission imports the
	// package the spelling names. One spelling in both type modes.
	Platform_Type,
}

// Transformation's decision to spell a C type with an explicit Odin
// spelling — either an idiomatic substitution proven safe on the target, or
// a config's direct type_map override requested by name. Leaves that could
// not be resolved to a native spelling (rung 3: unknown size, or no scalar
// shape at all) keep their ABI spelling. The original type moves to its own
// slot so the decision stays auditable (and signedness queries on an enum's
// backing type keep working).
Type_Idiomatic_Leaf :: struct {
	original: Type_Handle, // the type this decision replaced
	spelling: string, // from types.odin, or copied verbatim from a type_map value
	reason:   Idiomatic_Reason,
}

Type_Pointer :: struct {
	pointee:              Type_Handle,
	// Extraction: this pointer came from a C array parameter form that decayed
	// at the ABI boundary. Proven multi-pointer candidate.
	is_array_param_decay: bool,
}

Pointer_Lowering_Kind :: enum {
	Single, // T* → ^T
	Multi, // T* with array semantics → [^]T (ABI-identical)
	Rawptr, // void* → rawptr
	CString, // const char* → cstring
	Proc, // function pointer → proc "c" (...)
}

Pointer_Lowering_Confidence :: enum {
	Proven,
	Guessed,
}

Pointer_Lowering_Reason :: enum {
	Void_Pointer,
	Const_Char_Pointer,
	Function_Pointer,
	Single_Pointer_Default,
	Array_Param_Decay, // C array parameter form decayed to pointer (Extraction fact)
	Configured_Multi, // procs.params pointer = "multi"
}

Type_Lowered_Pointer :: struct {
	pointee:    Type_Handle,
	kind:       Pointer_Lowering_Kind,
	confidence: Pointer_Lowering_Confidence,
	reason:     Pointer_Lowering_Reason,
}

Type_Array :: struct {
	element:       Type_Handle,
	count:         i64,
	is_incomplete: bool, // T[] — flexible array member or extern array of unknown size
}

// C calling convention as measured by libclang (Extraction fact). Emission
// maps supported values to Odin spellings (`"c"`, `"stdcall"`, …); unsupported
// non-default values become an error diagnostic rather than silent `"c"`.
// Zero value is Default (CXCallingConv_Default).
Calling_Conv :: enum u8 {
	Default,
	C,
	Stdcall,
	Fastcall,
	Thiscall,
	Vectorcall,
	Win64,
	Sys_V,
	// Anything libclang reports that we do not map to an Odin convention
	// string (Swift, AAPCS, Preserve*, …). Still a fact: not silently C.
	Other,
	// libclang returned Invalid / Unexposed.
	Unknown,
}

// A C function type (always used through a pointer in practice). Parameter
// names at the type level are usually empty.
Type_Proc :: struct {
	return_type:  Type_Handle,
	params:       []Param,
	is_variadic:  bool,
	calling_conv: Calling_Conv,
}

Type_Record_Ref :: struct {
	decl: Decl_Handle, // into IR.records
}

Type_Enum_Ref :: struct {
	decl: Decl_Handle, // into IR.enums
}

Type_Typedef_Ref :: struct {
	decl: Decl_Handle, // into IR.typedefs
}

// Odin `bit_set[Enum; uN]` produced by enums.bit_sets (log2 transform). The
// element enum is a normal Enum_Decl; this type is only the set wrapper.
// backing_bits is the proven width from the C enum's measured integer type;
// never size from the highest flag bit.
Type_Bit_Set :: struct {
	elem:         Type_Handle, // Type_Enum_Ref to the flag enum
	backing_bits: int, // 8 / 16 / 32 / 64
}

// ---------------------------------------------------------------- Decls

Decl_Kind :: enum {
	Invalid,
	Func,
	Record,
	Enum,
	Typedef,
	Var,
	Macro,
	Bit_Set, // named bit_set[Enum] alias produced by enum policy
	Wrapper, // idiomatic generator-authored proc over a faithful foreign func
}

// An entry in the ordering list: which pool, and where in that pool.
Decl_Ref :: struct {
	kind:  Decl_Kind,
	index: u32,
}

Param_Facts :: struct {
	is_length_like:            bool,
	length_for_pointer_index:  i32,
	has_length_like_neighbour: bool,
	length_param_index:        i32,
}

Param :: struct {
	name:          string, // "" when the parameter is unnamed in the header
	type:          Type_Handle,
	// Non-empty: emit this spelling instead of following `type` (procs.param).
	type_spelling: string,
	// Non-empty: emit as a default argument expression (procs.param).
	default:       string,
	// Idiomatic-only: emit `#by_ptr name: T` for a single data pointer param
	// (pointee spelling). Explicit policy only — never inferred from const.
	by_ptr:        bool,
	facts:         Param_Facts,
}

Func_Decl :: struct {
	name:                 string,

	// The C symbol when a rename changed the Odin-visible name; "" means
	// name still is the symbol and no @(link_name) is needed.
	link_name:            string,
	return_type:          Type_Handle,
	// Non-empty: emit this spelling for the return type (procs.result).
	return_type_spelling: string,
	params:               []Param,
	is_variadic:          bool,
	// libclang calling convention on the function type (Extraction fact).
	calling_conv:         Calling_Conv,
	// C deprecation fact (attribute / availability). Message is
	// arena-copied; empty when the attribute carries none.
	deprecated:           bool,
	deprecated_message:   string,
	// procs.require_results: callers must use/acknowledge results (Odin attr).
	require_results:      bool,
	doc:                  string,
	// Configured input header that owns this declaration for output placement.
	home:                 Input_Header_Handle,
}

Field :: struct {
	name:          string, // "" for C11 anonymous struct/union members
	type:          Type_Handle,
	// Target-measured layout facts copied from libclang. bit_offset is from
	// the start of the containing record. size/alignment describe an ordinary
	// field's type; bit-field storage is proven from the surrounding offsets
	// instead. Negative values mean libclang could not answer.
	is_bitfield:   bool,
	bit_width:     i64,
	bit_offset:    i64,
	size:          int,
	alignment:     int,
	// Non-empty: emit this spelling instead of following `type` (structs.field).
	type_spelling: string,
	// Non-empty: field tag text inside backticks, e.g. fmt:"s,0".
	tag:           string,
	doc:           string,
}

// A C struct or union.
Record_Decl :: struct {
	name:                       string, // "" when anonymous
	fields:                     []Field,
	// Target-measured record layout. Negative means libclang could not answer.
	size:                       int,
	alignment:                  int,
	is_union:                   bool,
	is_packed:                  bool,
	// Positive → emit #align(N). Zero means no alignment attribute.
	align:                      int,
	is_complete:                bool, // false → opaque (forward-declared only)

	// The header defines a layout the IR cannot represent (for example, a
	// field of an unsupported type). Extraction or the bit-field layout proof
	// reports why; emission falls back rather than guessing.
	has_unrepresentable_fields: bool,
	// Incomplete tag emitted as handle (mode default or
	// types.opaque override): `Name :: distinct rawptr`, one pointer level
	// collapsed at references.
	emit_as_handle:             bool,
	is_typedef_named:           bool, // anonymous tag that a typedef gives a name to
	// Declared in a system header: someone else's type. Its layout is not
	// ours to claim; Transformation maps it, stubs it, or
	// diagnoses it. Distinct from `home`, which is about output placement.
	is_foreign:                 bool,
	// C deprecation fact.
	deprecated:                 bool,
	deprecated_message:         string,
	doc:                        string,
	// Definition site wins over an earlier placeholder's home (see fill_record).
	home:                       Input_Header_Handle,
}

Enum_Member :: struct {
	name:  string,
	value: i64, // raw bits; interpret via the backing type's signedness
	doc:   string,
}

Enum_Decl :: struct {
	name:               string, // "" when anonymous
	backing:            Type_Handle,
	members:            []Enum_Member,
	is_typedef_named:   bool,
	is_foreign:         bool, // declared in a system header (see Record_Decl)
	// C deprecation fact.
	deprecated:         bool,
	deprecated_message: string,
	doc:                string,
	// Definition site wins over an earlier placeholder's home (see fill_enum).
	home:               Input_Header_Handle,
}

Typedef_Decl :: struct {
	name:               string,
	aliased:            Type_Handle,

	// The underlying type could not be captured. The typedef is skipped and
	// so is anything that uses it — emitting a dangling name would just move
	// the failure into the generated code.
	is_unresolvable:    bool,
	is_foreign:         bool, // declared in a system header (see Record_Decl)
	// C deprecation fact.
	deprecated:         bool,
	deprecated_message: string,
	doc:                string,
	home:               Input_Header_Handle,
}

Var_Decl :: struct {
	name:               string,
	link_name:          string, // as in Func_Decl
	type:               Type_Handle,
	// C deprecation fact. Emitted as a Deprecated: doc line (no
	// Odin attribute on variables).
	deprecated:         bool,
	deprecated_message: string,
	doc:                string,
	home:               Input_Header_Handle,
}

Macro_Token_Kind :: enum {
	Punctuation,
	Keyword,
	Identifier,
	Literal,
	Comment,
}

Macro_Token :: struct {
	spelling: string,
	kind:     Macro_Token_Kind,
}

// An object-like #define constant, or a function-like macro recorded so the
// pipeline knows it exists (never emitted).
Macro_Decl :: struct {
	name:               string,
	tokens:             []Macro_Token, // raw replacement-list tokens after the name
	is_function_like:   bool,
	// C deprecation fact when libclang reports it (rare for
	// macros). Emitted as a Deprecated: doc line like variables.
	deprecated:         bool,
	deprecated_message: string,
	doc:                string,
	home:               Input_Header_Handle,
}

// A named `Name :: bit_set[Enum; uN]` produced by enums.bit_sets. Stored as
// its own pool entry so emission stays a pure serialization of IR decls.
// backing_bits is the C enum's measured integer width in bits.
Bit_Set_Decl :: struct {
	name:         string,
	elem:         Type_Handle, // Type_Enum_Ref
	backing_bits: int, // 8 / 16 / 32 / 64
	doc:          string,
	// Inherits the element enum's home (set in Transformation).
	home:         Input_Header_Handle,
}

// Out-parameter promoted to a named multi-result (peels one pointer level).
Wrapper_Out_Param :: struct {
	param_index: int,
	result_name: string, // public result name (usually the param's Odin name)
}

// Pointer + count → one []T public parameter.
Wrapper_Slice :: struct {
	pointer_index: int,
	count_index:   int,
	public_name:   string,
}

// Idiomatic-only public procedure that calls a retained faithful foreign func.
// Transformation plans; Emission serializes a minimal body.
Wrapper_Decl :: struct {
	name:            string, // public Odin name
	target:          Decl_Handle, // ir.funcs index
	home:            Input_Header_Handle,
	require_results: bool,
	out_params:      []Wrapper_Out_Param,
	slices:          []Wrapper_Slice,
	// Keep the C return value as a named result (default true).
	keep_c_return:   bool,
	doc:             string,
}

// IR owns the complete, libclang-independent model of one generation run.
// Declarations and types live in dense arena-backed pools and refer to one
// another by handles, never pointers. `order` is a presentation/provenance
// index over live declarations; removing an item from it does not invalidate
// pool handles.
IR :: struct {
	types:         [dynamic]Type_Info,
	funcs:         [dynamic]Func_Decl,
	records:       [dynamic]Record_Decl,
	enums:         [dynamic]Enum_Decl,
	typedefs:      [dynamic]Typedef_Decl,
	vars:          [dynamic]Var_Decl,
	macros:        [dynamic]Macro_Decl,
	bit_sets:      [dynamic]Bit_Set_Decl,
	wrappers:      [dynamic]Wrapper_Decl,
	order:         [dynamic]Decl_Ref,

	// Configured input headers in config.inputs order. Slot 0 is empty so a
	// zero Input_Header_Handle means "no home". Paths are as passed to
	// extract (resolved absolute or relative); matching uses normalize_source_path.
	input_headers: [dynamic]string,

	// Non-certain decisions and honesty notes collected during the run.
	// Messages are arena-owned; main prints them as a single report on
	// stderr after the pipeline (bindings go to config.output_folder or
	// -destination:stdout). Each entry carries a named category; severity
	// is resolved at report time from policy (and any local constructor
	// override stored on the entry).
	diagnostics:   [dynamic]Diagnostic,

	// Interning table for the pre-seeded, unqualified builtin types.
	builtins:      [Builtin_Kind]Type_Handle,
}

// -------------------------------------------------------------- Helpers

// Pre-seed the type pool: slot 0 is the invalid type, then one entry per
// builtin so extraction can intern them by lookup. Slot 0 of input_headers is
// empty so a zero home handle means "no home".
ir_init :: proc(ir: ^IR) {
	append(&ir.types, Type_Info{}) // slot 0: invalid
	append(&ir.input_headers, "") // slot 0: no home
	for kind in Builtin_Kind {
		// Sizes start unknown (-1); extraction fills each shared entry the
		// first time it measures that kind. One entry per kind stays sound
		// because a builtin's size cannot vary within a single target.
		ir.builtins[kind] = ir_add_type(ir, Type_Info{variant = Type_Builtin{kind = kind, size = -1}})
	}
}

// Register config.inputs paths on the IR and return a normalized-path → handle
// map for Extraction's location checks. Paths are stored as given (for stems);
// allocator owns only the returned lookup map and its normalized keys.
ir_register_input_headers :: proc(ir: ^IR, header_paths: []string, allocator := context.allocator) -> map[string]Input_Header_Handle {
	files := make(map[string]Input_Header_Handle, allocator)
	for path in header_paths {
		handle := Input_Header_Handle(len(ir.input_headers))
		append(&ir.input_headers, path)
		if key := normalize_source_path(path, allocator); key != "" {
			files[key] = handle
		}
	}
	return files
}

ir_input_header_path :: proc(ir: ^IR, home: Input_Header_Handle) -> string {
	i := int(home)
	if i <= 0 || i >= len(ir.input_headers) {
		return ""
	}
	return ir.input_headers[i]
}

// Home header of a live declaration; 0 when unset (internal error in per_header).
ir_decl_home :: proc(ir: ^IR, ref: Decl_Ref) -> Input_Header_Handle {
	switch ref.kind {
	case .Invalid:
		return 0
	case .Func:
		return ir.funcs[ref.index].home
	case .Record:
		return ir.records[ref.index].home
	case .Enum:
		return ir.enums[ref.index].home
	case .Typedef:
		return ir.typedefs[ref.index].home
	case .Var:
		return ir.vars[ref.index].home
	case .Macro:
		return ir.macros[ref.index].home
	case .Bit_Set:
		return ir.bit_sets[ref.index].home
	case .Wrapper:
		return ir.wrappers[ref.index].home
	}
	return 0
}

ir_set_decl_home :: proc(ir: ^IR, ref: Decl_Ref, home: Input_Header_Handle) {
	switch ref.kind {
	case .Invalid:
	case .Func:
		ir.funcs[ref.index].home = home
	case .Record:
		ir.records[ref.index].home = home
	case .Enum:
		ir.enums[ref.index].home = home
	case .Typedef:
		ir.typedefs[ref.index].home = home
	case .Var:
		ir.vars[ref.index].home = home
	case .Macro:
		ir.macros[ref.index].home = home
	case .Bit_Set:
		ir.bit_sets[ref.index].home = home
	case .Wrapper:
		ir.wrappers[ref.index].home = home
	}
}

ir_add_type :: proc(ir: ^IR, info: Type_Info) -> Type_Handle {
	append(&ir.types, info)
	return Type_Handle(len(ir.types) - 1)
}

ir_builtin_type :: proc(ir: ^IR, kind: Builtin_Kind) -> Type_Handle {
	return ir.builtins[kind]
}

ir_type :: proc(ir: ^IR, handle: Type_Handle) -> Type_Info {
	return ir.types[int(handle)]
}

// Each add_* appends to its pool and records the declaration in the ordering
// list. Records and enums may be created as placeholders when first
// referenced and filled in when their definition is visited; they enter the
// ordering list at creation, which matches where the header first names them.

ir_add_func :: proc(ir: ^IR, decl: Func_Decl) {
	append(&ir.funcs, decl)
	append(&ir.order, Decl_Ref{kind = .Func, index = u32(len(ir.funcs) - 1)})
}

ir_add_record :: proc(ir: ^IR, decl: Record_Decl) -> Decl_Handle {
	append(&ir.records, decl)
	handle := Decl_Handle(len(ir.records) - 1)
	append(&ir.order, Decl_Ref{kind = .Record, index = u32(handle)})
	return handle
}

// Create a record pool entry without adding it to the ordering list. Used for
// foreign (non-input) records captured transitively through type references:
// they must exist in the pool so handles resolve, but they must not be emitted
// as standalone declarations. A later definition in a configured input promotes
// the record into order via ir_promote_record.
ir_create_record :: proc(ir: ^IR, decl: Record_Decl) -> Decl_Handle {
	append(&ir.records, decl)
	return Decl_Handle(len(ir.records) - 1)
}

// Promote a pool-only record into the ordering list (emission). Called when a
// foreign record's definition lands in a configured input header.
ir_promote_record :: proc(ir: ^IR, handle: Decl_Handle) {
	for ref in ir.order {
		if ref.kind == .Record && ref.index == u32(handle) {
			return // already in order
		}
	}
	append(&ir.order, Decl_Ref{kind = .Record, index = u32(handle)})
}

ir_add_enum :: proc(ir: ^IR, decl: Enum_Decl) -> Decl_Handle {
	append(&ir.enums, decl)
	handle := Decl_Handle(len(ir.enums) - 1)
	append(&ir.order, Decl_Ref{kind = .Enum, index = u32(handle)})
	return handle
}

// Create an enum pool entry without adding it to the ordering list. Mirrors
// ir_create_record for foreign enums captured transitively.
ir_create_enum :: proc(ir: ^IR, decl: Enum_Decl) -> Decl_Handle {
	append(&ir.enums, decl)
	return Decl_Handle(len(ir.enums) - 1)
}

// Promote a pool-only enum into the ordering list (emission).
ir_promote_enum :: proc(ir: ^IR, handle: Decl_Handle) {
	for ref in ir.order {
		if ref.kind == .Enum && ref.index == u32(handle) {
			return // already in order
		}
	}
	append(&ir.order, Decl_Ref{kind = .Enum, index = u32(handle)})
}

ir_add_typedef :: proc(ir: ^IR, decl: Typedef_Decl) -> Decl_Handle {
	append(&ir.typedefs, decl)
	handle := Decl_Handle(len(ir.typedefs) - 1)
	append(&ir.order, Decl_Ref{kind = .Typedef, index = u32(handle)})
	return handle
}

// Create a typedef pool entry without adding it to the ordering list. Mirrors
// ir_create_record for foreign typedefs captured transitively: the name and
// underlying type stay available to Transformation, but the declaration is
// not ours to emit.
ir_create_typedef :: proc(ir: ^IR, decl: Typedef_Decl) -> Decl_Handle {
	append(&ir.typedefs, decl)
	return Decl_Handle(len(ir.typedefs) - 1)
}

ir_add_var :: proc(ir: ^IR, decl: Var_Decl) {
	append(&ir.vars, decl)
	append(&ir.order, Decl_Ref{kind = .Var, index = u32(len(ir.vars) - 1)})
}

ir_add_macro :: proc(ir: ^IR, decl: Macro_Decl) {
	append(&ir.macros, decl)
	append(&ir.order, Decl_Ref{kind = .Macro, index = u32(len(ir.macros) - 1)})
}

ir_add_bit_set :: proc(ir: ^IR, decl: Bit_Set_Decl) {
	append(&ir.bit_sets, decl)
	append(&ir.order, Decl_Ref{kind = .Bit_Set, index = u32(len(ir.bit_sets) - 1)})
}

// Append a wrapper and return its pool index. Does not insert into order —
// callers insert next to the target foreign decl for stable placement.
ir_add_wrapper :: proc(ir: ^IR, decl: Wrapper_Decl) -> Decl_Handle {
	append(&ir.wrappers, decl)
	return Decl_Handle(len(ir.wrappers) - 1)
}

ir_add_wrapper_to_order :: proc(ir: ^IR, handle: Decl_Handle) {
	append(&ir.order, Decl_Ref{kind = .Wrapper, index = u32(handle)})
}
