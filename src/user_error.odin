package h2odin

import "core:fmt"

// Under `odin test`, the !ODIN_TEST branches below are compiled out and
// `fmt` would look unused to -vet. Keep the import for those builds.
when ODIN_TEST {
	_ :: fmt
}

// CLI-facing messages to stderr.
//
// Silent when compiling with `odin test` (ODIN_TEST): unit tests call the
// library in-process and assert on return values; spamming the test console
// is noise. The real binary (`odin build` → build/h2odin) still prints —
// e2e captures that stderr via process_exec and checks it with expect_contains.

user_error :: proc(msg: string) {
	when !ODIN_TEST {
		fmt.eprintln(msg)
	}
}

user_errorf :: proc(format: string, args: ..any) {
	when !ODIN_TEST {
		fmt.eprintfln(format, ..args)
	}
}
