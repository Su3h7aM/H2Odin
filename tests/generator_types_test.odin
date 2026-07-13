package h2odin_e2e

import "core:os"
import "core:testing"

@(test)
test_opaque_tags_abi_default_faithful :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_contains(t, stdout, "take_tag :: proc(t: ^Opaque_Tag")
	expect_contains(t, stdout, "out: ^^Opaque_Tag")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
}
@(test)
test_opaque_tags_idiomatic_default_handle :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_idiomatic.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
	expect_contains(t, stdout, "take_tag :: proc(t: Opaque_Tag")
	expect_contains(t, stdout, "out: ^Opaque_Tag")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_not_contains(t, stdout, "^^Opaque_Tag")
}
@(test)
test_opaque_tags_abi_opt_in_handle :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_opt_in.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
	expect_contains(t, stdout, "take_tag :: proc(t: Opaque_Tag")
	expect_contains(t, stdout, "out: ^Opaque_Tag")
	expect_not_contains(t, stdout, "^^Opaque_Tag")

	out_dir := "/tmp/h2odin-opaque-tags"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-tags/generated.odin", stdout), nil)
	ok_src := `package opaque_tags

nil_ok :: proc() -> Opaque_Tag {
	return nil
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-tags/ok.odin", ok_src), nil)
	check_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	check_stdout, check_stderr, check_ok := run_h2odin(t, check_cmd[:])
	defer delete(check_stdout)
	defer delete(check_stderr)
	testing.expect(t, check_ok)
}

@(test)
test_opaque_tags_idiomatic_opt_out_faithful :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_opt_out.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_contains(t, stdout, "Opaque_Tag :: struct {}")
	expect_contains(t, stdout, "take_tag :: proc(t: ^Opaque_Tag")
	expect_contains(t, stdout, "out: ^^Opaque_Tag")
	expect_not_contains(t, stdout, "Opaque_Tag :: distinct rawptr")
}

@(test)
test_opaque_tags_complete_fails_closed :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_tags_complete.lua"}
	stdout, stderr, code, ok := run_h2odin_expect_failure(t, cmd[:])
	// Generator still emits (faithful), but error severity fails the run.
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}
	testing.expect(t, code != 0)

	expect_contains(t, stderr, "opaque_record_complete")
	expect_contains(t, stderr, "Complete_Tag")
	// Faithful emission retained for the complete record.
	expect_contains(t, stdout, "Complete_Tag :: struct")
	expect_contains(t, stdout, "c: ^Complete_Tag")
	expect_not_contains(t, stdout, "Complete_Tag :: distinct rawptr")
}

@(test)
test_opaque_handles_distinct_rawptr :: proc(t: ^testing.T) {
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/opaque_handles.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	// Incomplete-record handles are distinct automatically.
	expect_contains(t, stdout, "Opaque_A :: distinct rawptr")
	expect_contains(t, stdout, "Opaque_B :: distinct rawptr")
	// Shared record: first is distinct; second aliases the first.
	expect_contains(t, stdout, "Shared_Handle :: distinct rawptr")
	expect_contains(t, stdout, "Shared_Alias :: Shared_Handle")
	// types.distinct opts void* in; unlisted void* stays plain.
	expect_contains(t, stdout, "Void_Handle :: distinct rawptr")
	expect_contains(t, stdout, "Void_Plain :: rawptr")
	// Complete record pointer is still a pointer, not collapsed.
	expect_contains(t, stdout, "Complete_Ptr ::")
	expect_contains(t, stdout, "^Complete_Rec")
	// Direct struct pointers canonicalize to the equivalent public handle, so
	// the private implementation record is still unnecessary.
	expect_contains(t, stdout, "impl: Opaque_A")
	expect_not_contains(t, stdout, "Opaque_A_Impl")
	expect_not_contains(t, stdout, "Shared_Impl")

	out_dir := "/tmp/h2odin-opaque-handles"
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/generated.odin", stdout), nil)

	// Cross-assignment of distinct handles must fail; same-record aliases and
	// nil assignment must succeed (odin check of a companion file).
	check_src := `package opaque_handles

cross_assign :: proc(a: Opaque_A) -> Opaque_B {
	return a // should not type-check
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/cross.odin", check_src), nil)
	cross_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	_, cross_stderr, cross_code, cross_ok := run_h2odin_expect_failure(t, cross_cmd[:])
	defer delete(cross_stderr)
	if !cross_ok {
		return
	}
	testing.expect(t, cross_code != 0)

	// Positive check: aliases assign; nil works; no cross-file needed beyond generated.
	_ = os.remove("/tmp/h2odin-opaque-handles/cross.odin")
	ok_src := `package opaque_handles

shared_ok :: proc(s: Shared_Handle) -> Shared_Alias {
	return s
}

nil_ok :: proc() -> Opaque_A {
	return nil
}
`
	testing.expect_value(t, os.write_entire_file("/tmp/h2odin-opaque-handles/ok.odin", ok_src), nil)
	ok_cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	ok_stdout, ok_stderr, ok_ok := run_h2odin(t, ok_cmd[:])
	defer delete(ok_stdout)
	defer delete(ok_stderr)
	testing.expect(t, ok_ok)
}
