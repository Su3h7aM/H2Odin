package h2odin

// The single source of truth for how C types are spelled in generated Odin.
//
// Emission reads spellings from here and nowhere else; it never decides them.
// Extraction asks here which standard typedef names are known. The structural
// decisions themselves (pointer lowering, future substitutions) stay in
// Transformation — this file is data, not policy.
//
// Every row was verified against core:c as shipped with the Odin compiler:
// a spelling that does not resolve in core:c would emit code that fails
// odin check.

// How one C type is written in Odin.
Type_Spelling :: struct {
	// The faithful ABI spelling via core:c ("c.int"). "" means the type has
	// no spelling at all (void), never an empty name.
	abi:                string,

	// A semantic preference for how idiomatic mode should spell this type
	// ("i32", or "uint" for size_t). This is rung 1 of the substitution
	// ladder in substitute_leaf_types: still verified against the size
	// libclang measured before use, never assumed. "" means the table has
	// no preference — idiomatic mode does not fall back to the ABI spelling
	// for that, it derives a fixed-width native spelling from the measured
	// size and signedness instead (rung 2).
	idiomatic:          string,

	// Documentation only — nothing branches on this. true means core:c
	// defines `idiomatic` as the same Odin type on every supported target,
	// so the rung-1 size check is guaranteed to pass; false means it can
	// vary and the check is doing real work. Either way the check runs.
	target_independent: bool,
}

// One spelling per builtin, each written exactly once. The enumerated array
// must cover every Builtin_Kind member, so adding a builtin without deciding
// its spelling does not compile — same guarantee the old exhaustive switch
// gave.
@(rodata)
builtin_spellings := [Builtin_Kind]Type_Spelling {
	// C void never appears as a parameter in the IR, and void returns are
	// handled by the caller omitting the result entirely.
	.Void          = {"", "", false},
	.Bool          = {"c.bool", "bool", true},
	// Plain char always prefers u8, regardless of which signedness libclang
	// measured on the target: Odin's own core:c hardcodes char as u8
	// ("assuming -funsigned-char", see core:c/c.odin), not the target's
	// true default. Deriving from the measured signedness instead would
	// pick i8 on the (common) targets where C's plain char is actually
	// signed, producing a type distinct from — and un-assignable to —
	// core:c.char, breaking interop with the rest of the Odin C-FFI ecosystem.
	.Char_Signed   = {"c.char", "u8", true},
	.Char_Unsigned = {"c.char", "u8", true},
	.S_Char        = {"c.schar", "i8", true},
	.U_Char        = {"c.uchar", "u8", true},
	.Short         = {"c.short", "i16", true},
	.U_Short       = {"c.ushort", "u16", true},
	.Int           = {"c.int", "i32", true},
	.U_Int         = {"c.uint", "u32", true},
	.Long          = {"c.long", "i64", false}, // i32 on Windows and 32-bit targets
	.U_Long        = {"c.ulong", "u64", false},
	.Long_Long     = {"c.longlong", "i64", true},
	.U_Long_Long   = {"c.ulonglong", "u64", true},
	.Float         = {"c.float", "f32", true},
	.Double        = {"c.double", "f64", true},
}

builtin_is_unsigned :: proc(kind: Builtin_Kind) -> bool {
	#partial switch kind {
	case .Bool, .Char_Unsigned, .U_Char, .U_Short, .U_Int, .U_Long, .U_Long_Long:
		return true
	}
	return false
}

builtin_is_integer :: proc(kind: Builtin_Kind) -> bool {
	switch kind {
	case .Char_Signed, .Char_Unsigned, .S_Char, .U_Char, .Short, .U_Short, .Int, .U_Int, .Long, .U_Long, .Long_Long, .U_Long_Long:
		return true
	case .Void, .Bool, .Float, .Double:
		return false
	}
	return false
}

builtin_kind_for_abi_spelling :: proc(spelling: string) -> (Builtin_Kind, bool) {
	// Both captured plain-char variants spell as core:c.char. The canonical
	// Odin C-FFI type is unsigned; never let enum metadata depend on table order.
	if spelling == "c.char" {
		return .Char_Unsigned, true
	}
	for mapping, kind_index in builtin_spellings {
		if mapping.abi == spelling {
			return Builtin_Kind(kind_index), true
		}
	}
	return {}, false
}

enum_backing_spelling_signedness :: proc(spelling: string) -> (unsigned: bool, ok: bool) {
	if builtin_kind, is_builtin := builtin_kind_for_abi_spelling(spelling); is_builtin {
		if !builtin_is_integer(builtin_kind) {
			return false, false
		}
		return builtin_is_unsigned(builtin_kind), true
	}
	switch spelling {
	case "i8", "i16", "i32", "i64", "int":
		return false, true
	case "u8", "u16", "u32", "u64", "uint", "uintptr":
		return true, true
	}
	return false, false
}

// A standard C typedef (stdint.h / stddef.h) that core:c spells under the
// same name, so the generated code can say c.uint32_t instead of re-declaring
// libc's typedef chain.
Std_Mapping :: struct {
	c_name:             string, // the typedef name as C headers spell it
	abi:                string,
	idiomatic:          string, // same rung-1-preference meaning as in Type_Spelling
	target_independent: bool, // documentation only, same meaning as in Type_Spelling
}

// A flat slice, not an enum-indexed array: this set is open-ended and grows
// one verified row at a time. c_name must be unique within the table.
@(rodata)
std_mappings := []Std_Mapping {
	{"size_t", "c.size_t", "uint", false},
	{"ssize_t", "c.ssize_t", "int", false},
	// No semantic preference: width and signedness both vary by target
	// (unsigned 16-bit on Windows, a signed 32-bit int on glibc), so
	// idiomatic mode derives the spelling from what libclang measures.
	{"wchar_t", "c.wchar_t", "", false},
	{"ptrdiff_t", "c.ptrdiff_t", "int", false},
	{"int8_t", "c.int8_t", "i8", true},
	{"int16_t", "c.int16_t", "i16", true},
	{"int32_t", "c.int32_t", "i32", true},
	{"int64_t", "c.int64_t", "i64", true},
	{"uint8_t", "c.uint8_t", "u8", true},
	{"uint16_t", "c.uint16_t", "u16", true},
	{"uint32_t", "c.uint32_t", "u32", true},
	{"uint64_t", "c.uint64_t", "u64", true},
	{"intptr_t", "c.intptr_t", "int", false},
	{"uintptr_t", "c.uintptr_t", "uintptr", false},
	{"intmax_t", "c.intmax_t", "i64", true},
	{"uintmax_t", "c.uintmax_t", "u64", true},
	{"int_least8_t", "c.int_least8_t", "i8", true},
	{"int_least16_t", "c.int_least16_t", "i16", true},
	{"int_least32_t", "c.int_least32_t", "i32", true},
	{"int_least64_t", "c.int_least64_t", "i64", true},
	{"uint_least8_t", "c.uint_least8_t", "u8", true},
	{"uint_least16_t", "c.uint_least16_t", "u16", true},
	{"uint_least32_t", "c.uint_least32_t", "u32", true},
	{"uint_least64_t", "c.uint_least64_t", "u64", true},
	// The fast families vary per architecture in core:c except at the 8- and
	// 64-bit ends, which are fixed on every branch; the 16- and 32-bit
	// entries carry no preference here, so idiomatic mode derives them.
	{"int_fast8_t", "c.int_fast8_t", "i8", true},
	{"int_fast16_t", "c.int_fast16_t", "", false},
	{"int_fast32_t", "c.int_fast32_t", "", false},
	{"int_fast64_t", "c.int_fast64_t", "i64", true},
	{"uint_fast8_t", "c.uint_fast8_t", "u8", true},
	{"uint_fast16_t", "c.uint_fast16_t", "", false},
	{"uint_fast32_t", "c.uint_fast32_t", "", false},
	{"uint_fast64_t", "c.uint_fast64_t", "u64", true},
}

// Pointer-lowering result spellings. These are mapping decisions (a C
// construct becomes an Odin type name), unlike the ^ / [^] sigils, which are
// just Odin syntax and stay inline in emission.
SPELLING_RAWPTR :: "rawptr"
SPELLING_DISTINCT_RAWPTR :: "distinct rawptr"
SPELLING_CSTRING :: "cstring"

// The size in bytes of an Odin type named in an idiomatic column, on the
// architecture h2odin itself is running as (which, absent a cross-target
// generation flag, is also the extraction target). Fixed-width spellings
// have a size known at compile time; "int"/"uint"/"uintptr" are register-
// width, so their size is asked of the Odin compiler building h2odin rather
// than hardcoded — on every real target that width matches size_t's, which
// is exactly the claim rung 1 needs verified, not assumed. -1 for anything
// else, meaning "cannot prove a substitution with this spelling".
odin_type_size :: proc(spelling: string) -> int {
	switch spelling {
	case "bool", "i8", "u8":
		return 1
	case "i16", "u16":
		return 2
	case "i32", "u32", "f32":
		return 4
	case "i64", "u64", "f64":
		return 8
	case "int", "uint":
		return size_of(int)
	case "uintptr":
		return size_of(uintptr)
	}
	return -1
}

// Alignment companion to odin_type_size, used when a transformed ordinary
// field sits beside a measured C bit-field region.
odin_type_alignment :: proc(spelling: string) -> int {
	switch spelling {
	case "bool":
		return align_of(bool)
	case "i8":
		return align_of(i8)
	case "u8":
		return align_of(u8)
	case "i16":
		return align_of(i16)
	case "u16":
		return align_of(u16)
	case "i32":
		return align_of(i32)
	case "u32":
		return align_of(u32)
	case "f32":
		return align_of(f32)
	case "i64":
		return align_of(i64)
	case "u64":
		return align_of(u64)
	case "f64":
		return align_of(f64)
	case "int":
		return align_of(int)
	case "uint":
		return align_of(uint)
	case "uintptr":
		return align_of(uintptr)
	}
	return -1
}

std_mapping_for :: proc(name: string) -> (Std_Mapping, bool) {
	for mapping in std_mappings {
		if mapping.c_name == name {
			return mapping, true
		}
	}
	return {}, false
}

is_std_c_type :: proc(name: string) -> bool {
	_, found := std_mapping_for(name)
	return found
}
