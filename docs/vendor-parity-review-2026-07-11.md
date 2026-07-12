# Vendor-binding parity review — 2026-07-11

## Purpose

This review turns the validation audit and the current pinned Odin vendor
bindings into an implementation boundary. It decides which recurring vendor
patterns belong in H2Odin, which belong only in idiomatic mode, and which remain
hand-written library code.

The target is close parity in correctness and recurring FFI ergonomics, not
line-for-line reproduction of maintained packages.

## Evidence base

Primary project evidence:

- `src/extract*.odin`, `src/analyze.odin`, `src/transform*.odin`,
  `src/emit*.odin`, and the focused/e2e tests;
- the checked-in generated examples and their Lua policies;
- specs 0001–0010, the historical vendor audit, and the roadmap;
- Odin `dev-2026-07a` under
  `/home/su3h7am/.local/share/mise/installs/odin/dev-2026-07a/bin`;
- the official `vendor:raylib`, `vendor:box3d`, `vendor:cgltf`, `vendor:curl`,
  and `vendor:miniaudio` sources in that tree.

Official language documentation:

- [Foreign system](https://odin-lang.org/docs/overview/#foreign-system)
- [Multi-pointers](https://odin-lang.org/docs/overview/#multi-pointers)
- [`cstring`](https://odin-lang.org/docs/overview/#cstring-type)
- [`#type`](https://odin-lang.org/docs/overview/#type)
- [Binding to C](https://odin-lang.org/news/binding-to-c/)

Observed current baseline:

- `./scripts/check` and `./scripts/build` pass.
- Unit tests: 82 pass.
- E2e tests: 57 pass.
- Checked generated packages for fff, sqlite3, bit_fields, raylib, Box3D,
  cgltf, curl, and miniaudio pass `odin check`.
- The separate ggml stress example fails `odin check` with unresolved renamed
  types, package redeclarations, and parameter/type shadowing; it is not part of
  `./scripts/validate-examples`.

## Current generator boundary

The current pipeline already supplies a broad faithful core:

- libclang extraction of functions, callbacks, records/unions, enums,
  typedefs, globals, object-like literal macros, comments, deprecation,
  measured layouts, system provenance, and calling-convention facts;
- analysis of length-like neighbours;
- ABI/idiomatic leaf spelling, pointer lowering, opaque handles, foreign
  POSIX/libc mapping, macro grouping, enum/bit-set transforms, struct/proc
  spelling overrides, naming, filtering, and final-name validation;
- merged/per-header emission, bit-field layout proof, imports, foreign blocks,
  deprecation attributes, and diagnostics.

The main parity gaps are not missing C declaration kinds. They are facts that
do not yet reach output (calling conventions and target linkage), recurring
foreign-surface curation, and selected call-shape wrappers.

## What official vendor bindings repeatedly do

### Platform and ABI patterns

| Pattern | Official evidence | Current H2Odin |
|---|---|---|
| OS/architecture library selection | raylib `raylib.odin:99-147`; Box3D `box3d.odin:10-37`; cgltf `cgltf.odin:5-26`; curl `curl.odin:5-31`; miniaudio `common.odin:5-19` | One `system:<name>` string |
| Platform-owned type aliases | curl `curl_posix.odin:6-7`, `curl_windows.odin:6-7` | Unix POSIX/libc map; Windows strategy absent |
| Correct calling conventions | foreign docs; vendor foreign blocks and callback types | Captured in IR; all emitted as `"c"` |
| Foreign-block metadata | `default_calling_convention`, `link_prefix`, `require_results` throughout all five packages | `link_prefix` only; per-decl `link_name` and deprecation supported |
| Array pointers as `[^]T` | cgltf, Box3D, raylib, miniaudio signatures | Unknown `T *` defaults to `^T`; explicit raw spelling override available |
| `cstring` for NUL-terminated input | all five packages | Automatic only for `const char *`; explicit overrides cover documented mutable strings |

Calling conventions and target linkage are correctness requirements. The
remaining rows are ABI-identical curation when their semantic preconditions
are known.

### Wrapper patterns

The clearest general wrapper pattern is in `vendor:cgltf`:

- `parse`, `parse_file`, and `load_buffer_base64`
  (`cgltf.odin:648-681`) retain local faithful foreign declarations;
- output pointer parameters become named Odin results;
- the original C status remains a result;
- wrappers are marked `require_results`.

This pattern is mechanical once policy identifies the out-parameter. It is
therefore part of the initial idiomatic wrapper set.

Pointer-plus-count input slices are also recurring and mechanically lowered:
the wrapper supplies `raw_data(slice)` and `len(slice)` to a retained pointer
and count declaration. Odin's docs establish that `[]T` is pointer plus length
and `raw_data` yields `[^]T`; this cannot be emitted directly as a one-parameter
replacement inside a foreign declaration.

Selected `#by_ptr` parameters recur heavily in Box3D and appear in cgltf. They
are not automatically derivable from `const T *`: constness does not prove
non-nullness or that the callee will not retain the pointer. This is an
explicit idiomatic policy action, not an ABI default.

### Library-specific helper patterns

The following official helpers are useful but not general binding-generator
features:

- Box3D ID predicates/serialization and large pure-math layer
  (`box3d_id.odin`, `box3d_math.odin`);
- raylib `TextFormat`, allocator adapter, and overload group
  (`raylib.odin:1784-1860`);
- miniaudio version checks and arithmetic helpers;
- palette/config constants not represented as usable header literals;
- translations of C static-inline bodies and function-like macros;
- additional modules outside the configured header surface (`raymath`,
  `raygui`, `rlgl`, easings).

These procedures carry domain semantics, allocation policy, or manually
translated algorithms. They stay in same-package hand-written Odin files or
footer files.

The pinned vendor tree is evidence, not an infallible generated oracle. The
inspected raylib arm64 static branch names `linux-arm/libraylib.a`, while the
shipped file is under `linux-arm64/`; several Box3D, cgltf, and miniaudio local
library paths referenced by source are absent until those libraries are built.
Parity therefore follows the language contract and recurring maintained
patterns, while target checks verify the concrete generated result.

## Required feature classification

| Feature | Classification | Mode | Priority |
|---|---|---|---|
| Emit captured direct/callback calling conventions | ABI correctness | Both | P0 |
| Structured OS/architecture foreign libraries and system dependencies | ABI/package correctness | Both | P1 |
| Windows defining-package foreign types and aliases | ABI/layout correctness | Both | P1 |
| Transactional output + stale-file tracking | Generation correctness | Both | P1 |
| Explicit/proven `[^]T` | Foreign-surface curation | Both; conservative default unchanged | P2 |
| `require_results` | Foreign-surface metadata | Both | P2 |
| `#by_ptr` | Call-shape curation without body | Idiomatic only, explicit | P2 |
| Out-parameter → named result wrapper | General ergonomic wrapper | Idiomatic only | P3 / Milestone 6 first |
| Pointer + count → input slice wrapper | General ergonomic wrapper | Idiomatic only | P3 / Milestone 6 second |
| Borrowed pointer/count output → slice | Lifetime-sensitive wrapper | Idiomatic only, later | Deferred |
| Struct pointer/count fields → slice | Whole-layout structural transform | Idiomatic only, later | Deferred |
| `string` ↔ `cstring` wrapper | Allocation/ownership-sensitive | Idiomatic only, separate spec | Deferred |
| `#type` on callback aliases | Documentary only | Either | Optional |
| Static-inline/function-like macro translation | C body translation | Neither core mode | Out of scope |
| Math, allocator, formatter, ID, and module-specific helpers | Library domain code | Hand-written layer | Out of scope |

## Mode contract

### ABI mode

ABI mode is the reference foreign surface:

- no generated procedure bodies;
- no arity changes;
- explicit C pointer levels and conservative `^T` fallback;
- `core:c`/defining-package types and measured layouts;
- correct symbol, calling convention, target library, and platform type;
- ABI-identical `[^]T` only when declaration evidence or explicit policy
  establishes array semantics.

### Idiomatic mode

Idiomatic mode contains the same faithful ABI declaration and may add:

- proven native leaf spellings and existing opaque-handle shapes;
- explicit `#by_ptr` call-borrowed inputs;
- generator-authored out-result wrappers;
- generator-authored pointer/count input-slice wrappers.

Policy selects semantic conversions. The generator owns names, temporaries,
statements, imports, and output text.

## Bugs and inconsistencies identified

1. `Calling_Conv` is extracted for procedures and callback types, but
   `write_type` and `emit_func` always write `"c"`. The IR comment acknowledges
   that emission is pending.
2. The existing single-library configuration cannot represent the official
   packages' target-specific static/shared/system dependencies.
3. Spec 0010 deliberately defers Windows foreign-type emission, leaving close
   curl/platform parity Unix-only.
4. `docs/type-modes.md` previously said a full slice could be selected as
   pointer lowering. A slice is two words and requires a wrapper; the document
   now distinguishes `[^]T` from `[]T`.
5. `docs/configuration.md` listed a shortened Transformation order that omitted
   opaque/foreign handling, member adjustments, and final-name validation. It
   now matches `src/transform.odin`.
6. The vendor audit described curl/miniaudio as current failures after those
   failures had been fixed. It is now explicitly marked as a historical
   discovery record.
7. The roadmap called Milestone 15 the current priority after its exit gate was
   complete. Milestone 16 is now the next priority.
8. The old Milestone 6 included generic `cstring -> string` conversion without
   an allocation/lifetime contract. It is removed from the initial wrapper set.
9. `naming_ambiguity` remains documented in code health as unreachable under
   the current tokenizer implementation.
10. Multi-file output remains non-transactional and stale generated files are
    not tracked.
11. The clang resource directory comes from `clang` on `PATH`, which may not
    match the linked libclang.
12. Policy callbacks still contain deep `os.exit` paths that skip top-level
    cleanup and reduce negative-path testability.

## Prioritized implementation plan

### Phase 1 — ABI facts (P0)

1. Map IR calling conventions to Odin spellings for direct procedures and
   procedure types.
2. Diagnose unsupported/unknown non-default conventions as errors.
3. Add direct and callback fixtures for cdecl/stdcall/fastcall and an
   unrepresentable case.
4. Expose linked libclang version and resource-directory selection under
   verbose output; add explicit override.

### Phase 2 — Target linkage and publication (P1)

1. Implement the closed `foreign.targets` schema from spec 0011.
2. Render deterministic target `when` branches and ordered dependencies.
3. Add Windows defining-package mappings/aliases required by curl and the next
   Windows corpus.
4. Render every output unit before publication, replace atomically, and remove
   stale generated files through a manifest.
5. Validate Linux and Windows target packages.

### Phase 3 — Faithful-surface curation (P2)

1. Add structured multi-pointer selection; preserve `^T` as the unknown
   default.
2. Add `require_results` selection and compact block emission.
3. Add explicit idiomatic `#by_ptr` with non-null/call-borrowed validation.
4. Curate recurring declarations in the five official-comparison examples.
5. Resolve ggml's known-red naming/type-reference failures and add it to the
   corpus gate.

### Phase 4 — Idiomatic wrappers (Milestone 6)

1. Add wrapper-plan IR and tests at the Transformation seam.
2. Retain faithful foreign declarations and emit out-parameter-result wrappers.
3. Add pointer/count input-slice wrappers with checked count conversion.
4. Integrate naming, collisions, imports, comments, diagnostics, output
   placement, and determinism.
5. Reproduce the three cgltf wrapper patterns through config.

### Phase 5 — Evidence-driven later work

1. Define lifetime vocabulary before borrowed output slices.
2. Require whole-record proof before struct pointer/count folding.
3. Specify allocation/ownership before generic string wrappers.

## Files changed by this review

- `docs/specs/0011-vendor-parity-and-idiomatic-wrappers.md`
- `docs/vendor-parity-review-2026-07-11.md`
- `docs/type-modes.md`
- `docs/config-spec.md`
- `docs/configuration.md`
- `docs/vendor-example-audit-2026-07-11.md`
- `docs/README.md`
- `CONTEXT.md`
- `README.md`
- `ROADMAP.md`

No implementation code is changed by this review.
