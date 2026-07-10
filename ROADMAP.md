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

- [x] Identifier tokenizer + case conversion in a pure module; exposed as `h2o.naming.snake_case` / `ada_case`. Automatic naming keeps C case (foreign porting convention) after affix strip + keyword safety; helpers are for deliberate recasing in callbacks.
- [x] `known_tokens` dictionary; ambiguous splits emit `naming_ambiguity` and are resolved per-symbol via `override` / `overrides`.
- [x] `naming.strip_suffixes`, `naming.overrides`.
- [x] `symbols.remove.names` / `.patterns` (declarative tiers gate before `where` runs).
- [x] `macros.groups` via `h2o.macro_group.enum{...}`: `prefix` → `exclude_prefixes` → value-kind → `include`, in that order. Synthesizes an ordinary explicit-valued IR enum.
- [x] Macro view with `m.name`, `m.value`, `m:is_integer()`, `m:has_prefix(...)`. `m.expr` is deliberately not exposed.
- [x] `enums.member` callback; `enums.anonymous`; `enums.bit_sets` with explicit `mode = "log2"` and a `bit_set_non_power_of_two` diagnostic.

## Milestone 10 — Structs, procs, inputs, output

- [x] `types.overrides` (replace a declaration) as distinct from `types.map` (rewrite references).
- [x] `structs.fields` / `structs.field` (`type`, `tag`), `structs.align`.
- [x] `procs.params` / `procs.param`, `procs.results` / `procs.result` — signature spellings and defaults only, no wrappers.
- [x] `config.inputs` (multi-header) and `preprocess.include_paths` / `.defines`.
- [x] `output_folder`, `output.procedures_at_end`, `output.imports_file`, `output.footer_per_header`.
- [x] `foreign.link_prefix` — the external C symbol, not the Odin name.

## Milestone 11 — Diagnostics as a system

- [x] Every heuristic registers a named category rather than printing ad-hoc.
- [x] `config.diagnostics` sets per-category severity (`warn` | `error`); default posture is `warn`.
- [x] Local overrides on a feature constructor beat the global block.
- [x] Name the categories that already exist: `pointer_lowering_guess`, `unresolved_idiomatic_leaf`, `opaque_layout_fallback`.

## Milestone 12 — C bit-fields → Odin `bit_field`

The hard correctness gap blocking self-host: any struct containing a bit-field
is emitted as an opaque `struct {}` today (`opaque_layout_fallback`), which
makes by-value construction — required for e.g. libclang's `CXIndexOptions` —
impossible. Design decisions are recorded in
[`docs/specs/0001-bit-field-emission.md`](docs/specs/0001-bit-field-emission.md).

- [x] Extraction: stop dropping bit-field members. Capture per-field facts:
      `is_bitfield` (`clang_Cursor_isBitField`), `bit_width`
      (`clang_getFieldDeclBitWidth`), and the measured bit offset
      (`clang_Cursor_getOffsetOfField`) — facts, decided nothing.
- [x] IR: extend `Field` with the bit-field facts;
      `has_unrepresentable_fields` remains only for genuine failures (unknown
      width, unsupported field type) — a representable bit-field no longer
      forces opacity. Fix the current inconsistency where a record marked
      unrepresentable still carries a partial `fields` slice.
- [x] Emission: group runs of adjacent bit-fields into
      `using _: bit_field uN { Name: uN | width, ... }` regions with the
      backing type and placement *proven* from the measured offsets and record
      size; anonymous/reserved members emit as `_` with their width.
- [x] Fail closed: when the measured layout cannot be reproduced with an Odin
      `bit_field` region, keep the opaque fallback and emit the new
      `bit_field_layout_fallback` diagnostic category (registered
      Milestone-11-style, `warn` by default).
- [x] Stop emitting `pointer_lowering_guess` diagnostics for fields of records
      that emit opaque — today they reference fields that never appear in the
      output.
- [x] Tests: unit fixtures for width/offset capture; a golden
      `CXIndexOptions`-shaped fixture whose emitted layout matches the
      known-good hand binding (`size_of` equality is the hard acceptance bar —
      "looks right but wrong size" is a fail); regression coverage that
      bit-field-free structs are unchanged; e2e through `odin check`.

## Milestone 13 — Self-hosted libclang bindings

H2Odin generates the libclang bindings its own Extraction stage imports,
replacing the vendored hand-written package. The generated package uses the
**Odin naming convention** (Ada_Case types, snake_case procs, SCREAMING_SNAKE
constants, library prefixes stripped), and `src/extract.odin` migrates to the
new names. Decisions and bootstrap plan in
[`docs/specs/0002-self-hosted-libclang.md`](docs/specs/0002-self-hosted-libclang.md).
Depends on Milestone 12 (bit-fields) — without it `CXIndexOptions` ships opaque.

- [ ] Multi-header input correctness: treat every header in `config.inputs` as
      "ours" during capture, not just the current TU's main file — today a
      typedef declared in a sibling input header is resolved transparently at
      use sites (its name is lost), which breaks the `clang-c/*.h` family
      (`Index.h` includes `CXString.h`, …).
- [ ] A checked-in `config.lua` for the pinned headers under
      `vendored/libclang/headers/`: multi-header inputs, include paths,
      Odin-convention naming (strip `clang_`/`CX*`, recase via
      `h2o.naming.snake_case` / `ada_case` as in the sqlite3 example),
      curation of macro groups / enums as needed.
- [ ] Quality pass on the generated output: pointer out-params
      (`pointer_lowering_guess`) resolved via config where the hand binding
      proves the intent; flag enums grouped where applicable.
- [ ] Regenerate into the `vendored:libclang` import path (replacing the hand
      package) and migrate `src/extract.odin` to the generated names
      (`clang.create_index`, `clang.get_cursor_kind`, …).
- [ ] Bootstrap explicitly: generation N is produced by a binary built against
      the checked-in bindings from generation N−1; the generated package is
      checked in, so the cycle never needs the old hand binding again after
      the switch.
- [ ] `make test` / examples stay green against the generated package; a
      `make regen-libclang` (or similar) target documents the regeneration
      workflow; the clang-c header version stays pinned in
      `vendored/libclang/headers/`.

## Code health (ongoing)

Not a milestone — a running list of known defects and structural debt. Fix
opportunistically or alongside the milestone that touches the same area.

- [x] **Bug — macro token use-after-free** (`src/extract.odin`,
      `extract_macro`): `defer clang.disposeTokens(...)` was inside the
      `if num_tokens > 0 { }` block; Odin's `defer` is block-scoped, so the
      token array was freed before the loop below read it. Fixed by deferring
      dispose at procedure scope.
- [x] **CLI is config-only**: drop `-mode:` and positional headers; require
      `-config:` with `config.inputs`. Keep process knobs (`-help`, `-quiet`).
- [x] **Split oversized source files** into files with one well-defined scope
      each — `policy_*`, `transform_*`, `extract_*`, `emit_*` per
      [`docs/source-layout.md`](docs/source-layout.md).

## Later

- [ ] Milestone 6 (wrappers) when deliberately taken up — see above.
- [ ] Multi-target runs (generate per target, merge).
- [ ] A license.

---

### Start here

Milestones 0–5 and 7–12 are complete. **The next goal is self-hosted libclang
bindings (Milestone 13)**; its **bit-field emission prerequisite (Milestone 12)**
is complete. **Milestone 6 (wrappers)** remains
deferred and independent.
