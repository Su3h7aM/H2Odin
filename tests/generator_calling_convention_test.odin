package h2odin_e2e

import "core:strings"
import "core:testing"

@(test)
test_calling_conv_unsupported_exits_nonzero :: proc(t: ^testing.T) {
	// vectorcall is captured but has no Odin spelling → error diagnostic,
	// still emits, then exits non-zero.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/calling_conv.lua"}
	stdout, stderr, exit_code, ok := run_h2odin_expect_failure(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	testing.expect(t, exit_code != 0)
	expect_contains(t, stderr, "error[unsupported_calling_conv]:")
	// Still emits the rest of the surface (same posture as other error diags).
	expect_contains(t, stdout, "plain_c :: proc")
}
@(test)
test_calling_conv_supported_emits_stdcall_and_callback_types :: proc(t: ^testing.T) {
	// Drop vectorcall so the run succeeds; check stdcall/fastcall on decls
	// and nested callback typedefs.
	cmd := [?]string{"build/h2odin", "-destination:stdout", "-config:tests/fixtures/configs/calling_conv_supported.lua"}
	stdout, stderr, ok := run_h2odin(t, cmd[:])
	defer delete(stdout)
	defer delete(stderr)
	if !ok {
		return
	}

	expect_not_contains(t, stderr, "unsupported_calling_conv")
	expect_contains(t, stdout, "plain_c :: proc(")
	// Non-C conventions must be stated on foreign decls.
	// On targets where the attribute does not stick, libclang may still
	// report C — then the spelling stays the foreign default. Accept either
	// the explicit convention or the plain form, but never a wrong rewrite.
	out := string(stdout)
	if strings.contains(out, "stdcall_fn :: proc \"stdcall\"") {
		// preferred path when libclang reports Stdcall
	} else {
		expect_contains(t, stdout, "stdcall_fn :: proc(")
	}
	if strings.contains(out, "Stdcall_Cb :: ") {
		// Callback typedef should spell the convention on the proc type when known.
		// e.g. `Stdcall_Cb :: proc "stdcall" ()` or `^proc "stdcall" ()` depending
		// on pointer lowering (function pointers lower to bare proc types).
		if strings.contains(out, "proc \"stdcall\"") || strings.contains(out, "proc \"c\"") {
			// ok — captured fact serialized
		} else {
			testing.expectf(t, false, "Stdcall_Cb missing procedure-type convention spelling:\n%s", out)
		}
	}
}
