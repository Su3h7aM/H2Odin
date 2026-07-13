package h2odin_e2e

import "core:testing"

@(test)
test_by_ptr_idiomatic_param :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/by_ptr.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	expect_contains(t, stdout, "create :: proc(#by_ptr options: Options)")
	// Unconfigured bare pointer stays ^T.
	expect_contains(t, stdout, "bare :: proc(p: ^")
	expect_not_contains(t, stdout, "#by_ptr p:")
	check_generated_output(t, stdout, "/tmp/h2odin-by-ptr")
}
@(test)
test_require_results_block_attr :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/require_results.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	// Sole configured proc → block-level attribute, not per-proc.
	expect_contains(t, stdout, "@(require_results)")
	expect_contains(t, stdout, "foreign lib {")
	expect_contains(t, stdout, "add :: proc")
	expect_not_contains(t, stdout, "\t@(require_results)\n")
	check_generated_output(t, stdout, "/tmp/h2odin-require-results")
}
@(test)
test_wrappers_out_param_and_slice :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/wrappers.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	// Faithful foreign under internal names.
	expect_contains(t, stdout, "foreign lib {")
	expect_contains(t, stdout, "_parse :: proc")
	expect_contains(t, stdout, "_consume :: proc")
	// Public out-param wrapper: multi-result, minimal body.
	expect_contains(t, stdout, "parse :: proc(")
	expect_contains(t, stdout, "out_data: ^Data")
	expect_contains(t, stdout, "res: Result")
	expect_contains(t, stdout, "res = _parse(")
	expect_contains(t, stdout, "&out_data")
	// Slice wrapper: raw_data + len cast, no runtime assert helper.
	expect_contains(t, stdout, "consume :: proc(items: []")
	expect_contains(t, stdout, "raw_data(items)")
	expect_contains(t, stdout, "len(items)")
	expect_not_contains(t, stdout, "assert(")
	expect_not_contains(t, stdout, "checked_len")
	check_generated_output(t, stdout, "/tmp/h2odin-wrappers")
}

@(test)
test_wrappers_rejected_in_abi_mode :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/wrappers_abi_reject.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, exit_code != 0)
	expect_contains(t, stderr, "procs.wrappers requires type_mode")
}

@(test)
test_array_param_and_configured_multi_pointer :: proc(t: ^testing.T) {
	// Array-form params → [^]T (proven); bare T* with pointer="multi" → [^]T.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/array_param.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "fill_buf :: proc(buf: [^]c.int")
	expect_contains(t, stdout, "flex :: proc(items: [^]c.int")
	expect_contains(t, stdout, "bare :: proc(p: [^]c.int")
	// No guessed diagnostic for array-decay or configured multi.
	expect_not_contains(t, stderr, "fill_buf")
	expect_not_contains(t, stderr, "pointer_lowering_guess")
	check_generated_output(t, stdout, "/tmp/h2odin-array-param")
}
