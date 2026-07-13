# AGENTS.md

Guidance for AI agents working in H2Odin — a C-header-to-Odin bindings generator written in Odin. Design intent and API documentation live in source documentation comments; this file is about how to act.

The pipeline has four stages: **Extraction → Analysis → Transformation → Emission**.

## Invariants — do not break these

- **libclang stays in Extraction.** No later stage holds a libclang handle; copy what you need into the IR.
- **Lua stays behind the policy layer.** Only Transformation consults policy. Other stages must not know Lua exists. Algorithms exposed to Lua (case conversion, identifier tokenizing, prefix handling) live in pure Odin modules that `policy.odin` merely *registers* — never inside the policy layer itself.
- **Lua sees views, never the IR.** Callbacks receive small, stable, read-only tables and return decisions. Handing Lua an IR handle or pointer would weld every user config to the current internals.
- **Copy foreign strings (libclang/Lua) into the generation arena at the boundary.** Never store foreign-owned strings in the IR.
- **Lua errors unwind with C `longjmp`.** `lua.L_error` and the `L_check*` helpers never return normally — they jump across Odin frames, skipping `defer`. In any Odin proc callable from Lua: no `defer` that must run, and no owned resource held, across a call that can raise; keep raising calls in small leaf procedures.
- **IR references are handles, not pointers.** Pool growth invalidates pointers.
- **The generation arena owns long-lived memory.** `context.allocator` is a convenience, not the owner. Scratch uses `context.temp_allocator` and never enters the IR.
- **Configuration selects behavior; it never authors output.** The generator owns every byte of Odin emitted, including configured wrapper procedures. Configuration selects from supported transformations; it does not provide source text.
- **Correctness over convenience.** Never swap in a type that could change behavior or break the ABI. When ambiguous, pick a conservative default, flag it, and let config override — never silently guess.

If a task seems to require breaking one of these, stop and surface the conflict.

## Where does my change go?

Ask: *would it still be true if the user changed their config?*
Yes → a fact → **Analysis** (or captured raw in Extraction). No → a decision → **Transformation**. Turning decided IR into text → **Emission**. Extraction and Emission decide nothing.

## Version control

This project uses **Jujutsu (`jj`)** as its VCS — always use `jj`, not raw `git`, for any repository operation (status, diff, describe, rebase, bookmark, push, conflict resolution, history). Git is the backend only. Prefer the non-interactive `jj desc` + `jj new` workflow over `jj commit`: start work from an empty working-copy commit, set a `WIP:` description before editing, replace it with the final description after, then `jj new` to leave a fresh empty working copy.

**Before every `jj new` (and before considering a change finished):**

```sh
./scripts/format && ./scripts/check && ./scripts/test && ./scripts/build
# or, with mise (pinned Odin; file tasks under scripts/ with #MISE annotations):
# mise run format && mise run check && mise run test && mise run build
```

Fix any failure; if the fix is formatting or a small correction that belongs in an earlier commit of the stack, use `jj absorb` (or squash into the right change) rather than leaving a drive-by follow-up commit.

If `./scripts/check` fails inside Odin's own `base/runtime` (e.g. `Invalid build tag platform: bedrock`), the compiler binary and `ODIN_ROOT` are mismatched — `scripts/_common.sh` pairs them automatically; ensure `which odin` is the toolchain you intend (mise-pinned `dev-2026-07a` vs system package).

## Style

Plain, data-oriented Odin — data is data, code that transforms it is separate. Prefer readable over clever, match surrounding conventions, keep procedures small. Pass state explicitly; Odin procedures do not capture. Keep the pure stages testable without a live libclang or Lua.

## Scope

Keep the early surface small. Before adding an option or abstraction: can richer callback context solve it? can it wait? If it must exist, keep it minimal. When in doubt, do the smaller thing and leave a note.

These are guidelines, not law. If docs and code disagree, or a task fights an invariant, raise it rather than bend it silently.

## Verification

Run from the repo root. Tasks are the executables in `scripts/` (each has
`#MISE` annotations for description/depends/sources). Run them directly, or via
mise (`.mise/config.toml` points `task_config.includes` at `scripts/`):

```sh
./scripts/check              # odin check src (vet + strict-style)
./scripts/build              # build/h2odin
./scripts/test               # unit tests (src/*_test.odin) + e2e (tests/)
./scripts/format             # odinfmt via odinfmt.json
./scripts/doc                # generate ignored src.odin-doc from source comments
./scripts/regen-libclang     # rebuild + rewrite vendored/libclang (self-host package)
./scripts/validate-examples  # regen all nine examples + odin check (corpus gate)

mise tasks                   # list (descriptions from #MISE)
mise run test                # same as ./scripts/test, with depends/sources
```

After extraction, transformation, or emission changes that affect emission
shape, run the corpus gate:

```sh
./scripts/validate-examples
```

All nine packages (fff, sqlite3, bit_fields, raylib, box3d, cgltf, curl,
miniaudio, ggml) must generate without error-severity diagnostics and pass
`odin check`. A regression on any of them is a blocker.

Unit tests must stay runnable without inventing new foreign deps in the pure stages. E2e tests drive `build/h2odin` against `tests/fixtures/`.

## Issue tracker

Issues and PRDs live in GitHub Issues and are managed with `gh`. External PRs
are not a triage surface. The canonical triage labels are `needs-triage`,
`needs-info`, `ready-for-agent`, `ready-for-human`, and `wontfix`.

Do not create standalone design documents. Durable design intent belongs in
concise documentation comments beside the declaration or stage it constrains;
planning and historical discussion belong in GitHub Issues.
