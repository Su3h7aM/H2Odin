# CONTEXT.md

Working context for H2Odin — what the project is, the choices behind it, how it is
built, and why. This is the orientation file to read first. Design intent lives in
[`docs/`](docs/); rules of engagement live in [`AGENTS.md`](AGENTS.md); this file
ties them together and records the *why* that neither of those spells out.

---

## What this project is

H2Odin is a **C-header-to-Odin bindings generator, written in Odin.** It reads a C
header through libclang, builds its own description of the API, and emits clean Odin
`foreign` bindings. A small Lua policy layer configures the run without ever
authoring output.

Status: Milestones 0–5, 7–14 complete; Milestone 6 (idiomatic wrappers) is
deferred. **H2Odin is self-hosted**: Extraction runs on the libclang package
H2Odin itself generates (`vendored/libclang`, Odin naming convention,
regenerated generation-over-generation via `make regen-libclang` — spec 0002).
Code health items for specs 0005–0007 (opaque handles, imports_file
removal, types.opaque for incomplete tag records) and deprecated-declaration
propagation (spec 0009) are done. The 2026-07 review left a hardening
backlog in ROADMAP's **Code health** section (headlined by symbol-collision
validation, spec 0008). The rest is polish / deferred work in ROADMAP's
**Later** section. See [`ROADMAP.md`](ROADMAP.md) and
[`docs/specs/`](docs/specs/).

---

## The architecture, in one screen

Four stages, data flowing left to right, each depending only on its declared input:

```
Extraction  ->  Analysis  ->  Transformation  ->  Emission
 (libclang)     (facts)        (decisions)          (text)
```

- **Extraction** (`src/extract.odin`) — the *only* stage that talks to libclang.
  Walks the parsed translation unit and builds the IR. Decides nothing: no
  renaming, no filtering, no policy. Keeping it opinion-free is what lets every
  later stage be tested without a C compiler in the loop.
- **Analysis** (`src/analyze.odin`) — adds *facts* that are true regardless of
  config (e.g. "this parameter looks length-like and sits next to a pointer").
  Surfaces hints; commits to nothing.
- **Transformation** (`src/transform.odin`) — the *only* stage that consults
  policy. Records decisions: renames, drops, type spellings. Rebuilds the ordering
  list when filtering.
- **Emission** (`src/emit.odin`) — serializes the final IR to Odin text. By the
  time it runs every decision is already made, so it should read as boring.

The litmus test for where logic belongs: **would it still be true if the user
changed their config?** Yes → a fact (Analysis). No → a decision (Transformation).
Extraction and Emission decide nothing.

`src/main.odin` owns the stage order and the generation arena; the stages own
everything else. `src/ir.odin` defines the IR; `src/types.odin` is the single
source of truth for how C types are *spelled* in Odin; `src/policy.odin` is the
Lua-backed policy layer.

---

## The principles everything follows from

These are load-bearing. When a decision is unclear, it is resolved by appeal to
these, not by convenience.

1. **Simple *codebase*, not just a simple tool.** A newcomer should open one stage,
   see what goes in and what comes out, and fix something without learning a web of
   abstractions. The generator may be capable; the code that makes it so stays
   plain. Data-oriented: data is data, and the code that transforms it is separate
   and visible.

2. **Correctness over convenience.** A type is never swapped for a nicer-looking one
   if it could change behavior or break the ABI. An honest, slightly-less-pretty
   binding beats a native-looking one that lies.

3. **The provability rule.** *Can this be proven from the header and the target
   alone?* If yes, the generator does it automatically. If it depends on what the
   library *means* — knowledge in a human's head, not in the types — it belongs in
   configuration. The generator owns *how*; configuration only chooses *what* and
   *where*.

4. **Honesty about uncertainty.** When a header lacks the information to know the
   right answer, H2Odin picks a conservative default, makes the guess *visible*
   (a diagnostic), and lets config override it — it never silently guesses wrong.

5. **Determinism.** Same headers + same config tree → byte-identical output. The Lua
   config is sandboxed (no `io`/`os`/`debug`, raw loaders withheld), so host side
   effects are blocked structurally; pure non-determinism inside allowed libs is
   still a config convention. Once `require` lands (see `docs/config-spec.md`) a
   config may read Lua beneath its own directory and nothing beyond it — hence
   "config *tree*". Analysis, which consults no policy, is deterministic
   unconditionally.

---

## Invariants — do not break these

- **libclang stays in Extraction.** Nothing downstream holds a libclang handle.
- **Lua stays behind the policy layer.** Only Transformation consults policy, and it
  consults *policy*, not "Lua" — the pure stages never see the VM, stack, or refs.
  A different policy backend should require no change outside `policy.odin`.
- **Copy foreign strings at the boundary.** Any string owned by libclang or Lua is
  copied into H2Odin's generation arena before it enters the IR. This one habit
  keeps both foreign boundaries clean.
- **IR references are handles (indices), not pointers.** A pointer into a growing
  pool is invalidated when the pool grows; a handle stays valid. Dropping a decl is
  just removing it from the ordering list.
- **The generation arena owns long-lived memory.** `context.allocator` points at
  the arena as a convenience, not as the owner. Scratch uses `temp_allocator` and
  never enters the IR.
- **Configuration selects behavior; it never authors output.** The generator owns
  every byte of Odin emitted.

If a task appears to require breaking one of these, stop and surface the conflict
rather than bend it silently.

---

## Key implementation choices, and why

- **The IR is dense pools + a separate ordering list.** Odin does not require
  file-scope decls in dependency order, so the ordering list exists only to make
  output read like the original header — not to make it compile. Handles over
  pointers (see invariants) fall out of this pool design.

- **Type spelling is data, in `src/types.odin`, decided nowhere else.** Emission
  reads spellings from the tables and never invents them. Every row was verified
  against `core:c` as shipped with the compiler — a spelling that does not resolve
  there would emit code that fails `odin check`. Builtins use an enumerated array so
  adding a `Builtin_Kind` without deciding its spelling fails to compile; std
  typedefs (`stdint.h`/`stddef.h`) are an open-ended flat table that grows one
  verified row at a time.

- **Two type modes.** *ABI mode* (default) spells everything faithfully via
  `core:c` (`c.int`, `c.size_t`). *Idiomatic mode* substitutes native Odin types
  (`i32`, `u64`) **only where the substitution is proven ABI-safe on the target.**
  The substitution ladder in Transformation:
  - *Rung 1* — a table's `idiomatic` preference, but still size-verified against
    what libclang measured before use; never assumed.
  - *Rung 2* — no table preference: derive a fixed-width native spelling from the
    measured size and signedness.
  - *Rung 3* — cannot prove it: fall back to the ABI spelling and emit a diagnostic.
  Notable deliberate choice: plain `char` always prefers `u8` regardless of the
  target's true signedness, because `core:c.char` is hardcoded `u8`; deriving `i8`
  on signed-char targets would produce a type un-assignable to `core:c.char` and
  break interop with the rest of the Odin C-FFI ecosystem.

- **Pointer lowering is spelling, not wrapping.** `void*`→`rawptr`,
  `const char*`→`cstring`, function pointer→`proc "c"`, `T[N]`→`[N]T`, bare
  `T*`→`^T` (recorded as a *guessed* decision with a diagnostic). These are
  type-level mapping decisions and are always on — `cstring` for `const char *`
  predates and is independent of any wrapper machinery.

  Constness alone does not prove NUL termination, and mutable `char *` may be
  either a string or a byte/output buffer. The automatic rule therefore leaves
  mutable pointers as `^u8`; when header comments or domain names establish a
  string contract, config should override that specific field/parameter to
  `cstring` (or `[^]cstring` for a counted array of C strings). The fff example
  documents this boundary explicitly.

- **Bit-field emission is planned before it is serialized.** Extraction stores
  measured widths, offsets, sizes, and alignments; Emission proves a whole
  record layout arithmetically and emits `bit_field uN` only when that proof
  succeeds. The plan is an emission-local view and never mutates semantic IR.
  Any user-authored adjacent field spelling or config type rewrite makes the
  proof fail closed, because the original C measurements no longer prove the
  bytes that Odin will emit. Opaque records do not produce diagnostics for
  pointer guesses in fields that never appear.

- **An output unit is one self-contained Odin file.** Multi-header extraction
  still builds one shared IR and one Odin package. A planned per-header layout
  partitions live declarations by their *home header* (the configured input
  header that owns the declaration or its definition); merged layout keeps one
  unit. Placement is decided in Transformation before Emission serializes bytes.
  Every unit repeats the imports and foreign-library declaration it needs because
  Odin names introduced by `import` and `foreign import` are file-local. See
  [`docs/specs/0003-multi-file-odin-emission.md`](docs/specs/0003-multi-file-odin-emission.md).

- **Wrappers are NOT implemented.** Milestone 6 (generated wrapper procs:
  `cstring→string`, pointer+length→slice, flag-enum→`bit_set`) is **deferred and
  has never existed** in the codebase — earlier roadmap boxes that implied
  otherwise were corrected. Idiomatic mode today means "faithful bindings spelled
  in native Odin types, one `foreign` decl per function" — no authored procedure
  bodies, no paired `__abi` decls. Anything that authors procedure *logic* (bodies,
  temp vars, allocator calls) fights principles 1 and 2 and is out of scope until
  that milestone is deliberately taken up. Analysis already records the
  length-like-neighbour facts a future pointer+length→slice decision would consume.

- **Config is Lua via `require "h2odin"`.** A program builds a sectioned object
  with `h2o.config()` — data for the easy path (`package`, `foreign.import_lib`,
  `naming.strip_prefixes`, `types.overrides`); callbacks (`naming.override`,
  `symbols.remove.where`) that return a decision or `nil` for the hard path —
  same small API either way. Keyword-safe renames are automatic: a C symbol named
  like an Odin keyword (`matrix`, `map`, `proc`) gets a deterministic rename plus
  `@(link_name)` so the C symbol is preserved; config can override.

- **Config selects; it never authors Odin.** This is about *who writes the source*,
  and it is permanent. It is not the same claim as "the generator emits no wrapper
  procedures," which is merely today's state (Milestone 6, deferred). If wrappers
  ever land, the generator authors them from a closed conversion set and config
  only names the conversion. Conflating the two claims is a recurring confusion.

- **The config surface is the sectioned `h2o` model** in
  [`docs/config-spec.md`](docs/config-spec.md). Milestones 8–10 landed the
  shape plus naming, macros, enums, structs, procs, multi-header inputs, and
  output knobs. `docs/configuration.md` describes what is wired today and the
  migration from the old flat keys (including the `keep` →
  `symbols.remove.where` polarity flip). Diagnostics severity is wired
  (Milestone 11): named categories, `config.diagnostics`, constructor-local
  overrides.

---

## How to work in this repo

- **VCS is Jujutsu (`jj`), not raw git.** Git is only the backend. Prefer the
  non-interactive `jj desc` + `jj new` flow: start from an empty working copy, set a
  `WIP:` description before editing, replace it with the final description after,
  then `jj new` to leave a fresh empty working copy.
- **Scoped commits.** One focused feature per commit, each independently buildable —
  never a whole milestone in one commit.
- **Verification.** `make check` / `make build` / `make test` / `make format`
  (odinfmt via `odinfmt.json`). For the examples, `odin check` them, e.g.
  `odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored`.
- **Tests are isolated and runnable without libclang/Lua where possible.** Unit
  tests sit beside sources (`*_test.odin`, package `h2odin`); e2e tests
  (`tests/e2e_test.odin`, package `h2odin_e2e`) drive the built binary against
  fixtures in `tests/fixtures/`.
- **Examples** in `examples/` (`bit_fields`, `fff`, `sqlite3`) are checked-in generated output;
  regenerate and `odin check` them when emission changes.
- **Style.** Plain, data-oriented Odin. Readable over clever, small procedures,
  state passed explicitly (Odin procs do not capture). Match surrounding
  conventions. Keep the early surface small — before adding an option, ask whether
  richer callback context solves it, or whether it can wait.

---

## Pointers to fuller docs

- [`docs/overview.md`](docs/overview.md) — the spirit of the project.
- [`docs/architecture.md`](docs/architecture.md) — the stages and their boundaries.
- [`docs/specs/`](docs/specs/) — numbered design specs: bit-field emission (0001), self-hosted libclang bindings (0002), multi-file emission (0003), bit_set backing width (0004), opaque handle typedefs (0005), imports_file removal (0006), opaque tag records (0007).
- [`docs/source-layout.md`](docs/source-layout.md) — what each `src/` file is for; planned file splits.
- [`docs/type-modes.md`](docs/type-modes.md) — ABI vs idiomatic in depth.
- [`docs/configuration.md`](docs/configuration.md) — the Lua policy surface today.
- [`docs/config-spec.md`](docs/config-spec.md) — the config model we are building toward.
- [`ROADMAP.md`](ROADMAP.md) — milestone-by-milestone status and what's next.
- [`AGENTS.md`](AGENTS.md) — how to act when changing the code.
