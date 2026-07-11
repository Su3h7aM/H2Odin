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
- [x] `output_folder`, `output.procedures_at_end`, `output.footer_per_header`
      (`output.imports_file` removed in Code health; see spec 0006).
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

- [x] Multi-header input correctness: treat every header in `config.inputs` as
      "ours" during capture, not just the current TU's main file — today a
      typedef declared in a sibling input header is resolved transparently at
      use sites (its name is lost), which breaks the `clang-c/*.h` family
      (`Index.h` includes `CXString.h`, …).
- [x] A checked-in `H2Odin.lua` for the pinned headers under
      `vendored/libclang/headers/` (flat): multi-header inputs, include
      paths (`-I headers`; pin `#include`s use local `"Foo.h"` form),
      Odin-convention naming (strip `clang_`/`CX*`, recase via
      `h2o.naming.snake_case` / `ada_case` as in the sqlite3 example),
      curation of macro groups / enums as needed. Generated package is the
      `vendored/libclang` root (`output_folder = "."`, `per_header` layout).
- [x] Quality pass on the generated output: pointer out-params
      (`pointer_lowering_guess`) resolved via config where the hand binding
      proves the intent; flag enums grouped where applicable. Scoped to
      Extraction's call surface (`parse_translation_unit` multipointers +
      `Translation_Unit_Flags` bit_set, `tokenize`/`dispose_tokens`); full-API
      curation remains polish (spec 0002).
- [x] Replace the hand-written package at `vendored/libclang` with the
      generated package; migrate `src/extract*.odin` to generated names
      (`clang.create_index`, `clang.get_cursor_kind`, …).
- [x] Bootstrap explicitly: generation N is produced by a binary built against
      the checked-in bindings from generation N−1; the generated package is
      checked in, so the cycle never needs the old hand binding again after
      the switch (`make regen-libclang`).
- [x] `make test` stays green against the generated package; clang-c headers
      stay pinned in `vendored/libclang/headers/`.

## Milestone 14 — Multi-file Odin emission

Keep the current merged output as the default, and add an opt-in layout that
mirrors each configured input header as one Odin file in the same package.
Decisions and edge cases are recorded in
[`docs/specs/0003-multi-file-odin-emission.md`](docs/specs/0003-multi-file-odin-emission.md).

- [x] Extraction records each declaration's home input header as an IR fact;
      record/enum definitions replace placeholder ownership without leaking a
      libclang handle past Extraction.
- [x] `config.output.layout = "merged" | "per_header"` (default `merged`);
      per-header layout requires `output_folder`.
- [x] Transformation produces an explicit output plan, inherits placement for
      synthesized macro enums / bit sets, preserves per-header relative order,
      and fails before writes on duplicate stems or missing placement.
- [x] Emission serializes named output units with their own file-local Odin
      prelude; merged output remains byte-identical.
- [x] `footer_per_header` appends the matching footer to each per-header unit;
      e2e fixtures `odin check` the whole generated directory.
- [x] The libclang self-host config opts into `per_header`; regenerate and check
      `Index.odin`, `CXString.odin`, and the rest of the pinned input family.

## Code health (ongoing)

Not a milestone — a running list of known defects and structural debt. Fix
opportunistically or alongside the milestone that touches the same area.

- [x] **Bug — macro token use-after-free** (`src/extract.odin`,
      `extract_macro`): `defer clang.disposeTokens(...)` was inside the
      `if num_tokens > 0 { }` block; Odin's `defer` is block-scoped, so the
      token array was freed before the loop below read it. Fixed by deferring
      dispose at procedure scope.
- [x] **CLI is config-driven**: drop `-mode:` and positional headers; load
      `H2Odin.lua` from a project directory (or `-config:` as fallback) with
      `config.inputs`. Process knobs: `-help`, `-quiet`, `-verbose`,
      `-destination`.
- [x] **Split oversized source files** into files with one well-defined scope
      each — `policy_*`, `transform_*`, `extract_*`, `emit_*` per
      [`docs/source-layout.md`](docs/source-layout.md).
- [x] **Remove `output.imports_file`** — decided in
      [`docs/specs/0006-remove-imports-file.md`](docs/specs/0006-remove-imports-file.md).
      The option was unsound by Odin's scoping rules (`import` aliases and the
      `foreign import` lib name are file-local, so the main file's body cannot
      compile), and its output never compiled. Key rejected by name with a
      migration message; split branch in `emit` and text-level e2e assertions
      deleted. The hand-editable-foreign-import desire behind it becomes a
      future per-OS `foreign.import_lib` spec (see Later, Windows parity).
- [x] **Bug (ABI) — generated `bit_set`s have no explicit backing width.**
      `enums.bit_sets` emitted `Name :: bit_set[Enum]`; Odin sized it from the
      highest flag bit, not from the C type it replaces.
      `Translation_Unit_Flags` was 2 bytes against a 4-byte C `unsigned`
      parameter. Fixed per
      [`docs/specs/0004-bit-set-backing-width.md`](docs/specs/0004-bit-set-backing-width.md):
      `Bit_Set_Decl` carries the measured enum width, emission writes
      `bit_set[Enum; uN]`, fail closed under `bit_set_backing_mismatch`.
- [x] **Bug — 128B leak in every unit-test run.**
      `test_bit_field_layout_rejects_user_authored_adjacent_field_type`
      (`src/emit_bit_field_test.odin`) freed only `ir.types`, but `ir_init`
      also allocates `ir.input_headers` since Milestone 14. Fixed by using an
      arena like the sibling tests.
- [x] **Type-safety gap — opaque handles are non-distinct `rawptr` aliases.**
      Decided in
      [`docs/specs/0005-opaque-handle-typedefs.md`](docs/specs/0005-opaque-handle-typedefs.md):
      a typedef of a pointer to an *incomplete* record emits
      `Foo :: distinct rawptr` automatically; `void*` typedefs stay plain
      aliases unless opted in via `types.distinct`. Aliased handles of one
      record stay mutually assignable; completed records emit normally.
      Libclang config drops the `types.overrides` rawptr-collapse block and
      `*Impl` `symbols.remove` entries; package regenerated.

The items below come out of the 2026-07 external code review (findings
verified against the code before being recorded; the review's symlink-escape
claim was *disproven* on Linux and survives only as the Windows note below).

- [ ] **Bug — symbol collisions after renaming are undetected.**
      `apply_renames` is the last transformation pass; nothing checks final
      Odin names for uniqueness, so `glOpen`/`vkOpen` + `strip_prefixes` both
      become `Open` and the output fails `odin check` (or worse, enum members
      silently merge). `.Symbol_Collision` is registered in
      `src/diagnostics.odin` but never emitted. Design in
      [`docs/specs/0008-symbol-collision-validation.md`](docs/specs/0008-symbol-collision-validation.md)
      (proposed): scope-aware `validate_symbol_names` pass, detect-and-report,
      default severity `error`.
- [ ] **Bug — package and foreign-lib names are emitted unvalidated.**
      `emit.odin` prints `package %s` raw and `foreign import lib "system:%s"`
      unescaped; both default to the first header's filename stem, so
      `my-library.h` yields `package my-library` — invalid Odin. Validate the
      package name as a legal non-keyword identifier (sanitize the stem
      default), and validate/escape `foreign.import_lib`.
- [x] **Determinism gap — the sandbox exposes `math.random`.**
      `policy_open_sandbox_libs` opens the whole `math` library, so a callback
      can rename nondeterministically, contradicting the determinism claim.
      Fixed by nil-ing `math.random` / `math.randomseed` after `open_math`
      while leaving pure helpers (`abs`, `floor`, …) available.
- [ ] **Portability — `require` sandbox path check is lexical on Windows.**
      On Linux, `filepath.abs` resolves symlinks through an fd (verified: a
      symlink escaping the config dir is rejected) — pin that load-bearing
      behavior with a test so a `core:os` change can't silently regress it.
      On Windows, `GetFullPathNameW` is purely lexical, so a symlink/junction
      could escape. `path_is_under` also mis-rejects descendants when the
      root is `/` and compares case-sensitively on case-insensitive volumes.
- [ ] **Dead diagnostic — `naming_ambiguity` cannot fire.**
      `longest_known_at` counts equal-length exact matches at one index, but
      `known_tokens` map keys are unique, so `match_count > 1` is unreachable.
      Real ambiguity is competing segmentations (`ABC = AB+C` vs `A+BC`),
      which needs a different detection. Implement that, or retire the
      diagnostic and the doc comment promising it (`src/naming.odin`).
- [ ] **Validation gap — Lua list fields accept hybrid tables.**
      `policy_string_list_field` / `policy_string_or_list_field`
      (`src/policy_lua.odin`) only scan non-index keys when `luaL_len` is 0,
      so `{ "a.h", typo = "b.h" }` passes silently. Validate every key as a
      dense 1..n integer index, and consolidate the two near-duplicate
      parsers while there.
- [ ] **`resolve_path` silently falls back on join failure**
      (`src/main.odin`): a config-relative path degrades to cwd-relative,
      which can select the wrong header or output dir. Propagate the error
      with both path components in the message.
- [ ] **Multi-file output is not transactional.**
      `write_emit_to_config_folder` writes in sequence, so a mid-run failure
      leaves a mixed generation, and files from since-removed headers are
      never cleaned up. Render everything first, write to temp files, rename
      into place; consider a generated-file manifest for stale cleanup. Also
      document (not just in a code comment) that output is written *before*
      error-severity diagnostics are reported — builds must gate on exit
      code, not file existence.
- [ ] **Structure — deep `os.exit` in `src/policy_callbacks.odin`**
      (18 call sites): skips main's defers, makes negative callback paths
      untestable, and diverges from the `(value, ok)` style elsewhere.
      Propagate an error state and let `main` own the single exit. Shared
      pcall/error-report/stack-cleanup helpers would also collapse the
      repeated dispatch boilerplate. (Same-area trivia: `delete_int_map` /
      `delete_string_bool_map` in `src/policy_test.odin` are identical bodies
      — one generic helper suffices.)
- [ ] **Provenance — builtin headers may not match the loaded libclang.**
      `clang_resource_dir_arg` (`src/extract.odin`) shells out to whatever
      `clang` is in `PATH`, which can belong to a different LLVM than the
      linked `libclang`. Make the executable/resource-dir configurable and
      print `clang_getClangVersion()` + the chosen resource dir under
      `-verbose`.
The 2026-07 libclang usage review (extraction audited against the vendored
bindings, claims probe-verified) also settled two non-issues worth pinning so
they are not "fixed" later: **`clang_Cursor_Evaluate` returns nil for macro
definitions** on this libclang, so `src/macro_value.odin`'s literal parser is
necessary, not a reimplementation; and the **empty `Platform.odin` /
`ExternC.odin` are correct output** — those headers declare no functions
(binding coverage is exact: 427/427 across all 13 headers).

- [ ] **Bug — enum member values are captured signed-only.**
      `extract_decls.odin` stores `i64(get_enum_constant_decl_value(...))`;
      a member like `0xFFFFFFFFFFFFFFFF` in an unsigned-backed enum arrives
      as `-1` with no record of unsignedness.
      `clang_getEnumConstantDeclUnsignedValue` is already in the bindings —
      capture it (or a signedness fact from the backing type) at extraction.
- [ ] **Capture calling convention at extraction.**
      `clang_getFunctionTypeCallingConv` is unused; `__stdcall`/`__fastcall`
      in Windows headers are silently dropped. Record the fact now (cheap,
      config-independent); emission consumes it when the Windows-parity work
      (see Later) happens.
- [ ] **Flaky e2e observed (2026-07-11):**
      `test_opaque_tags_idiomatic_default_handle` once failed all four
      `expect_contains` (empty/truncated stdout?) under the 16-thread runner
      right after a rebuild; rerun and direct invocation pass. Watch for
      recurrence; suspect a process-spawn/stdout-read race in `run_h2odin`.
- [ ] **Reproducibility — no pinned Odin release, no CI.**
      Document the tested compiler (currently `dev-2026-07a` nightly via
      mise) and a minimum version; add CI running the AGENTS.md sequence
      (`make format && make check && make test && make build`) plus
      `make regen-libclang` + `git diff --exit-code` and the example
      `odin check`s.

## Later

- [ ] Milestone 6 (wrappers) when deliberately taken up — see above.
- [x] **Deprecated C declarations — propagate by default, drop on opt-in.**
      Decided in
      [`docs/specs/0009-deprecated-declarations.md`](docs/specs/0009-deprecated-declarations.md):
      Extraction records `deprecated` + message via
      `clang_getCursorAvailability` / `clang_getCursorPlatformAvailability`
      (probe-verified); Emission writes `@(deprecated = "msg")` on procs and
      types and a `Deprecated:` doc line on consts/vars (no Odin attribute
      there); `symbols.remove.deprecated = true` drops them;
      `sym.deprecated` joins the callback view. Dogfood acceptance:
      `make regen-libclang` annotates exactly the five `clang_getRemappings*`
      procs that `Index.h` marks `CINDEX_DEPRECATED` today.
- [x] **Incomplete tag records — mode default + `types.opaque` overrides**
      (sqlite3-style `typedef struct T T;` used as `T *`). Decided in
      [`docs/specs/0007-opaque-tag-records.md`](docs/specs/0007-opaque-tag-records.md):
      ABI keeps `T :: struct {}` + `^T`; idiomatic collapses to
      `T :: distinct rawptr` with one pointer level removed; `types.opaque`
      is a per-name bool override either way; forcing a complete record
      fails closed under `opaque_record_complete`.
- [ ] Curate the rest of the generated libclang surface: ~173
      `pointer_lowering_guess` warnings remain outside Extraction's call
      surface (array params like `CXUnsavedFile *` as `^Unsaved_File`,
      out-params, …). Spec 0002 scoped self-host to Extraction's needs; this
      is the follow-up polish.
- [ ] Windows multi-lib `foreign import` parity for the generated libclang
      package (the hand binding had a `when ODIN_OS` stanza; generated output
      is Unix `system:clang` only — documented out of scope in spec 0002).
- [ ] Multi-target runs (generate per target, merge).
- [ ] A license.

---

### Start here

Milestones 0–5, 7–14 are complete — including **self-hosted libclang bindings
(Milestone 13)** and **multi-file Odin emission (Milestone 14)**. Regenerate the
checked-in package with `make regen-libclang`. **Milestone 6 (wrappers)**
remains deferred and independent.

Code health items for specs 0005–0007 and deprecated-declaration propagation
(spec 0009) are done. The open Code health items from the 2026-07 review are
the current hardening backlog — start with symbol-collision validation
(spec 0008, proposed) and package-name validation, which are the two that
can produce invalid Odin today. Later items remain polish and deferred work
(wrappers, full pointer-lowering curation, Windows multi-lib, …).
