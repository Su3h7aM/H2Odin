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
test_odin_type_size_refuses_target_width_spellings :: proc(t: ^testing.T) {
	testing.expect_value(t, odin_type_size("int"), -1)
	testing.expect_value(t, odin_type_size("uint"), -1)
	testing.expect_value(t, odin_type_size("uintptr"), -1)
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
