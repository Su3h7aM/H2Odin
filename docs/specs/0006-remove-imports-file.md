# Spec 0006 — Remove `output.imports_file`

**Status:** accepted
**Date:** 2026-07-10

## Context

`output.imports_file` (Milestone 10) was meant to split generated output into
an `imports.odin` holding the plumbing — `package`, `import "core:c"`,
`foreign import lib` — and a main file holding only declarations. The
motivations were layout taste and a single hand-editable place for the
`foreign import` line.

The option is unsound by Odin's scoping rules, not by implementation
accident: `import` aliases and the `foreign import` lib name are
**file-scoped**. A main file whose body says `c.int` or opens
`foreign lib { ... }` cannot see declarations that live only in
`imports.odin` — and the body does one or both in essentially every real
binding. The produced output does not compile; the e2e test never noticed
because it asserts on file *text* without running `odin check`
(the missing regression called out in ROADMAP's Code health). Milestone 14
already rejects the option in `per_header` layout for the same reason.

## Decision

**Remove the option.** Reject `output.imports_file` by name with a migration
message, following the established legacy-key pattern. Delete the split
branch in emission and the text-level e2e assertions.

Alternatives considered:

- *Redesign as a foreign-block split* (the file holds the `foreign import`
  plus all foreign blocks; type files repeat their own `core:c` import).
  Compilable and coherent, but no longer an "imports file" — it is a procs
  file, overlapping `output.procedures_at_end` and `per_header`. Not worth
  an emission mode; can be reintroduced deliberately under an honest name if
  ever wanted.
- *Minimal patch* (duplicate `import "core:c"` into both files, keep the
  foreign import with its block). Leaves `imports.odin` holding a package
  line and an unreferenced import — decorative, discarded.

The second underlying desire — customizing the `foreign import` (static
libs, per-OS multi-lib stanzas) — needs a different mechanism that respects
file-scoping: config that *selects* per-OS libraries (e.g.
`foreign.import_lib = { linux = "system:clang", windows = {...} }`) while
the generator authors the `when ODIN_OS` stanza into every file that needs
it. That stays inside "config never authors output" and would also close the
Windows-parity gap (spec 0002, "Later"). Out of scope here; design it as its
own spec when taken up.

## Consequences

- No migration burden: the option's output never compiled, so no working
  config can depend on it.
- `Emit_Options.imports_file`, the split branch in `emit`, the policy field,
  and its validation/tests are deleted; `output` keeps `layout`,
  `procedures_at_end`, `footer_per_header`.
- `docs/configuration.md` and `docs/config-spec.md` drop the option;
  the config-spec's output model loses one knob it never needed.
