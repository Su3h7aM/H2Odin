package h2odin

import vmem "core:mem/virtual"
import "core:strings"
import "core:testing"

@(test)
test_keyword_safe_default_suffixes_keywords :: proc(t: ^testing.T) {
	testing.expect_value(t, keyword_safe_default("ordinary"), "ordinary")

	name := keyword_safe_default("matrix")
	defer delete(name)
	testing.expect_value(t, name, "matrix_")
}

@(test)
test_strip_configured_affixes_by_symbol_kind :: proc(t: ^testing.T) {
	policy := Policy {
		strip_prefix_proc  = {"gl_"},
		strip_prefix_type  = {"GL"},
		strip_prefix_const = {"GL_"},
		strip_suffix_type  = {"_t"},
	}

	testing.expect_value(t, strip_configured_affixes(&policy, "gl_Draw", .Func), "Draw")
	testing.expect_value(t, strip_configured_affixes(&policy, "GLVector", .Type), "Vector")
	testing.expect_value(t, strip_configured_affixes(&policy, "GL_MAX", .Const), "MAX")
	testing.expect_value(t, strip_configured_affixes(&policy, "gl_field", .Field), "gl_field")
	testing.expect_value(t, strip_configured_affixes(&policy, "gl_", .Func), "gl_")
	testing.expect_value(t, strip_configured_affixes(&policy, "size_t", .Type), "size")
}

@(test)
test_rename_of_escapes_keywords_from_absolute_overrides :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	// An absolute override that happens to land on an Odin keyword must still
	// emit valid syntax — keyword safety is a generator invariant, not a
	// naming preference, so it gates every emitted name.
	policy := Policy{}
	policy.naming_overrides = make(map[string]string)
	policy.naming_overrides["context"] = "context"

	name, decided := rename_of(&ir, &policy, "context", .Field, "CursorAndRangeVisitor")
	testing.expect(t, decided)
	testing.expect_value(t, name, "context_")
}

@(test)
test_rename_of_escapes_keywords_from_generator_default :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)

	// No override callback, no absolute map: the default path must escape too.
	policy := Policy{}
	name, decided := rename_of(&ir, &policy, "map", .Field, "")
	testing.expect(t, decided)
	testing.expect_value(t, name, "map_")
}

@(test)
test_apply_renames_renames_params_via_override_map :: proc(t: ^testing.T) {
	// libclang names parameters after their type (CXCursor Cursor); once the
	// type is recased to Cursor the param shadows it. Parameters must be
	// renamable through the same naming pipeline as fields.
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_ty := ir_builtin_type(&ir, .Int)
	ir_add_func(&ir, Func_Decl{name = "clang_getModuleParent", return_type = int_ty, params = {{name = "Module", type = int_ty}}})

	policy := Policy{}
	policy.naming_overrides = make(map[string]string)
	policy.naming_overrides["Module"] = "module"

	apply_renames(&ir, &policy)

	testing.expect_value(t, ir.funcs[0].name, "clang_getModuleParent")
	testing.expect_value(t, ir.funcs[0].params[0].name, "module")
}

@(test)
test_apply_renames_escapes_keyword_param :: proc(t: ^testing.T) {
	// A parameter named with an Odin keyword must still emit valid syntax —
	// keyword safety gates params, same as every other emitted name.
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_ty := ir_builtin_type(&ir, .Int)
	ir_add_func(&ir, Func_Decl{name = "f", return_type = int_ty, params = {{name = "context", type = int_ty}}})

	apply_renames(&ir, &Policy{})

	testing.expect_value(t, ir.funcs[0].params[0].name, "context_")
}

@(test)
test_link_name_for_respects_link_prefix :: proc(t: ^testing.T) {
	policy := Policy {
		foreign_link_prefix = "sqlite3_",
	}
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open"), "")
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open_v2"), "sqlite3_open")
	policy.foreign_link_prefix = ""
	testing.expect_value(t, link_name_for(&policy, "sqlite3_open", "open"), "sqlite3_open")
}

@(test)
test_macro_group_and_bit_set_inherit_home :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	_ = ir_register_input_headers(&ir, {"a.h", "b.h"})
	// Two macros in different homes; first matched (pool order) is home_a.
	ir_add_macro(&ir, Macro_Decl{name = "FLG_A", tokens = {{spelling = "1", kind = .Literal}}, home = 1})
	ir_add_macro(&ir, Macro_Decl{name = "FLG_B", tokens = {{spelling = "2", kind = .Literal}}, home = 2})
	// Backing enum for bit_set lives in header b. Seed a measured size so
	// the bit_set transform has a proven width.
	int_ty := ir_builtin_type(&ir, .Int)
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = int_ty, members = {{name = "One", value = 1}, {name = "Two", value = 2}}, home = 2})

	policy := Policy {
		macro_groups  = {{name = "Flg", prefix = "FLG_"}},
		enum_bit_sets = {{enum_name = "Flag", name = "Flag_Set", mode = "log2"}},
	}
	apply_macro_groups(&ir, &policy)
	apply_enum_bit_sets(&ir, &policy)

	found_enum := false
	for e in ir.enums {
		if e.name == "Flg" {
			found_enum = true
			testing.expect_value(t, e.home, Input_Header_Handle(1))
		}
	}
	testing.expect(t, found_enum)

	found_bs := false
	for bs in ir.bit_sets {
		if bs.name == "Flag_Set" {
			found_bs = true
			testing.expect_value(t, bs.home, Input_Header_Handle(2))
			testing.expect_value(t, bs.backing_bits, 32)
		}
	}
	testing.expect(t, found_bs)
}

@(test)
test_bit_set_records_measured_backing_width :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_ty := ir_builtin_type(&ir, .Int)
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	_ = ir_add_enum(
		&ir,
		Enum_Decl {
			name = "Config_Flag",
			backing = int_ty,
			members = {{name = "VSYNC", value = 1}, {name = "FULLSCREEN", value = 2}, {name = "MSAA", value = 4}},
		},
	)

	policy := Policy {
		enum_bit_sets = {{enum_name = "Config_Flag", name = "Config_Flags", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 1)
	if len(ir.bit_sets) == 1 {
		testing.expect_value(t, ir.bit_sets[0].backing_bits, 32)
		// The Odin size of the explicit backing must
		// match the measured C enum size (4 bytes for int).
		testing.expect_value(t, odin_type_size(bit_set_backing_spelling(ir.bit_sets[0].backing_bits)), 4)
	}
	// Members rewritten to bit positions.
	for e in ir.enums {
		if e.name == "Config_Flag" {
			testing.expect_value(t, e.members[0].value, i64(0))
			testing.expect_value(t, e.members[1].value, i64(1))
			testing.expect_value(t, e.members[2].value, i64(2))
		}
	}
}

@(test)
test_bit_set_skips_when_flag_exceeds_backing_width :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// 1-byte backing cannot hold bit position 8 (value 256).
	u8_ty := ir_builtin_type(&ir, .U_Char)
	ir.types[int(u8_ty)].variant = Type_Builtin {
		kind = .U_Char,
		size = 1,
	}
	_ = ir_add_enum(&ir, Enum_Decl{name = "Wide_Flag", backing = u8_ty, members = {{name = "Low", value = 1}, {name = "High", value = 256}}})

	policy := Policy {
		enum_bit_sets = {{enum_name = "Wide_Flag", name = "Wide_Flags", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	// Members must stay as C masks when the rewrite is skipped.
	testing.expect_value(t, ir.enums[0].members[1].value, i64(256))
	found_diag := false
	for d in ir.diagnostics {
		if d.category == .Bit_Set_Backing_Mismatch {
			found_diag = true
		}
	}
	testing.expect(t, found_diag)
}

@(test)
test_bit_set_skips_when_backing_size_unknown :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	// Pre-seeded builtins start at size -1; do not fill.
	_ = ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = ir_builtin_type(&ir, .Int), members = {{name = "One", value = 1}}})

	policy := Policy {
		enum_bit_sets = {{enum_name = "Flag", name = "Flag_Set", mode = "log2"}},
	}
	apply_enum_bit_sets(&ir, &policy)

	testing.expect_value(t, len(ir.bit_sets), 0)
	found_diag := false
	for d in ir.diagnostics {
		if d.category == .Bit_Set_Backing_Mismatch {
			found_diag = true
		}
	}
	testing.expect(t, found_diag)
}

@(test)
test_emit_bit_set_writes_explicit_backing :: proc(t: ^testing.T) {
	arena: vmem.Arena
	err := vmem.arena_init_growing(&arena)
	testing.expect_value(t, err, nil)
	defer vmem.arena_destroy(&arena)

	old_allocator := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old_allocator

	ir: IR
	ir_init(&ir)
	int_ty := ir_builtin_type(&ir, .Int)
	ir.types[int(int_ty)].variant = Type_Builtin {
		kind = .Int,
		size = 4,
	}
	enum_handle := ir_add_enum(&ir, Enum_Decl{name = "Flag", backing = int_ty, members = {{name = "One", value = 0}}})
	elem := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enum_handle}})
	decl := Bit_Set_Decl {
		name         = "Flags",
		elem         = elem,
		backing_bits = 32,
	}

	b: strings.Builder
	strings.builder_init(&b)
	imports: Emit_Imports
	emit_bit_set(&b, &ir, decl, false, &imports)
	out := strings.to_string(b)
	testing.expect(t, strings.contains(out, "Flags :: bit_set[Flag; u32]"))
}

@(test)
test_validate_package_scope_collision :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	ir_add_func(&ir, Func_Decl{name = "Open"})
	ir_add_func(&ir, Func_Decl{name = "Open"})
	validate_symbol_names(&ir)
	testing.expect(t, len(ir.diagnostics) >= 1)
	testing.expect_value(t, ir.diagnostics[0].category, Diag_Category.Symbol_Collision)
}

@(test)
test_validate_field_shadow_with_second_type_use :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	enm := ir_add_enum(&ir, Enum_Decl{name = "format"})
	enm_ty := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enm}})
	fields := make([]Field, 2)
	fields[0] = Field {
		name = "format",
		type = enm_ty,
	}
	fields[1] = Field {
		name = "internalFormat",
		type = enm_ty,
	}
	ir_add_record(&ir, Record_Decl{name = "device", fields = fields, is_complete = true})
	validate_symbol_names(&ir)
	found := false
	for d in ir.diagnostics {
		if d.category == .Symbol_Collision && strings.contains(d.message, "shadows type") {
			found = true
		}
	}
	testing.expect(t, found)
}

@(test)
test_validate_alone_self_annotation_is_ok :: proc(t: ^testing.T) {
	arena: vmem.Arena
	testing.expect_value(t, vmem.arena_init_growing(&arena), nil)
	defer vmem.arena_destroy(&arena)
	old := context.allocator
	context.allocator = vmem.arena_allocator(&arena)
	defer context.allocator = old

	ir: IR
	ir_init(&ir)
	enm := ir_add_enum(&ir, Enum_Decl{name = "format"})
	enm_ty := ir_add_type(&ir, Type_Info{variant = Type_Enum_Ref{decl = enm}})
	fields := make([]Field, 1)
	fields[0] = Field {
		name = "format",
		type = enm_ty,
	}
	ir_add_record(&ir, Record_Decl{name = "S", fields = fields, is_complete = true})
	validate_symbol_names(&ir)
	for d in ir.diagnostics {
		testing.expect(t, d.category != .Symbol_Collision)
	}
}
