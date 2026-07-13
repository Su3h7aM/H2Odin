package h2odin

import "core:testing"

@(test)
test_odin_type_size_fixed_width :: proc(t: ^testing.T) {
	testing.expect_value(t, odin_type_size("bool"), 1)
	testing.expect_value(t, odin_type_size("i8"), 1)
	testing.expect_value(t, odin_type_size("u16"), 2)
	testing.expect_value(t, odin_type_size("i32"), 4)
	testing.expect_value(t, odin_type_size("f32"), 4)
	testing.expect_value(t, odin_type_size("u64"), 8)
	testing.expect_value(t, odin_type_size("f64"), 8)
}

@(test)
test_odin_type_size_register_width_spellings :: proc(t: ^testing.T) {
	testing.expect_value(t, odin_type_size("int"), size_of(int))
	testing.expect_value(t, odin_type_size("uint"), size_of(uint))
	testing.expect_value(t, odin_type_size("uintptr"), size_of(uintptr))
	testing.expect_value(t, odin_type_size("not_a_type"), -1)
}

@(test)
test_std_mappings_are_lookup_source :: proc(t: ^testing.T) {
	mapping, ok := std_mapping_for("uint32_t")
	testing.expect(t, ok)
	testing.expect_value(t, mapping.abi, "c.uint32_t")
	testing.expect_value(t, mapping.idiomatic, "u32")
	testing.expect(t, mapping.target_independent)

	size_mapping, size_ok := std_mapping_for("size_t")
	testing.expect(t, size_ok)
	testing.expect_value(t, size_mapping.abi, "c.size_t")
	testing.expect_value(t, size_mapping.idiomatic, "uint")
	testing.expect(t, !size_mapping.target_independent)

	testing.expect(t, is_std_c_type("uint64_t"))
	testing.expect(t, !is_std_c_type("__uint64_t"))
}

@(test)
test_c_char_spelling_uses_canonical_unsigned_kind :: proc(t: ^testing.T) {
	kind, found := builtin_kind_for_abi_spelling("c.char")
	testing.expect(t, found)
	testing.expect_value(t, kind, Builtin_Kind.Char_Unsigned)
	unsigned, valid_backing := enum_backing_spelling_signedness("c.char")
	testing.expect(t, valid_backing)
	testing.expect(t, unsigned)
}
