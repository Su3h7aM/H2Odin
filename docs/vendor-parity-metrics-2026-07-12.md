# Vendor declaration-level parity metrics — 2026-07-12

Counts the **foreign procedure surface** after curated configs for multi-pointer,
`require_results`, and idiomatic `#by_ptr`. These are **declaration-level**
metrics on generated packages, not helper/module/wrapper counts from official
`vendor:` trees (spec 0011 levels 2 vs 3).

Regenerate with `./scripts/validate-examples` (nine gate packages including
ggml). Measured after that gate's generator + configs.

## Table

| Package | Foreign procs¹ | `[^]T` sites | `#by_ptr` params | `@(require_results)` procs | Notes |
|---------|---------------:|-------------:|-----------------:|---------------------------:|-------|
| raylib | 600 | 3 | 0 | 12 | Multi on icon/glyph/anim arrays; loaders required. No `#by_ptr` on this surface. |
| box3d | 417 | 0 | 5 | 5 | `#by_ptr` on CreateWorld / Create*Shape defs (+ sphere/capsule geometry). Input is umbrella `box3d.h` only. |
| cgltf | 36 | 0 | 4 | 5 | `#by_ptr options` on parse/load; result codes required. Types keep `cgltf_` prefix. |
| curl | 41 | 0 | 0 | 7 | Only decls whose **home** is `include/curl.h` are emitted. easy/multi/urlapi live in sibling headers and are not "ours" without listing them (they cannot parse alone). |
| miniaudio | 931 | 2 | 5 | 9 | `#by_ptr` on device/context/decoder/encoder config; multi on backend arrays. |
| ggml | 612 | 6 | 0 | 0 | Dual-prefix: strip `ggml_`, keep `gguf_*` Odin names; kind-aware renames for tag/proc collisions. |

¹ Approx. count of `Name :: proc(` forms in the merged package (includes
callback typedefs where present; foreign `---` decls dominate for large APIs).

## What is intentionally not counted

- Official `vendor:` packages' hand-written helpers, math reimplementations,
  OS multi-lib `when` trees, and wrapper procedures (spec 0011 level 3 /
  library-specific code).
- Diagnostic volume (`pointer_lowering_guess`, etc.) — quality signal, not a
  parity score.
- Palette constants, static inlines, and macros without linkable symbols.

## Config keys used

- `config.procs.params["CName.param"] = { pointer = "multi" }` → `[^]T`
- `config.procs.params["CName.param"] = { by_ptr = true }` → `#by_ptr` (idiomatic only)
- `config.procs.require_results = { "CName", … }` → `@(require_results)`

## Residual gaps (honest)

1. **curl easy/multi API** — umbrella `curl.h` includes sibling headers, but
   extraction only binds decls from paths listed in `config.inputs`. Expanding
   the input surface without a parse-order amalgam is future work.
2. **Default `^T` multipointers** — most array-shaped `T*` still lower to `^T`
   until explicit `pointer = "multi"` (or future array-decay automation).
3. **ggml** has no `require_results` / `#by_ptr` curation yet; the gate proves
   dual-prefix naming + type references only.
4. **Calling conventions** on this corpus are all the C default; non-C
   conventions are covered by unit/e2e fixtures, not these packages.
