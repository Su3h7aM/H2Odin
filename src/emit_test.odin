package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_emit_preserves_configured_declaration_layout :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	ir_add_func(&ir, Func_Decl{name = "before", return_type = void_type})
	_ = ir_add_record(&ir, Record_Decl{name = "Value", is_complete = true})
	ir_add_func(&ir, Func_Decl{name = "after", return_type = void_type})

	plan := Output_Plan {
		units = {{filename = "example.odin", stem = "example", decls = ir.order[:]}},
	}
	options := Emit_Options {
		package_name = "example",
		foreign_lib  = "example",
	}

	interleaved := emit(&ir, plan, options)
	testing.expect_value(
		t,
		interleaved.files[0].content,
		"package example\n\n" +
		"foreign import lib \"system:example\"\n\n" +
		"foreign lib {\n\tbefore :: proc() ---\n}\n" +
		"Value :: struct {}\n\n" +
		"foreign lib {\n\tafter :: proc() ---\n}\n",
	)

	options.procedures_at_end = true
	procedures_at_end := emit(&ir, plan, options)
	testing.expect_value(
		t,
		procedures_at_end.files[0].content,
		"package example\n\n" +
		"foreign import lib \"system:example\"\n\n" +
		"Value :: struct {}\n\n" +
		"foreign lib {\n\tbefore :: proc() ---\n\tafter :: proc() ---\n}\n",
	)
}

@(test)
test_emit_result_outlives_scratch_plan_and_body :: proc(t: ^testing.T) {
	generation_arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&generation_arena), nil)
	defer vmem.arena_destroy(&generation_arena)
	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&generation_arena)
	defer context.allocator = old_allocator

	result: Emit_Result
	{
		scratch_arena: vmem.Arena
		testing.expect_value(t, vmem.arena_init_growing(&scratch_arena), nil)
		defer vmem.arena_destroy(&scratch_arena)
		old_temp_allocator := context.temp_allocator
		context.temp_allocator = vmem.arena_allocator(&scratch_arena)
		defer context.temp_allocator = old_temp_allocator

		filename := strings.clone("example.odin", context.temp_allocator)
		stem := strings.clone("example", context.temp_allocator)
		plan := Output_Plan {
			units = {{filename = filename, stem = stem}},
		}
		result = emit(&IR{}, plan, Emit_Options{package_name = "example"})
	}

	testing.expect_value(t, result.files[0].filename, "example.odin")
	testing.expect_value(t, result.files[0].stem, "example")
	testing.expect_value(t, result.files[0].content, "package example\n\n")
}

@(test)
test_emit_imports_packages_used_by_explicit_function_results :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	ir_add_func(&ir, Func_Decl{name = "get_count", return_type = void_type, return_type_spelling = "^c.int"})
	ir_add_func(&ir, Func_Decl{name = "get_socket_length", return_type = void_type, return_type_spelling = "[^]posix.socklen_t"})
	ir_add_func(&ir, Func_Decl{name = "get_stream", return_type = void_type, return_type_spelling = "^libc.FILE"})
	ir_add_func(&ir, Func_Decl{name = "get_handle", return_type = void_type, return_type_spelling = "^[4]win32.HANDLE"})

	plan := Output_Plan {
		units = {{filename = "example.odin", stem = "example", decls = ir.order[:]}},
	}
	result := emit(&ir, plan, Emit_Options{package_name = "example", foreign_lib = "example"})
	content := result.files[0].content

	testing.expect(t, strings.contains(content, "import \"core:c\""))
	testing.expect(t, strings.contains(content, "import \"core:c/libc\""))
	testing.expect(t, strings.contains(content, "import \"core:sys/posix\""))
	testing.expect(t, strings.contains(content, "import win32 \"core:sys/windows\""))
}

@(test)
test_emit_does_not_import_packages_named_only_inside_type_metadata :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	void_type := ir_builtin_type(&ir, .Void)
	ir_add_func(
		&ir,
		Func_Decl {
			name = "get_value",
			return_type = void_type,
			return_type_spelling = "struct { longer: abc.int, chained: other.c.int, tagged: int `fmt:\"c.int libc.FILE posix.T win32.T\"` }",
		},
	)

	plan := Output_Plan {
		units = {{filename = "example.odin", stem = "example", decls = ir.order[:]}},
	}
	result := emit(&ir, plan, Emit_Options{package_name = "example", foreign_lib = "example"})
	content := result.files[0].content

	testing.expect(t, !strings.contains(content, "import \"core:c\""))
	testing.expect(t, !strings.contains(content, "import \"core:c/libc\""))
	testing.expect(t, !strings.contains(content, "import \"core:sys/posix\""))
	testing.expect(t, !strings.contains(content, "import win32 \"core:sys/windows\""))
}
