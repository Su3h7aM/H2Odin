package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_write_enum_body_omits_default_sequential_values :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	backing := ir_builtin_type(&ir, .U_Int)
	decl := Enum_Decl {
		name    = "Kind",
		backing = backing,
		members = {{name = "None", value = 0}, {name = "A", value = 1}, {name = "B", value = 2}},
	}

	b: strings.Builder
	uses_core_c := false
	write_enum_body(&b, &ir, decl, 0, false, &uses_core_c)
	text := strings.to_string(b)

	testing.expect(t, strings.contains(text, "None,\n"))
	testing.expect(t, strings.contains(text, "A,\n"))
	testing.expect(t, strings.contains(text, "B,\n"))
	testing.expect(t, !strings.contains(text, "None ="))
	testing.expect(t, !strings.contains(text, "A ="))
	testing.expect(t, !strings.contains(text, "B ="))
}

@(test)
test_write_enum_body_emits_gaps_and_non_zero_start :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	backing := ir_builtin_type(&ir, .Int)
	// Non-zero start + gap after remove-style hole (0 then 2).
	decl := Enum_Decl {
		name    = "Code",
		backing = backing,
		members = {
			{name = "First", value = 1},
			{name = "Second", value = 2},
			{name = "Hundred", value = 100},
			{name = "Zero", value = 0},
			{name = "One_Again", value = 1},
		},
	}

	b: strings.Builder
	uses_core_c := false
	write_enum_body(&b, &ir, decl, 0, false, &uses_core_c)
	text := strings.to_string(b)

	// 1 ≠ expected 0 → explicit; next expected 2 so Second omits; 100 explicit;
	// Zero=0 restarts the sequence so One_Again (1) omits again.
	testing.expect(t, strings.contains(text, "First = 1"))
	testing.expect(t, strings.contains(text, "Second,\n") || strings.contains(text, "\tSecond,\n"))
	testing.expect(t, !strings.contains(text, "Second ="))
	testing.expect(t, strings.contains(text, "Hundred = 100"))
	testing.expect(t, strings.contains(text, "Zero = 0"))
	testing.expect(t, strings.contains(text, "One_Again,\n") || strings.contains(text, "\tOne_Again,\n"))
	testing.expect(t, !strings.contains(text, "One_Again ="))
}

@(test)
test_write_enum_body_gap_after_sequential_prefix :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	backing := ir_builtin_type(&ir, .Int)
	// Like Result_Code: OK=0, ERR=1, ROW=100
	decl := Enum_Decl {
		name    = "Result_Code",
		backing = backing,
		members = {{name = "OK", value = 0}, {name = "ERR", value = 1}, {name = "ROW", value = 100}},
	}

	b: strings.Builder
	uses_core_c := false
	write_enum_body(&b, &ir, decl, 0, false, &uses_core_c)
	text := strings.to_string(b)

	testing.expect(t, strings.contains(text, "OK,\n") || strings.contains(text, "\tOK,\n"))
	testing.expect(t, strings.contains(text, "ERR,\n") || strings.contains(text, "\tERR,\n"))
	testing.expect(t, !strings.contains(text, "OK ="))
	testing.expect(t, !strings.contains(text, "ERR ="))
	testing.expect(t, strings.contains(text, "ROW = 100"))
}
