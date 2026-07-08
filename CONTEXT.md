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

Status: early development. The pipeline is proven end-to-end; features are being
widened milestone by milestone (see [`ROADMAP.md`](ROADMAP.md)).

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

5. **Determinism.** Same headers + same config → byte-identical output. (Honest
   caveat: a Lua policy *can* do arbitrary work, so determinism is a convention the
   config is expected to honor, not something the architecture forces. Analysis,
   which consults no policy, is deterministic unconditionally.)

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

- **Wrappers are NOT implemented.** Milestone 6 (generated wrapper procs:
  `cstring→string`, pointer+length→slice, flag-enum→`bit_set`) is **deferred and
  has never existed** in the codebase — earlier roadmap boxes that implied
  otherwise were corrected. Idiomatic mode today means "faithful bindings spelled
  in native Odin types, one `foreign` decl per function" — no authored procedure
  bodies, no paired `__abi` decls. Anything that authors procedure *logic* (bodies,
  temp vars, allocator calls) fights principles 1 and 2 and is out of scope until
  that milestone is deliberately taken up. Analysis already records the
  length-like-neighbour facts a future pointer+length→slice decision would consume.

- **Config is Lua, common cases are plain data.** Data for the easy path
  (`package`, `headers`, `strip_prefixes`, `type_map`); callbacks (`rename`,
  `keep`) that return a decision or `nil` to accept the default for the hard path —
  same small API either way. Keyword-safe renames are automatic: a C symbol named
  like an Odin keyword (`matrix`, `map`, `proc`) gets a deterministic rename plus
  `@(link_name)` so the C symbol is preserved; config can override.

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
- **Examples** in `examples/` (`fff`, `sqlite3`) are checked-in generated output;
  regenerate and `odin check` them when emission changes.
- **Style.** Plain, data-oriented Odin. Readable over clever, small procedures,
  state passed explicitly (Odin procs do not capture). Match surrounding
  conventions. Keep the early surface small — before adding an option, ask whether
  richer callback context solves it, or whether it can wait.

---

## Pointers to fuller docs

- [`docs/overview.md`](docs/overview.md) — the spirit of the project.
- [`docs/architecture.md`](docs/architecture.md) — the stages and their boundaries.
- [`docs/type-modes.md`](docs/type-modes.md) — ABI vs idiomatic in depth.
- [`docs/configuration.md`](docs/configuration.md) — the Lua policy surface.
- [`ROADMAP.md`](ROADMAP.md) — milestone-by-milestone status and what's next.
- [`AGENTS.md`](AGENTS.md) — how to act when changing the code.
