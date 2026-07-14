package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_foreign_function_signatures_distinguish_value_and_pointer_records :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	foreign_record := ir_create_record(&ir, Record_Decl{name = "Foreign_Value", is_foreign = true})
	foreign_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = foreign_record}})
	foreign_pointer_record := ir_create_record(&ir, Record_Decl{name = "Foreign_Pointer", is_foreign = true})
	foreign_pointer_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = foreign_pointer_record}})
	foreign_pointer_type := ir_add_type(&ir, Type_Info{variant = Type_Lowered_Pointer{pointee = foreign_pointer_record_type, kind = .Single}})
	ir_add_func(
		&ir,
		Func_Decl {
			name = "consume_foreign_value",
			return_type = foreign_record_type,
			params = {{name = "value", type = foreign_record_type}, {name = "pointer", type = foreign_pointer_type}},
		},
	)

	apply_foreign_types(&ir, &Policy{})

	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Unresolved_Type)
	testing.expect(t, strings.contains(ir.diagnostics[0].message, "used by value"))
}

@(test)
test_foreign_type_analysis_terminates_recursive_typedefs :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	foreign_record := ir_create_record(&ir, Record_Decl{name = "Foreign_Value", is_foreign = true})
	foreign_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = foreign_record}})
	recursive_typedef := ir_add_typedef(&ir, Typedef_Decl{name = "Recursive"})
	recursive_reference := ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = recursive_typedef}})
	recursive_proc_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Proc{return_type = foreign_record_type, params = {{name = "next", type = recursive_reference}}}},
	)
	ir.typedefs[recursive_typedef].aliased = recursive_proc_type

	uses := analyze_foreign_type_uses(&ir)

	testing.expect(t, uses.record_referenced[foreign_record])
	testing.expect(t, uses.record_by_value[foreign_record])
}

@(test)
test_foreign_type_analysis_ignores_decided_leaf_provenance :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	foreign_record := ir_create_record(&ir, Record_Decl{name = "Foreign_Value", is_foreign = true})
	foreign_record_type := ir_add_type(&ir, Type_Info{variant = Type_Record_Ref{decl = foreign_record}})
	decided_type := ir_add_type(
		&ir,
		Type_Info{variant = Type_Idiomatic_Leaf{original = foreign_record_type, spelling = "Configured_Value", reason = .Config_Override}},
	)
	ir_add_func(&ir, Func_Decl{name = "configured_value", return_type = decided_type})

	apply_foreign_types(&ir, &Policy{})

	testing.expect_value(t, len(ir.diagnostics), 0)
	for declaration in ir.order {
		testing.expect(t, declaration.kind != .Record)
	}
}

@(test)
test_foreign_enum_inherits_live_referrer_home :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)
	append(&ir.input_headers, "input.h")

	foreign_enum := ir_create_enum(&ir, Enum_Decl{name = "Foreign_Kind", is_foreign = true})
	foreign_enum_type := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = foreign_enum}})
	ir_add_func(&ir, Func_Decl{name = "foreign_kind", return_type = foreign_enum_type, home = 1})

	apply_foreign_types(&ir, &Policy{})

	testing.expect_value(t, ir.enums[foreign_enum].home, Input_Header_Handle(1))
	testing.expect_value(t, len(ir.diagnostics), 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Unresolved_Type)
	foreign_enum_is_emitted := false
	for declaration in ir.order {
		if declaration.kind == .Enum && declaration.index == u32(foreign_enum) {
			foreign_enum_is_emitted = true
			break
		}
	}
	testing.expect(t, foreign_enum_is_emitted)
}

@(test)
test_foreign_scalar_measurement_follows_full_typedef_chain :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)

	previous_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = previous_allocator

	ir: IR
	ir_init(&ir)

	measured_type := ir_add_type(&ir, Type_Info{variant = Type_Builtin{kind = .Long_Long, size = 8}})
	for _ in 0 ..< 40 {
		typedef := ir_add_typedef(&ir, Typedef_Decl{aliased = measured_type})
		measured_type = ir_add_type(&ir, Type_Info{variant = Type_Typedef_Ref{decl = typedef}})
	}

	testing.expect_value(t, type_measured_size(&ir, measured_type), 8)
}

@(test)
test_windows_compound_spelling_corpus_names :: proc(t: ^testing.T) {
	// Names core:sys/windows exports — used on Windows hosts for the
	// built-in foreign map. Pure function so Unix CI can still lock the list.
	cases := [?]struct {
		c_name:   string,
		spelling: string,
	} {
		{"sockaddr", "win32.sockaddr"},
		{"sockaddr_in", "win32.sockaddr_in"},
		{"sockaddr_in6", "win32.sockaddr_in6"},
		{"in_addr", "win32.in_addr"},
		{"in6_addr", "win32.in6_addr"},
		{"fd_set", "win32.fd_set"},
		{"timeval", "win32.timeval"},
		{"socklen_t", "win32.socklen_t"},
	}
	for c in cases {
		s, ok := windows_compound_spelling(c.c_name)
		testing.expectf(t, ok, "expected win32 spelling for %q", c.c_name)
		testing.expect_value(t, s, c.spelling)
	}
	_, absent := windows_compound_spelling("sockaddr_storage")
	testing.expect(t, !absent)
	_, pure_posix := windows_compound_spelling("pid_t")
	testing.expect(t, !pure_posix)
}

@(test)
test_note_imports_for_odin_expression_tracks_win32 :: proc(t: ^testing.T) {
	imports: Emit_Imports
	note_imports_for_odin_expression(&imports, "win32.sockaddr")
	testing.expect(t, imports.win32)
	testing.expect(t, !imports.posix)

	b: strings.Builder
	defer strings.builder_destroy(&b)
	emit_write_prelude(&b, Emit_Options{package_name = "pkg"}, imports, false)
	text := strings.to_string(b)
	testing.expect(t, strings.contains(text, `import win32 "core:sys/windows"`))
	testing.expect(t, !strings.contains(text, "core:sys/posix"))
}

@(test)
test_platform_foreign_spelling_unix_keeps_map_entry :: proc(t: ^testing.T) {
	// On this host (build-tagged), platform_foreign_spelling should return a
	// non-empty spelling for map entries that the host defines.
	entry, ok := foreign_type_entry("sockaddr")
	testing.expect(t, ok)
	s := platform_foreign_spelling(entry)
	testing.expect(t, s != "")
	// Unix CI: posix.sockaddr; Windows CI: win32.sockaddr.
	when ODIN_OS == .Windows {
		testing.expect_value(t, s, "win32.sockaddr")
	} else {
		testing.expect_value(t, s, "posix.sockaddr")
	}
}
