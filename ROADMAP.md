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
>
> The generator authors any wrapper it emits, from the closed conversion set below. Config *names* a conversion; it never supplies its text. That boundary is permanent and does not depend on this milestone landing.

- [ ] Closed conversion set as a union carrying its own data; `nil` = no conversion.
- [ ] Two-layer emission: faithful ABI foreign decl + generated wrapper.
- [ ] `cstring` parameter→`string` wrapper parameter; return `cstring` stays ABI-shaped until ownership/lifetime policy exists.
- [ ] pointer+length→slice (config-driven).
- [ ] `wrappers = false` falls back to ABI form per declaration.

Flag enum→`bit_set` was once listed here. It needs no wrapper — it rewrites a declaration and its members' values (`value → log2(value)`), which is Transformation's ordinary work. It moves to Milestone 9.

## Milestone 7 — Robustness & polish

- [x] Diagnostics report: list every non-certain decision in a run.
- [x] Check libclang parse diagnostics; fail loudly on bad `-I`/`-D` rather than emitting partial output. _(pulled forward)_
- [x] Config validation with clear error messages.
- [x] Real build/usage instructions in the README; fill the verification commands in `AGENTS.md`.
- [x] Sandbox the Lua config (withhold `io`/`os`/`package`/loaders) to make determinism structural. _(Milestone 8 reopens `package` narrowly, for `require` — see below.)_

---

The milestones below build the configuration model specified in
[`docs/config-spec.md`](docs/config-spec.md). Read that first: it fixes the shape
each of these grows toward, and each milestone should land as a step into it
rather than a parallel surface. `docs/configuration.md` holds the migration table
from today's flat keys.

## Milestone 8 — The `h2o` API and the sectioned config

The shape change everything else depends on. Do this before adding any new option
to the flat table, or the flat table grows a surface that must later be removed.

- [x] `require "h2odin"` resolves a preloaded prelude; searchers restricted to the prelude and `.lua` beneath the config's directory. `io`/`os`/`debug`/raw loaders stay withheld.
- [x] `h2o.config()` returns the config object; sections (`naming`, `types`, `symbols`, `macros`, `enums`, `structs`, `procs`, `foreign`, `output`, `diagnostics`).
- [x] Odin-registered helpers exposed to Lua: `h2o.str.has_prefix` / `strip_prefix` / `has_suffix`.
- [x] Validation rejects a table where a callback belongs (and vice versa), naming the key — plural is data, singular is a callback.
- [x] Migrate `foreign_lib`→`foreign.import_lib`, `strip_prefixes`→`naming.strip_prefixes`, `type_map`→`types.map` / `types.overrides`, `rename`→`naming.override`.
- [x] `keep` → `symbols.remove.where`. **Polarity inverts**; reject `keep` by name rather than accepting both.
- [x] Respell symbol kinds: `function`→`proc`, `variable`→`var`, `constant`→`const`, `enum_member`→`enum_value`.

## Milestone 9 — Naming, macros, enums

The three sections that carry real algorithms. Each needs a pure Odin module that
`policy.odin` merely registers into the VM — never logic living behind the Lua
boundary.

- [ ] Identifier tokenizer + case conversion in a pure module; exposed as `h2o.naming.snake_case` / `ada_case` and reused by the generator's automatic naming.
- [ ] `known_tokens` dictionary; ambiguous splits emit `naming_ambiguity` and are resolved per-symbol via `override`.
- [ ] `naming.strip_suffixes`, `naming.overrides`.
- [ ] `symbols.remove.names` / `.patterns` (declarative tiers gate before `where` runs).
- [ ] `macros.groups` via `h2o.macro_group.enum{...}`: `prefix` → `exclude_prefixes` → value-kind → `include`, in that order. Synthesizes an ordinary explicit-valued IR enum.
- [ ] Macro view with `m.name`, `m.value`, `m:is_integer()`. `m.expr` is deliberately not exposed.
- [ ] `enums.member` callback; `enums.anonymous`; `enums.bit_sets` with explicit `mode = "log2"` and a `bit_set_non_power_of_two` diagnostic.

## Milestone 10 — Structs, procs, inputs, output

- [ ] `types.overrides` (replace a declaration) as distinct from `types.map` (rewrite references).
- [ ] `structs.fields` / `structs.field` (`type`, `tag`), `structs.align`.
- [ ] `procs.params` / `procs.param`, `procs.results` / `procs.result` — signature spellings and defaults only, no wrappers.
- [ ] `config.inputs` (multi-header) and `preprocess.include_paths` / `.defines`.
- [ ] `output_folder`, `output.procedures_at_end`, `output.imports_file`, `output.footer_per_header`.
- [ ] `foreign.link_prefix` — the external C symbol, not the Odin name.

## Milestone 11 — Diagnostics as a system

- [ ] Every heuristic registers a named category rather than printing ad-hoc.
- [ ] `config.diagnostics` sets per-category severity (`warn` | `error`); default posture is `warn`.
- [ ] Local overrides on a feature constructor beat the global block.
- [ ] Name the categories that already exist: `pointer_lowering_guess`, `unresolved_idiomatic_leaf`, `opaque_layout_fallback`.

## Later

- [ ] Milestone 6 (wrappers) when deliberately taken up — see above.
- [ ] Self-hosted libclang bindings — H2Odin generates the bindings it uses.
- [ ] Multi-target runs (generate per target, merge).
- [ ] A license.

---

### Start here

Milestones 0–5, 7, and 8 are complete. The next work is **Milestone 9** — naming
tokenizer/case conversion, macro groups, and enum policies — on top of the
sectioned `h2o` shape. **Milestone 6 (wrappers)** remains deferred and is
independent of 9–11.
