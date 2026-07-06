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

// Handle into the IR type pool. Slot 0 holds the invalid type, so a
// zero-valued handle means "no type" rather than silently naming a real one.
Type_Handle :: distinct u32

// The C builtin types the IR knows. Milestone 1 is builtins only; pointers,
// records, enums and typedefs widen this later.
Builtin_Kind :: enum {
	Invalid,
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
	builtin: Builtin_Kind,
}

Decl_Kind :: enum {
	Invalid,
	Func,
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
}

IR :: struct {
	types:    [dynamic]Type_Info,
	funcs:    [dynamic]Func_Decl,
	order:    [dynamic]Decl_Ref,

	// Interning table for the pre-seeded builtin types.
	builtins: [Builtin_Kind]Type_Handle,
}

// Pre-seed the type pool with every builtin so extraction can intern them by
// lookup. Slot 0 is the invalid type.
ir_init :: proc(ir: ^IR) {
	for kind in Builtin_Kind {
		append(&ir.types, Type_Info{builtin = kind})
		ir.builtins[kind] = Type_Handle(len(ir.types) - 1)
	}
}

ir_builtin_type :: proc(ir: ^IR, kind: Builtin_Kind) -> Type_Handle {
	return ir.builtins[kind]
}

ir_type :: proc(ir: ^IR, handle: Type_Handle) -> Type_Info {
	return ir.types[int(handle)]
}

ir_add_func :: proc(ir: ^IR, func: Func_Decl) {
	append(&ir.funcs, func)
	append(&ir.order, Decl_Ref{kind = .Func, index = u32(len(ir.funcs) - 1)})
}
