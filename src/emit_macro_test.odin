package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_emit_macro_preserves_c_integer_values :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	test_cases := []struct {
		name:     string,
		literal:  string,
		expected: string,
	} {
		{"Octal_Mode", "010", "Octal_Mode :: 0o10\n"},
		{"Unsigned_Count", "42U", "Unsigned_Count :: 42\n"},
		{"Long_Mask", "0x7fLL", "Long_Mask :: 0x7f\n"},
		{"Maximum_U64", "0xFFFFFFFFFFFFFFFFULL", "Maximum_U64 :: 0xFFFFFFFFFFFFFFFF\n"},
	}

	for test_case in test_cases {
		builder: strings.Builder
		declaration := Macro_Decl {
			name   = test_case.name,
			tokens = {{spelling = test_case.literal, kind = .Literal}},
		}
		emit_macro(&builder, declaration, false)
		testing.expect_value(t, strings.to_string(builder), test_case.expected)
	}
}
