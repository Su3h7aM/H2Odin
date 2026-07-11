# Vendor-library example audit — 2026-07-11

## Scope and evidence standard

This audit covers the current generator, tests, roadmap, and the recently added real-world examples derived from Odin `vendor:` libraries. It uses only repository primary sources: source, tests, checked-in headers/configs/generated bindings, project documentation, and local validation commands. Statements labelled **Direct evidence** are demonstrated by those artifacts; statements labelled **Inference** are proposed explanations or design consequences that still need a focused reproducer.

## Executive summary

The validation corpus has done its job: it shows that the core pipeline is mature on three substantial APIs, but it also exposes three correctness failures that should now outrank deferred wrapper work and most polish:

1. Pure `typedef void Name` handles can panic emission and cannot be represented coherently.
2. Naming transforms are not validated in Odin scope, allowing type/field cycles and other post-rename collisions.
3. Non-input system declarations can leak into generated output.

The checked-in status is honest: raylib, box3d, and cgltf are documented as passing; curl and miniaudio are documented as failing. The full automated suite is green, but it does not execute this vendor-example matrix. `make test` passed locally (78 unit tests and 47 e2e tests), while the example README explicitly leaves curl/miniaudio outside its `odin check` commands (`examples/README.md:11-30`). Consequently, green CI-equivalent tests do **not** imply real-world example validity.

## Validation status

| Surface | Current evidence | Status |
|---|---|---|
| Unit + e2e suite | `Makefile:48-58`; local `make test`: 78 unit and 47 e2e tests passed | Green |
| Build | `Makefile:41-43`; local `make build` passed | Green |
| raylib | Matrix says pass (`examples/README.md:51-54`) | Documented green |
| box3d | Matrix says pass (`examples/README.md:51-55`) | Documented green |
| cgltf | Generation/check are OK with official-style prefixed type names (`examples/cgltf/README.md:23-34`) | Green; separate collision reproducer needed |
| curl | Generation requires dropping opaque typedefs; generated output then fails (`examples/curl/README.md:24-48`) | Red |
| miniaudio | Generation requires dropping opaque typedefs; output still fails (`examples/miniaudio/README.md:24-46`) | Red |
| Example automation | README lists manual commands and omits checks for known-red examples (`examples/README.md:11-30`); `Makefile:34-73` has no example-validation target | Missing |

A fresh local run on 2026-07-11 built the current generator, regenerated all
eight examples, and ran `odin check -no-entry-point` against each package.
Generation completed under the checked-in workaround configs for all eight.
Checks passed for fff, sqlite3, bit_fields, raylib, box3d, and cgltf; curl and
miniaudio failed exactly as documented. Curl's first errors are the two
`sockaddr` declarations followed by unresolved `CURL`; miniaudio's first errors
are `thread: thread` / `format: format` cycles followed by unresolved dropped
opaque names. This confirms that the READMEs describe current behavior, not
only historical observations. The reproducible command shape is:

```sh
make build
for example in fff sqlite3 bit_fields raylib box3d cgltf curl miniaudio; do
    ./build/h2odin "examples/$example"
    odin check "examples/$example" -no-entry-point -collection:vendored=$(pwd)/vendored
done
```

The generated files were restored after the probe; this report records the
observed exit status, while the proposed validation target will make the result
a durable automated artifact.

### Validation caveats

- **Direct evidence:** The e2e suite checks generated Odin for focused fixtures such as bit-fields, per-header output, and opaque incomplete-record handles (`tests/e2e_test.odin:638-735`, `882-1052`).
- **Direct evidence:** Existing opaque-handle tests cover incomplete record pointers and `void *` typedefs, not pure `typedef void Name` (`tests/e2e_test.odin:987-1007`).
- **Direct evidence:** The roadmap records one observed flaky e2e run in the process runner (`ROADMAP.md:364-368`). The local run passed, so this audit neither confirms nor closes that issue.
- **Inference:** A dedicated example target should distinguish expected-green examples from expected-red regression probes. Otherwise a known failure must either be omitted or make every routine validation red.

## Validation-driven fixes already landed

- **Unsigned enum values:** change `qryrtlzo` switched unsigned-backed enum
  members to libclang's unsigned value API, so high-bit constants such as
  `0xFFFFFFFF` retain their bit pattern. The focused fixture and extraction
  assertions are in `tests/fixtures/unsigned_enum.h` and
  `src/extract_test.odin`; the roadmap records the completed fix at
  `ROADMAP.md:354-359`.
- **Distinct anonymous records:** change `ylwzkkmn` stopped interning anonymous
  records by libclang USR after Box3D's `TreeNode` showed that multiple C11
  anonymous unions in one parent can share a USR and collapse into one IR
  layout. The regression fixture is `tests/fixtures/anon_unions.h`, with the
  extraction test in `src/extract_test.odin`; the Box3D README records the
  dogfood case (`examples/box3d/README.md:49-53`).

These fixes demonstrate the intended workflow: reduce a real header failure to
a focused fixture, fix the owning stage, then retain the full library as a
regression benchmark.

## Findings

### P0 — Pure `typedef void Name` causes an emission panic and broken workaround output

**Direct evidence**

- Curl contains the pattern `typedef void CURL` and related handles; its README records an unhandled emission panic, then unresolved names after the config drops those declarations (`examples/curl/README.md:9-14`, `24-48`).
- Miniaudio has the same pattern at much larger scale and the same failure (`examples/miniaudio/README.md:9-15`, `24-46`).
- Both configs explicitly remove the typedef declarations as a workaround, not a fix (`examples/curl/H2Odin.lua:27-34`; `examples/miniaudio/H2Odin.lua:26-35`).
- The emitter panics whenever a builtin type has no ABI spelling; its comment assumes C void cannot reach this path (`src/emit_types.odin:38-54`). Pure void typedefs disprove that assumption.
- The current successful handle behavior is narrower: incomplete-record handles and selected `void *` aliases become distinct raw pointers (`ROADMAP.md:266-274`; `tests/e2e_test.odin:987-1007`).

**Impact**

This is a generator crash on valid and common C API design, not a cosmetic mismatch. Removing the declaration is unsafe because references in callback typedefs and signatures retain the named type (`examples/curl/README.md:33-38`; `examples/miniaudio/README.md:33-38`). Curl and miniaudio therefore cannot produce self-consistent bindings.

**Recommendation**

Investigate and specify this first. Extraction/IR must preserve “named opaque void type” as a semantic case rather than blindly emitting builtin `void`. Transformation should choose an explicit representation (likely a distinct handle) and consistently rewrite pointer levels and every reference. Emission must return a diagnostic/failure rather than panic even if an unsupported type reaches it. Add a minimal fixture containing a pure void typedef, direct pointer uses, callback parameters, callback returns, and pointer-to-pointer out parameters; require generation plus `odin check`.

### P0 — Post-transform Odin name collisions are not validated

**Direct evidence**

- Cgltf retains the official-style type prefixes and stays green; enabling a `cgltf_` type strip demonstrates that `cgltf_size -> size` and `cgltf_image -> image` would collide with same-named fields and create illegal declaration cycles (`examples/cgltf/H2Odin.lua:14-26`; `examples/cgltf/README.md:31-34`).
- Miniaudio actively demonstrates the failure with `format: format` and `thread: thread` after stripping `ma_` (`examples/miniaudio/README.md:13-15`, `33-44`).
- Transformation filters declarations and then applies renames as its final shown step (`src/transform.odin:43-46`).
- `symbol_collision` is registered and configurable (`src/diagnostics.odin:79-82`, `116-120`) but the roadmap states it is never emitted and proposes a scope-aware validation pass (`ROADMAP.md:280-288`).

**Impact**

This is broader than top-level duplicate declarations. Odin has scope-sensitive conflicts: a field can conflict with the type spelling used in its declaration, enum values have their own relevant scope, and separate C prefixes can collapse to one Odin name. Today configs must avoid or manually resolve these cases without the generator reliably detecting them.

**Recommendation**

Promote proposed spec 0008 implementation to P0 alongside void handles. Validate the *final* transformed names and emitted scopes, before output is written. Include at least:

- top-level declaration collisions after strip/override/keyword handling;
- record field versus referenced type self-cycles;
- duplicate field names after callbacks/recasing;
- enum member collisions in the emitted scope;
- synthesized macro enum/bit-set names;
- per-header output (same package means cross-file top-level collisions still matter).

Default `symbol_collision` to error and ensure no files are written for a predictable validation error. A conservative automatic fallback (retain the original prefix) could be considered later; detection should land first.

### P0/P1 — Curl combines a post-rename package collision with foreign-type provenance leakage

**Direct evidence**

- The configured input declares `struct curl_sockaddr`, whose `addr` field is the transitively referenced system type `struct sockaddr`; the callback then takes `struct curl_sockaddr *` (`examples/curl/include/curl.h:428-441`).
- Curl's naming policy strips `curl_` from type names (`examples/curl/H2Odin.lua:18-24`). Therefore the input-owned `struct curl_sockaddr` is renamed to the Odin top-level name `sockaddr`.
- The generated first declaration at `examples/curl/curl.odin:204-213` is that renamed `curl_sockaddr`: its fields (`family`, `socktype`, `protocol`, `addrlen`, `addr`) match `examples/curl/include/curl.h:428-436`.
- Resolving its `addr: struct sockaddr` field also captures and emits the foreign/system `struct sockaddr` transitively as a second top-level `sockaddr` (`examples/curl/curl.odin:215-218`).
- The result is one package-scope name occupied twice, and the first record's `addr: sockaddr` spelling is ambiguous/self-referential in the invalid generated package (`examples/curl/curl.odin:204-220`).
- Curl's config has only `include/curl.h` in `config.inputs`; the system declaration is not an intended input-owned declaration (`examples/curl/H2Odin.lua:12-13`).
- The generator registers configured input headers for provenance (`src/extract.odin:61-65`; `src/ir.odin:401-404`, `434-443`). Focused tests prove the intended distinction: sibling configured inputs retain typedef identity while a non-input included typedef is peeled and not emitted (`tests/e2e_test.odin:408-442`).
- The roadmap records general post-rename collision detection as missing (`ROADMAP.md:280-288`) and now promotes both that work and curl's external-type provenance problem into Milestone 15 (`ROADMAP.md:376-436`).

**Classification**

This is **two defects exposed by one header relationship**, not merely “two system declarations”:

1. **Post-rename package collision:** input-owned `curl_sockaddr` becomes `sockaddr` after prefix stripping, colliding with another emitted top-level name.
2. **Foreign-type provenance/capture defect:** the referenced system `struct sockaddr` is materialized into the generated package even though its home is outside `config.inputs`.

Fixing only collision validation would make the run fail safely but would not restore the intended input boundary. Fixing only provenance would remove this particular collision but would leave equivalent post-transform collisions undetected elsewhere.

**Inference**

The narrow non-input typedef fixture passes, so the likely missing guard is on a recursive declaration-materialization path used while resolving a record field (or on placeholder-to-definition promotion). The evidence establishes the transitive relationship but does not yet identify the exact capture function.

**Recommendation**

Create a reduced fixture where an input-owned `struct lib_sockaddr` contains a foreign `struct sockaddr` and naming strips `lib_`. Trace direct traversal, record-field resolution, typedef targets, callbacks, and placeholder replacement. Require that foreign declarations are lowered/referenced through an explicit external strategy or rejected—never silently appended to output order. Independently, final-name validation must report the two C origins and their common transformed Odin name before writing output.

### P1 — Example validation is manual and known-red cases are not regression-tested

**Direct evidence**

- The examples documentation provides manual generation/check commands (`examples/README.md:11-30`).
- `Makefile` exposes source checks, build, unit/e2e tests, formatting, and libclang regeneration, but no vendor-example validation target (`Makefile:34-73`).
- The main matrix explicitly records three passing and two failing vendor benchmarks (`examples/README.md:51-57`).
- The roadmap notes there is no CI or pinned Odin release (`ROADMAP.md:370-375`).

**Impact**

Checked-in generated outputs and README status can drift from generator behavior. The most valuable newly discovered failure patterns are not guarded by automated minimal tests. Manual regeneration can also modify large output files before a reviewer sees the meaningful behavioral delta.

**Recommendation**

Add two layers after the P0 investigations establish expected behavior:

1. Small deterministic e2e fixtures for each bug pattern, run in `make test`.
2. An example-validation target that regenerates to temporary directories and checks expected-green packages. Keep expected-red probes as explicit tests for their known diagnostic/nonzero behavior until fixed.

Pin the tested Odin version before making full-corpus checks a merge gate.

### P1 — Pointer/callback curation remains a practical quality gap

**Direct evidence**

- Cgltf's README says multipointers often remain `^T` (`examples/cgltf/README.md:36-40`).
- Miniaudio reports many pointer-lowering diagnostics at scale (`examples/miniaudio/README.md:24-31`).
- The roadmap records approximately 173 remaining libclang pointer-lowering warnings and defers full-API curation (`ROADMAP.md:486-490`).
- Wrapper conversions remain deliberately deferred and require faithful foreign declarations plus generated wrappers (`ROADMAP.md:60-72`).

**Inference**

The vendor corpus supports improving facts and diagnostics for common pointer patterns, but it does not justify pulling the entire wrapper milestone forward. Many bindings can compile faithfully with conservative pointers; crashes and invalid Odin are more urgent.

**Recommendation**

Keep wrappers deferred. After P0 correctness work, classify repeated callback/out-parameter patterns from cgltf/miniaudio and improve diagnostics or config ergonomics without changing ABI arity. Use vendor hand bindings as evidence for targeted config curation, not as proof of a universal heuristic.

### P1 — Calling convention capture should move ahead of Windows output work

**Direct evidence**

- Curl exercises platform callbacks and its comparison notes calling-convention curation (`examples/curl/README.md:50-54`).
- The roadmap states `clang_getFunctionTypeCallingConv` is unused and `__stdcall`/`__fastcall` are silently dropped (`ROADMAP.md:360-363`).
- Windows multi-library import parity is separately deferred (`ROADMAP.md:491-493`).

**Recommendation**

Capture calling convention as an extraction fact now, as the roadmap suggests. Emission policy can remain deferred, but silently discarding the fact makes future Windows correctness harder and can affect callback ABI independently of multi-lib imports.

### P2 — Failure atomicity and provenance diagnostics remain relevant to a larger corpus

**Direct evidence**

- Multi-file writes are sequential, non-transactional, and do not clean stale files; diagnostics with error severity are reported after output (`ROADMAP.md:324-331`).
- The e2e test explicitly asserts that an error-severity pointer diagnostic still emits output before failing (`tests/e2e_test.odin:221-235`).

**Impact**

Large examples amplify the risk of mixed generations and stale declarations. This does not explain the current parser/emitter gaps, but it complicates validation and can make a failed regenerate look usable.

**Recommendation**

Prioritize after invalid-output blockers. Render and validate all units before writes, then atomically replace generated files using a manifest. Document exit-code gating until that work lands.

## Ordered closure plan

The sequence below is ordered by dependency and by the shortest path from crashing/invalid output to a trustworthy green corpus.

1. **Freeze minimal red fixtures and baselines.** Add reduced fixtures for (a) pure `typedef void Name` through ordinary and callback signatures, (b) a type/field post-rename cycle, and (c) input-owned `lib_sockaddr` containing foreign `struct sockaddr`. Until fixes land, assert structured failure/diagnostic behavior rather than a panic or unreviewed malformed output.
2. **Eliminate the pure-void panic and design named opaque-void semantics.** Preserve the named type in IR, define ABI and idiomatic representations, rewrite every nested reference coherently, and make unsupported emission return a diagnostic instead of panicking. This unblocks both curl and miniaudio.
3. **Implement final-name, scope-aware validation (spec 0008).** Run after all transformations and before output planning/writes. Cover package names, record fields, enum members, proc parameters, synthesized declarations, and field-versus-referenced-type cycles. Default `symbol_collision` to error and report original C names plus final Odin scope/name.
4. ~~**Fix foreign declaration provenance/capture.**~~ **Done (spec 0010).**
   The ownership rule turned out *not* to be `config.inputs` membership: a
   library's own headers reached through an umbrella input are still its own
   (Box3D lists only `box3d.h`). Foreignness is what libclang reports —
   declared in a system header. Foreign declarations are captured pool-only
   and never emitted with a system layout; curl keeps its own `curl_sockaddr`
   and no longer leaks `struct sockaddr`.
5. ~~**POSIX / libc mapping.**~~ **Done (spec 0010):**
   [`docs/specs/0010-posix-libc-type-mapping.md`](specs/0010-posix-libc-type-mapping.md).
   System compounds (`sockaddr`) and named POSIX/libc scalars map to
   `posix.*` / `libc.*` through the **defining package**, one spelling in both
   modes; dual ABI/idiomatic stays ISO-C-only (`std_mappings`); `types.map`
   beats the built-in map. Curl now emits `addr: posix.sockaddr`, matching the
   hand-written `vendor:curl`.
6. **Turn the reduced red fixtures green.** Require generation without workarounds, no panic, no dangling names, correct diagnostics, and `odin check`. Keep focused tests separate enough to identify which layer regressed.
7. **Close real examples in dependency order.** Keep cgltf green in its official-style prefixed configuration while a reduced fixture verifies the conflicting strip is diagnosed; then close curl (remove the pure-void deletion workaround and verify provenance); then close miniaudio (remove the pure-void deletion workaround and resolve all naming scopes at scale). Reconfirm raylib and box3d after each shared naming/type change.
8. **Automate the full acceptance matrix.** Add a Make target that regenerates into temporary locations, compares or reviews deterministic output, and runs `odin check` for every expected-green example. Pin the Odin version and add CI before making this a required merge gate (`ROADMAP.md:370-375`).
8. **Capture calling conventions as extraction facts.** Do this before Windows parity, then add targeted callback ABI tests. It need not block the initial Linux green matrix unless an example requires a non-default convention.
9. **Curate pointer/callback shapes and diagnostics.** Improve faithful ABI usability without pulling forward arity-changing wrappers.
10. **Harden output transactions.** Render and validate all units before atomic replacement; add stale-file cleanup/manifest behavior.
11. **Keep Milestone 6 wrappers deferred.** None of the closure blockers requires slice/string wrappers (`ROADMAP.md:60-72`).

This order is now reflected directly in Roadmap Milestone 15 (`ROADMAP.md:376-464`): package-name validation is already fixed (`ROADMAP.md:289-295`), while pure-void handles have stronger evidence—a deterministic generator panic and two red benchmark packages.

## Example acceptance matrix

“Accept” below is the closure bar, not merely the currently documented status.

| Example | Current baseline | Required acceptance | Blockers/notes |
|---|---|---|---|
| `fff` | Development fixture; manual generate/check command is documented (`examples/README.md:14`, `23`) | Regenerate deterministically; `odin check`; retain `foreign.link_prefix`, prefix stripping, and configured `cstring` spellings | Regression sentinel for basic naming/config behavior; no newly discovered blocker |
| `sqlite3` | Development fixture with large header, macro groups, and incomplete-tag opaque handles (`examples/README.md:41`) | Regenerate deterministically; `odin check`; incomplete-tag handles remain distinct/coherent; macro groups remain valid | Guards against pure-void work regressing the already-supported incomplete-record handle path |
| `bit_fields` | Development fixture for proven bit-field layout (`examples/README.md:42`) | Regenerate; `odin check`; layout assertions remain green; unsupported layouts still fail closed with diagnostics | Guards layout/ABI behavior independent of vendor examples |
| `raylib` | Repository-documented pass (`examples/README.md:51-54`) | Regenerate and `odin check`; preserve configured math shapes and PascalCase API; no new collision/provenance diagnostics | Production parity (OS libs, wrappers, extra modules) is explicitly not required (`examples/raylib/README.md:30-42`) |
| `box3d` | Repository-documented pass (`examples/README.md:51-55`) | Regenerate and `odin check`; preserve `b3` strip/link-prefix behavior, handles, and math overrides; anonymous-union regression stays fixed | Topic-split output and hand-written helpers are not closure requirements (`examples/box3d/README.md:36-53`) |
| `cgltf` | Passes with official-style type prefixes retained (`examples/cgltf/README.md:23-34`) | Regenerate deterministically and `odin check`; a separate reduced fixture that enables the conflicting strip must produce a clear error rather than illegal Odin | Retaining `cgltf_` type names is valid reference parity, not itself a defect; missing collision detection is the defect |
| `curl` | Generation panics without opaque workaround; workaround output fails (`examples/curl/README.md:24-48`) | Remove `CURL`/`CURLM`/`CURLSH` deletion workaround; no panic or dangling handle names; input-owned `curl_sockaddr` and foreign `struct sockaddr` do not become duplicate package `sockaddr`; final output `odin check`s | Requires pure-void semantics, nested reference rewriting, final-name validation, and foreign provenance fix |
| `miniaudio` | Generation panics without workaround; workaround output fails on dangling opaques and naming cycles (`examples/miniaudio/README.md:24-46`) | Remove pure-void deletion workaround; no dangling names; all final naming scopes validate; no `format: format`/`thread: thread` illegal cycles; deterministic generation at full-header scale; `odin check` | Strongest scale/stress acceptance; pointer warnings may remain if actionable and non-fatal |
| Generated libclang | Self-hosted package and regeneration are roadmap-complete (`ROADMAP.md:168-226`) | `make regen-libclang`; package `odin check`; source test suite remains green; generated diff deterministic | Must be rerun because handle/naming/provenance changes touch shared extraction and transformation paths |
| Whole project | Local audit run: `make test` passed 78 unit + 47 e2e tests; build passed | `make format`, `make check`, `make test`, `make build`, full example target, and deterministic libclang regeneration under pinned compiler | CI/version pin remains required before claiming reproducible closure (`ROADMAP.md:370-375`) |

### Cross-example acceptance invariants

Every example accepted as green must satisfy all of the following:

- Generation exits normally—no panic—and error diagnostics produce a nonzero exit before publishing accepted output.
- Every emitted named type resolves; filtering a declaration cannot leave dangling nested references.
- Final Odin names are unique and legal in their actual scope, including field/type resolution.
- Only declarations with an explicit ownership/external-type strategy enter the generated package; transitive foreign declarations are not silently promoted.
- `odin check -no-entry-point` passes with the repository's vendored collection where needed.
- Regeneration is deterministic under the pinned Odin/libclang toolchain.
- Remaining differences from hand-written `vendor:` packages are documented as scope/curation gaps, not ABI correctness failures.

## Patterns the corpus now requires H2Odin to handle

| Header pattern | Example | Required behavior |
|---|---|---|
| `typedef void Name;` followed by `Name *` | curl, miniaudio | Named opaque representation; coherent pointer peeling; no panic |
| Opaque name inside callback typedefs | curl, miniaudio | Preserve/rewrite all nested references when declaration representation changes |
| Prefix-stripped type equals field name | cgltf, miniaudio | Detect final Odin-scope cycle before emission; diagnose or safely disambiguate |
| Included platform record referenced by API | curl (`sockaddr`) | Do not emit non-input declarations accidentally; preserve a coherent external/lowered type |
| Platform callback calling conventions | curl / Windows-facing APIs | Capture convention in IR even before emission support |
| Large pointer-rich single header | miniaudio | Bounded, actionable diagnostics; no crash; deterministic validation |

## Conclusion

The recently added vendor examples are not merely demonstrations; they expose correctness boundaries absent from focused fixtures. Three of five benchmark packages are green, proving useful breadth. The two failures share a concrete opaque-void defect, while cgltf and miniaudio jointly demonstrate that final Odin name validation is a correctness requirement rather than naming polish. The next work should therefore close crash/invalid-output paths and automate these discoveries before expanding into wrappers or broad stylistic parity with hand-written vendor packages.
