package h2odin_e2e

import "core:testing"

@(test)
test_add_fixture_abi_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/add.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package add")
	expect_contains(t, stdout, "import \"core:c\"")
	expect_contains(t, stdout, "add :: proc(a: c.int, b: c.int) -> c.int ---")
}

@(test)
test_add_fixture_idiomatic_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/add_idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package add")
	expect_not_contains(t, stdout, "import \"core:c\"")
	expect_contains(t, stdout, "add :: proc(a: i32, b: i32) -> i32 ---")
}

@(test)
test_idiomatic_mode_defaults_to_native_leaf_types :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Rung 1: table preference, size-verified.
	expect_contains(t, stdout, "checksum :: proc(data: rawptr, nbytes: u64) -> u32 ---")
	expect_contains(t, stdout, "ticks :: proc() -> i64 ---")
	expect_contains(t, stdout, "uticks :: proc() -> u64 ---")
	// Rung 1 for both: size_t -> uint, and plain char -> u8 (matching
	// core:c.char, not the true per-target signedness).
	expect_contains(t, stdout, "payload_len :: proc(tag: u8) -> uint ---")
	// Enum backing types substitute through the same ladder.
	expect_contains(t, stdout, "Mode :: enum u32")
	expect_contains(t, stdout, "get_mode :: proc() -> Mode ---")
	// The ABI fallback (c.X) should not appear anywhere on the idiomatic
	// surface for this fixture — every leaf here is determinable, so
	// nothing pulls in core:c at all.
	expect_not_contains(t, stdout, "import \"core:c\"")
}

@(test)
test_basic_config_sets_package_foreign_lib_and_type_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/basic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "package mylib")
	expect_contains(t, stdout, "foreign import lib \"system:mylib_native\"")
	expect_contains(t, stdout, "add :: proc(a: i32, b: i32) -> i32 ---")
}

@(test)
test_keyword_safe_defaults_emit_link_name :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/keywords.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "@(link_name = \"matrix\")")
	expect_contains(t, stdout, "matrix_: [16]c.float")
	// C names are kept (foreign porting convention); keyword collisions get _.
	expect_contains(t, stdout, "map_ :: struct")
	expect_contains(t, stdout, "context_: c.int")
}

@(test)
test_declarative_config_applies_prefixes_and_type_map :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/declarative.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "MAX_POINTS :: 64")
	expect_contains(t, stdout, "@(link_name = \"gl_Distance\")")
	// types.overrides on a typedef emits a named alias; use sites keep the name.
	expect_contains(t, stdout, "Vector2 :: [2]f32")
	expect_contains(t, stdout, "Distance :: proc(a: Vector2, b: Vector2) -> c.int ---")
	expect_not_contains(t, stdout, "gl_Vector2 :: struct")
	expect_not_contains(t, stdout, "Vector2 :: struct")
}

@(test)
test_remove_where_filters_top_level_decls :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/keep.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "VERSION :: 3")
	expect_contains(t, stdout, "distance :: proc(a: Point, b: Point) -> c.int ---")
	expect_contains(t, stdout, "visible_count: c.int")
	expect_not_contains(t, stdout, "internal_BUILD")
	expect_not_contains(t, stdout, "internal_reset")
	expect_not_contains(t, stdout, "internal_count")
}

@(test)
test_diagnostics_report_lists_guessed_pointer_lowerings :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/pointers.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Bindings on stdout via -destination:stdout; the report is a single stderr block.
	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, "warning[pointer_lowering_guess]:")
	expect_contains(t, stderr, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
	expect_contains(t, stderr, `guessed pointer lowering in function "make_row" return type: defaulted to ^T`)
	// Proven lowerings (void*, const char*, function pointers) must not appear.
	expect_not_contains(t, stderr, `function "on_event"`)
	expect_not_contains(t, stderr, `function "log_fmt"`)
}

@(test)
test_diagnostics_report_lists_unknown_size_extern_arrays :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/extern_arrays.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "version:")
	expect_contains(t, stderr, "non-certain")
	expect_contains(t, stderr, "warning[incomplete_extern_array]:")
	expect_contains(t, stderr, `extern array "version" has unknown size; emitted as [0]T`)
	expect_contains(t, stderr, `extern array "values" has unknown size; emitted as [0]T`)
	// Known bounds are certain — no note for them.
	expect_not_contains(t, stderr, "known_values")
}

@(test)
test_quiet_suppresses_diagnostics_report :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/pointers.lua", "-quiet"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "fill :: proc")
	expect_not_contains(t, stderr, "non-certain")
	expect_not_contains(t, stderr, "pointer_lowering_guess")
}

@(test)
test_diagnostics_error_severity_exits_nonzero_after_emit :: proc(t: ^testing.T) {
	// pointer_lowering_guess = error still emits bindings, then fails the run.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/diag_pointer_error.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	expect_contains(t, stdout, "fill :: proc")
	expect_contains(t, stderr, "error[pointer_lowering_guess]:")
	expect_contains(t, stderr, `guessed pointer lowering in function "fill" parameter "out": defaulted to ^T`)
}

@(test)
test_bad_config_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bad_type_map.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `types.overrides["Foo"] must be a string`)
}

@(test)
test_unknown_config_key_fails_with_clear_message :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/unknown_key.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `unknown key "typo_mode"`)
}

@(test)
test_unsupported_config_key_fails_with_clear_message :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/unsupported_key.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, `"wrappers" is not yet supported`)
}

@(test)
test_macro_group_policy_synthesizes_enum :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/macro_groups.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Grouped integer macros become an enum; contiguous 0..n omit `= N`,
	// non-default values stay explicit. Originals dropped.
	expect_contains(t, stdout, "Result_Code :: enum")
	expect_contains(t, stdout, "OK")
	expect_contains(t, stdout, "ERR")
	expect_contains(t, stdout, "ROW = 100")
	expect_not_contains(t, stdout, "OK = 0")
	expect_not_contains(t, stdout, "ERR = 1")
	expect_not_contains(t, stdout, "LIB_OK ::")
	// Excluded prefix stays as standalone consts; non-integers are not enum members.
	expect_contains(t, stdout, "LIB_OPEN_RO ::")
	expect_contains(t, stdout, "LIB_TITLE ::")
}

@(test)
test_enum_policies_name_anonymous_enums_and_create_bit_sets :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/enum_policies.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Keyboard_Key :: enum")
	expect_contains(t, stdout, "NULL")
	// Sequential 0..n: no explicit values.
	expect_not_contains(t, stdout, "NULL = 0")
	// FLAG_COUNT removed by enums.member; remaining flags log2'd to 0,1,2.
	expect_contains(t, stdout, "Config_Flag :: enum")
	expect_contains(t, stdout, "VSYNC")
	expect_contains(t, stdout, "FULLSCREEN")
	expect_contains(t, stdout, "MSAA")
	expect_not_contains(t, stdout, "VSYNC = 0")
	expect_not_contains(t, stdout, "FULLSCREEN = 1")
	expect_not_contains(t, stdout, "MSAA = 2")
	expect_not_contains(t, stdout, "COUNT")
	expect_contains(t, stdout, "Config_Flags :: bit_set[Config_Flag; u32]")
}

@(test)
test_naming_overrides_and_symbol_removal_compose :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/naming_policies.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Widget ::")
	expect_contains(t, stdout, "size_t_like ::") // strip_suffixes type _t
	expect_contains(t, stdout, "@(link_name = \"lib_open\")")
	expect_contains(t, stdout, "open :: proc")
	expect_contains(t, stdout, "@(link_name = \"lib_special_do_thing\")")
	expect_contains(t, stdout, "do_thing :: proc")
	expect_not_contains(t, stdout, "lib_internal")
	expect_not_contains(t, stdout, "LIB_ITEM_COUNT")
	expect_contains(t, stdout, "LIB_OK ::")
}

@(test)
test_naming_callback_members_keep_original_parent_name :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/rename.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Colour :: enum")
	expect_contains(t, stdout, "Red")
	expect_contains(t, stdout, "Green")
	expect_contains(t, stdout, "Blue")
	expect_contains(t, stdout, `@(link_name = "paint")`)
	expect_contains(t, stdout, "lib_paint :: proc(color: Colour, opacity: c.int)")
	check_generated_output(t, stdout, "/tmp/h2odin-rename")
}

@(test)
test_parse_error_fails_without_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/bad_parse.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	testing.expect_value(t, len(stdout), 0)
	expect_contains(t, stderr, "did not parse cleanly")
}

@(test)
test_member_policies_and_link_prefix_shape_output :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/member_policies.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, `@(link_prefix = "rl_")`)
	// structs.fields: tag + type spelling
	expect_contains(t, stdout, "name: [32]c.char `fmt:\"s,0\"`")
	expect_contains(t, stdout, "parent: i32")
	// structs.align
	expect_contains(t, stdout, "Mesh :: struct #align(16)")
	// structs.field callback
	expect_contains(t, stdout, "vertexCount: c.int")
	// procs.params / results / param callback
	expect_contains(t, stdout, "SetConfigFlags :: proc(flags: ConfigFlags)")
	expect_contains(t, stdout, "GetKeyPressed :: proc() -> c.int")
	expect_contains(t, stdout, "DrawTexturePro :: proc(tint: Color = WHITE)")
}

@(test)
test_member_callback_type_replaces_declarative_pointer_shape :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/member_action_precedence.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "BorrowOrSpell :: proc(value: ^c.int)")
	expect_contains(t, stdout, "MultiOrSpell :: proc(values: [^]c.int)")
	expect_not_contains(t, stdout, "#by_ptr")
	expect_not_contains(t, stderr, "cannot combine with an explicit type spelling")
}
