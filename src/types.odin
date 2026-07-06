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

	// The fixed-width Odin spelling idiomatic mode will use ("i32").
	// "" means no idiomatic form has been decided. Nothing reads this yet.
	idiomatic:          string,

	// true  — core:c defines this name as the same Odin type on every
	//         supported target, so the idiomatic substitution is safe by
	//         construction and needs no verification.
	// false — the width varies with the target. The substitution must be
	//         proven per-target (measured size against the Odin type's
	//         size) before use, never assumed. This flag must never become
	//         the thing that *decides* a substitution for a target-varying
	//         type; it only says whether verification is required.
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
	.Void        = {"", "", false},
	.Bool        = {"c.bool", "bool", true},
	// Plain char's signedness is implementation-defined; no idiomatic form
	// until a policy decides how to read it.
	.Char        = {"c.char", "", false},
	.S_Char      = {"c.schar", "i8", true},
	.U_Char      = {"c.uchar", "u8", true},
	.Short       = {"c.short", "i16", true},
	.U_Short     = {"c.ushort", "u16", true},
	.Int         = {"c.int", "i32", true},
	.U_Int       = {"c.uint", "u32", true},
	.Long        = {"c.long", "i64", false}, // i32 on Windows and 32-bit targets
	.U_Long      = {"c.ulong", "u64", false},
	.Long_Long   = {"c.longlong", "i64", true},
	.U_Long_Long = {"c.ulonglong", "u64", true},
	.Float       = {"c.float", "f32", true},
	.Double      = {"c.double", "f64", true},
}

// A standard C typedef (stdint.h / stddef.h) that core:c spells under the
// same name, so the generated code can say c.uint32_t instead of re-declaring
// libc's typedef chain.
Std_Mapping :: struct {
	c_name:             string, // the typedef name as C headers spell it
	abi:                string,
	idiomatic:          string,
	target_independent: bool, // same meaning as in Type_Spelling
}

// A flat slice, not an enum-indexed array: this set is open-ended and grows
// one verified row at a time. c_name must be unique within the table.
@(rodata)
std_mappings := []Std_Mapping {
	{"size_t", "c.size_t", "uint", false},
	{"ssize_t", "c.ssize_t", "int", false},
	{"wchar_t", "c.wchar_t", "", false}, // u16 on Windows, u32 elsewhere
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
	// 64-bit ends, which are fixed on every branch.
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
SPELLING_CSTRING :: "cstring"

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
