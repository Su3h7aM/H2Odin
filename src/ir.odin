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

// The C builtin types the IR knows.
Builtin_Kind :: enum {
	Void,
	Bool,
	Char, // plain C char — distinct from schar/uchar, its signedness is implementation-defined
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
	Type_Pointer,
	Type_Array,
	Type_Proc,
	Type_Record_Ref,
	Type_Enum_Ref,
	Type_Typedef_Ref,
}

Type_Builtin :: struct {
	kind: Builtin_Kind,
}

// A well-known C standard typedef (stdint.h / stddef.h) from an included
// header, kept under its familiar name via core:c — uint32_t stays
// c.uint32_t instead of dragging libc-internal typedef chains into the
// output.
Type_Std :: struct {
	name: string,
}

Type_Pointer :: struct {
	pointee: Type_Handle,
}

Type_Array :: struct {
	element:       Type_Handle,
	count:         i64,
	is_incomplete: bool, // T[] — flexible array member or extern array of unknown size
}

// A C function type (always used through a pointer in practice). Parameter
// names at the type level are usually empty.
Type_Proc :: struct {
	return_type: Type_Handle,
	params:      []Param,
	is_variadic: bool,
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

// ---------------------------------------------------------------- Decls

Decl_Kind :: enum {
	Invalid,
	Func,
	Record,
	Enum,
	Typedef,
	Var,
	Macro,
}

// An entry in the ordering list: which pool, and where in that pool.
Decl_Ref :: struct {
	kind:  Decl_Kind,
	index: u32,
}

Param :: struct {
	name: string, // "" when the parameter is unnamed in the header
	type: Type_Handle,
}

Func_Decl :: struct {
	name:        string,
	return_type: Type_Handle,
	params:      []Param,
	is_variadic: bool,
	doc:         string,
}

Field :: struct {
	name: string, // "" for C11 anonymous struct/union members
	type: Type_Handle,
	doc:  string,
}

// A C struct or union.
Record_Decl :: struct {
	name:                       string, // "" when anonymous
	fields:                     []Field,
	is_union:                   bool,
	is_packed:                  bool,
	is_complete:                bool, // false → opaque (forward-declared only)

	// The header defines a layout the IR cannot represent yet (bit-fields,
	// or a field of an unsupported type). Extraction reports why; emission
	// falls back to an opaque body rather than guessing at the layout.
	has_unrepresentable_fields: bool,
	is_typedef_named:           bool, // anonymous tag that a typedef gives a name to
	doc:                        string,
}

Enum_Member :: struct {
	name:  string,
	value: i64, // raw bits; interpret via the backing type's signedness
	doc:   string,
}

Enum_Decl :: struct {
	name:             string, // "" when anonymous
	backing:          Type_Handle,
	members:          []Enum_Member,
	is_typedef_named: bool,
	doc:              string,
}

Typedef_Decl :: struct {
	name:            string,
	aliased:         Type_Handle,

	// The underlying type could not be captured. The typedef is skipped and
	// so is anything that uses it — emitting a dangling name would just move
	// the failure into the generated code.
	is_unresolvable: bool,
	doc:             string,
}

Var_Decl :: struct {
	name: string,
	type: Type_Handle,
	doc:  string,
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
	name:             string,
	tokens:           []Macro_Token, // raw replacement-list tokens after the name
	is_function_like: bool,
	doc:              string,
}

IR :: struct {
	types:    [dynamic]Type_Info,
	funcs:    [dynamic]Func_Decl,
	records:  [dynamic]Record_Decl,
	enums:    [dynamic]Enum_Decl,
	typedefs: [dynamic]Typedef_Decl,
	vars:     [dynamic]Var_Decl,
	macros:   [dynamic]Macro_Decl,
	order:    [dynamic]Decl_Ref,

	// Interning table for the pre-seeded, unqualified builtin types.
	builtins: [Builtin_Kind]Type_Handle,
}

// -------------------------------------------------------------- Helpers

// Pre-seed the type pool: slot 0 is the invalid type, then one entry per
// builtin so extraction can intern them by lookup.
ir_init :: proc(ir: ^IR) {
	append(&ir.types, Type_Info{}) // slot 0: invalid
	for kind in Builtin_Kind {
		ir.builtins[kind] = ir_add_type(ir, Type_Info{variant = Type_Builtin{kind = kind}})
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

ir_add_enum :: proc(ir: ^IR, decl: Enum_Decl) -> Decl_Handle {
	append(&ir.enums, decl)
	handle := Decl_Handle(len(ir.enums) - 1)
	append(&ir.order, Decl_Ref{kind = .Enum, index = u32(handle)})
	return handle
}

ir_add_typedef :: proc(ir: ^IR, decl: Typedef_Decl) -> Decl_Handle {
	append(&ir.typedefs, decl)
	handle := Decl_Handle(len(ir.typedefs) - 1)
	append(&ir.order, Decl_Ref{kind = .Typedef, index = u32(handle)})
	return handle
}

ir_add_var :: proc(ir: ^IR, decl: Var_Decl) {
	append(&ir.vars, decl)
	append(&ir.order, Decl_Ref{kind = .Var, index = u32(len(ir.vars) - 1)})
}

ir_add_macro :: proc(ir: ^IR, decl: Macro_Decl) {
	append(&ir.macros, decl)
	append(&ir.order, Decl_Ref{kind = .Macro, index = u32(len(ir.macros) - 1)})
}
