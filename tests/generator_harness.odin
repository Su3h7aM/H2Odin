package h2odin_e2e

import "core:os"
import "core:strings"
import "core:sync"
import "core:testing"

// os.process_start (used by process_exec) is not thread-safe. The e2e suite
// runs multi-threaded and every test spawns build/h2odin; serialize only the
// spawn/capture so the rest of each test stays free to run in parallel.
process_mu: sync.Mutex

run_process :: proc(command: []string) -> (state: os.Process_State, stdout: []byte, stderr: []byte, err: os.Error) {
	sync.mutex_lock(&process_mu)
	defer sync.mutex_unlock(&process_mu)
	return os.process_exec(os.Process_Desc{command = command}, context.allocator)
}

run_h2odin :: proc(t: ^testing.T, command: []string) -> ([]byte, []byte, bool) {
	state, stdout, stderr, err := run_process(command)
	if err != nil {
		testing.expectf(t, false, "process_exec failed: %v", err)
		return stdout, stderr, false
	}
	if !state.success || state.exit_code != 0 {
		testing.expectf(t, false, "command failed with exit %d\nstderr:\n%s", state.exit_code, string(stderr))
		return stdout, stderr, false
	}
	return stdout, stderr, true
}

run_h2odin_expect_failure :: proc(t: ^testing.T, command: []string) -> ([]byte, []byte, int, bool) {
	state, stdout, stderr, err := run_process(command)
	if err != nil {
		testing.expectf(t, false, "process_exec failed: %v", err)
		return stdout, stderr, 0, false
	}
	if state.success && state.exit_code == 0 {
		testing.expectf(t, false, "command unexpectedly succeeded\nstdout:\n%s", string(stdout))
		return stdout, stderr, state.exit_code, false
	}
	return stdout, stderr, state.exit_code, true
}

expect_contains :: proc(t: ^testing.T, haystack: []byte, needle: string) {
	testing.expectf(t, strings.contains(string(haystack), needle), "expected output to contain %q", needle)
}

expect_not_contains :: proc(t: ^testing.T, haystack: []byte, needle: string) {
	testing.expectf(t, !strings.contains(string(haystack), needle), "expected output not to contain %q", needle)
}

// Generate a project fixture (tests/fixtures/configs/<name>/H2Odin.lua) to
// stdout. Caller owns the returned bytes.
generate_fixture :: proc(t: ^testing.T, name: string) -> (stdout: []byte, ok: bool) {
	cwd, cwd_err := os.get_working_directory(context.allocator)
	testing.expect(t, cwd_err == nil)
	defer delete(cwd)
	proj := strings.concatenate({cwd, "/tests/fixtures/configs/", name})
	defer delete(proj)

	cmd := [?]string{"build/h2odin", "-destination:stdout", proj}
	out, stderr, run_ok := run_h2odin(t, cmd[:])
	defer delete(stderr)
	if !run_ok {
		delete(out)
		return nil, false
	}
	return out, true
}

// Generated bindings must compile: `odin check` the emitted package.
check_generated_output :: proc(t: ^testing.T, content: []byte, out_dir: string) {
	_ = os.remove_all(out_dir)
	testing.expect_value(t, os.make_directory_all(out_dir), nil)
	path := strings.concatenate({out_dir, "/generated.odin"})
	defer delete(path)
	testing.expect_value(t, os.write_entire_file(path, content), nil)

	cmd := [?]string{"odin", "check", out_dir, "-no-entry-point"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	testing.expect(t, ok)
}

// Cross-target check of an already-written package directory (no rewrite).
check_generated_output_target :: proc(t: ^testing.T, out_dir: string, target: string) {
	flag := strings.concatenate({"-target:", target})
	defer delete(flag)
	cmd := [?]string{"odin", "check", out_dir, "-no-entry-point", flag}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	testing.expectf(t, ok, "odin check -target:%s failed", target)
}
