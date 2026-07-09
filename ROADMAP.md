# Roadmap

Ordered by risk and dependency: prove the pipeline end-to-end on the simplest possible input, then widen. Each milestone should leave the project in a buildable, demonstrable state.

## Milestone 0 — Prove the foundations

The two biggest unknowns. Settle them before writing any pipeline code.

- [x] Link libclang from Odin and call one function (e.g. print the Clang version). Uses Karl's bindings. If this does not link, nothing else matters yet.
- [x] Stand up the project skeleton: build compiles, entry point runs, `docs/` and `AGENTS.md` in place.
- [x] Wire the generation arena: create it, install it as `context.allocator` for the run scope, free it at the end.

## Milestone 1 — The vertical slice

Drive one trivial header all the way through all four stages, ABI mode, no Lua.

Target: `int add(int a, int b);` → `add :: proc(a: c.int, b: c.int) -> c.int ---`

- [x] Minimal IR: `Func_Decl`, `Param`, a type pool with builtin types, the ordering list, and the `add_*` construction helpers.
- [x] Extraction: parse a TU, walk cursors, pull one `FunctionDecl` (return type + params) into the IR. Copy every string into the arena. Filter by source location so system headers are ignored.
- [x] Pipeline frame: `main` calls all four stages in order, with Analysis and Transformation as empty pass-throughs.
- [x] Emission: walk the ordering list, emit the `package`, `foreign import`, and the one function in ABI mode.
- [x] Confirm the emitted file compiles as Odin.

Reaching this means the architecture works. Everything after is widening a proven thread.

## Milestone 2 — Widen extraction (all declaration kinds)

- [x] Structs and unions (fields, opaque/forward-declared, packed).
- [x] Enums (members, backing type).
- [x] Typedefs.
- [x] Global variables.
- [x] Function pointers and variadics.
- [x] Pointers and arrays in the type pool (recursive types).
- [x] Object-like macros (`#define` constants); record and skip function-like ones.
- [x] Doc-comment passthrough (raw text attached to declarations).

## Milestone 3 — Pointer lowering

- [x] Represent each pointer decision explicitly (lowering + confidence + reason).
- [x] Kind-dependent defaults: `void*`→`rawptr`, `const char*`→`cstring`, `T[N]`→`[N]T`, bare `T*`→`^T`.
- [x] Emit diagnostics for heuristic (guessed) decisions.
- [x] Analysis hint: detect length-like neighbours (`count`/`len`/`size`/…) — a fact, not yet a decision.

## Milestone 4 — Idiomatic mode (no wrappers yet)

- [x] Type mode flag (`abi` | `idiomatic`), target detected via libclang.
- [x] Leaf renames proven safe on the target (`c.int`→`i32`, etc.), including enum backing types.
- [x] Confirm ABI and Idiomatic both emit correctly for the widened decl set.

## Milestone 5 — The Lua policy layer

- [x] Load and execute a Lua config once at startup (`vendor:lua/5.4`).
- [x] Policy interface: explicit state (no captured closures); pure stages see only the policy, never `lua_State`.
- [x] Marshal callback context tables in; copy returned strings into the arena.
- [x] Wire `rename` and `keep` through Transformation. Filtering rebuilds the ordering list.
- [x] Keyword-safe default renames: a C symbol named like an Odin keyword (`matrix`, `map`, `proc`, …) gets a deterministic default rename plus `@(link_name)`; config can override.
- [x] Declarative shortcuts: `strip_prefixes`, `type_map`, package/output/foreign settings.

## Milestone 6 — Conversions (idiomatic wrappers)

> **Deferred.** Wrapper/conversion work has not started — the four boxes that were marked done described code that never existed. Slices (`pointer+length → []T`) and `cstring → string` both change arity or layout, so neither is a pure type swap: each needs a generated wrapper proc sitting in front of a faithful `foreign` decl, which is the bulk of this milestone. The plumbing is forward-looking: Analysis already records length-like-neighbour facts (`analyze.odin`) that a future pointer+length→slice decision will consume.

- [ ] Closed conversion set as a union carrying its own data; `nil` = no conversion.
- [ ] Two-layer emission: faithful ABI foreign decl + generated wrapper.
- [ ] `cstring` parameter→`string` wrapper parameter; return `cstring` stays ABI-shaped until ownership/lifetime policy exists.
- [ ] pointer+length→slice (config-driven).
- [ ] flag enum→`bit_set` (heuristic + config confirm).
- [ ] `wrappers = false` falls back to ABI form per declaration.

## Milestone 7 — Robustness & polish

- [x] Diagnostics report: list every non-certain decision in a run.
- [x] Check libclang parse diagnostics; fail loudly on bad `-I`/`-D` rather than emitting partial output. _(pulled forward)_
- [x] Config validation with clear error messages.
- [x] Real build/usage instructions in the README; fill the verification commands in `AGENTS.md`.
- [x] Sandbox the Lua config (withhold `io`/`os`/`package`/loaders) to make determinism structural.

## Later

- [ ] Milestone 6 (wrappers) when deliberately taken up — see above.
- [ ] Self-hosted libclang bindings — H2Odin generates the bindings it uses.
- [ ] Multi-target runs (generate per target, merge).
- [ ] Config-driven inputs (`headers`, `include_dirs`, `defines`) and `output` path.
- [ ] A license.

---

### Start here

Milestones 0–5 and 7 are complete. Next large feature when wanted: **Milestone 6
(wrappers)**. Smaller follow-ups live under **Later**.
