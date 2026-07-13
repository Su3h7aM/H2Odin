# Example: cgltf (validation benchmark)

Generate bindings for [cgltf](https://github.com/jkuhlmann/cgltf) and compare
with Odin's hand-written `vendor:cgltf`.

## What this exercises

- Single-header C library (header-only API surface when the implementation
  macro is not defined)
- Dense glTF scene graph: many structs with optional pointers and counts
- Nested enums (`cgltf_result`, attribute/component types, …)
- `typedef` aliases for `size_t` / `float` / `int` (`cgltf_size`, …)
- Prefix strip + `link_prefix` (`cgltf_`)

## Regenerate

```sh
./scripts/build
./build/h2odin examples/cgltf
odin check examples/cgltf -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Status

| Step | Result |
|------|--------|
| Generate | OK |
| `odin check` | **OK** |
| Foreign procs (approx.) | 36 |
| `#by_ptr` params | 4 (`options` on parse/load) |
| `@(require_results)` | 5 |

Type names keep the `cgltf_` prefix. Stripping them is deliberately disabled:
`cgltf_size` → `size` would collide with fields named `size`, and
`cgltf_image` → `image` with fields named `image`. The `symbol_collision`
diagnostic catches that if strip is enabled; the
config opts out so the package stays green without field renames.

## Gaps vs `vendor:cgltf`

- Official multi-file / wasm layout; we emit one unit
- Out-parameter wrappers (`parse`, `parse_file`, `load_buffer_base64`) are
  generated via `procs.wrappers` (faithful foreign under `_name`); vendor also
  nests private foreign blocks differently
- Remaining multipointers often stay `^T` (see regenerate diagnostics)
- Struct field pointer/count → `[]T` overlays are not generated
- Header-only static inlines are skipped (no external symbol) — by design
