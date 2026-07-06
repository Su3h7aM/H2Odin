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

- [ ] Minimal IR: `Func_Decl`, `Param`, a type pool with builtin types, the ordering list, and the `add_*` construction helpers.
- [ ] Extraction: parse a TU, walk cursors, pull one `FunctionDecl` (return type + params) into the IR. Copy every string into the arena. Filter by source location so system headers are ignored.
- [ ] Pipeline frame: `main` calls all four stages in order, with Analysis and Transformation as empty pass-throughs.
- [ ] Emission: walk the ordering list, emit the `package`, `foreign import`, and the one function in ABI mode.
- [ ] Confirm the emitted file compiles as Odin.

Reaching this means the architecture works. Everything after is widening a proven thread.

## Milestone 2 — Widen extraction (all declaration kinds)

- [ ] Structs and unions (fields, opaque/forward-declared, packed).
- [ ] Enums (members, backing type).
- [ ] Typedefs.
- [ ] Global variables.
- [ ] Function pointers and variadics.
- [ ] Pointers and arrays in the type pool (recursive types).
- [ ] Object-like macros (`#define` constants); record and skip function-like ones.
- [ ] Doc-comment passthrough (raw text attached to declarations).

## Milestone 3 — Pointer lowering

- [ ] Represent each pointer decision explicitly (lowering + confidence + reason).
- [ ] Kind-dependent defaults: `void*`→`rawptr`, `const char*`→`cstring`, `T[N]`→`[N]T`, bare `T*`→`^T`.
- [ ] Emit diagnostics for heuristic (guessed) decisions.
- [ ] Analysis hint: detect length-like neighbours (`count`/`len`/`size`/…) — a fact, not yet a decision.

## Milestone 4 — Idiomatic mode (no wrappers yet)

- [ ] Type mode flag (`abi` | `idiomatic`), target detected via libclang.
- [ ] Leaf renames proven safe on the target (`c.int`→`i32`, etc.), including enum backing types.
- [ ] Confirm ABI and Idiomatic both emit correctly for the widened decl set.

## Milestone 5 — The Lua policy layer

- [ ] Load and execute a Lua config once at startup (`vendor:lua/5.4`).
- [ ] Policy interface: explicit state (no captured closures); pure stages see only the policy, never `lua_State`.
- [ ] Marshal callback context tables in; copy returned strings into the arena.
- [ ] Wire `rename` and `keep` through Transformation. Filtering rebuilds the ordering list.
- [ ] Declarative shortcuts: `strip_prefixes`, `type_map`, package/output/foreign settings.

## Milestone 6 — Conversions (idiomatic wrappers)

- [ ] Closed conversion set as a union carrying its own data; `nil` = no conversion.
- [ ] Two-layer emission: faithful ABI foreign decl + generated wrapper.
- [ ] `cstring`→`string`.
- [ ] pointer+length→slice (config-driven).
- [ ] flag enum→`bit_set` (heuristic + config confirm).
- [ ] `wrappers = false` falls back to ABI form per declaration.

## Milestone 7 — Robustness & polish

- [ ] Diagnostics report: list every non-certain decision in a run.
- [ ] Check libclang parse diagnostics; fail loudly on bad `-I`/`-D` rather than emitting partial output.
- [ ] Config validation with clear error messages.
- [ ] Real build/usage instructions in the README; fill the verification commands in `AGENTS.md`.
- [ ] Optionally sandbox the Lua config (withhold `io`/`os`) to make determinism structural.

## Later

- [ ] Self-hosted libclang bindings — H2Odin generates the bindings it uses.
- [ ] Multi-target runs (generate per target, merge).
- [ ] A license.

---

### Start here

Milestone 0, first box: **make libclang link and print its version.** Until that compiles, everything else is theory.
