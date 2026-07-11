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
make build
./build/h2odin examples/cgltf
odin check examples/cgltf -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Status (present capabilities)

| Step | Result |
|------|--------|
| Generate | OK (~0.04s) |
| `odin check` | **OK** with current config |
| Proc count (approx.) | ~36 foreign procs |

Type names keep the `cgltf_` prefix. Stripping them is deliberately disabled:
`cgltf_size` → `size` collides with fields named `size`, and `cgltf_image` →
`image` collides with fields named `image`, producing illegal Odin declaration
cycles. That collision mode is recorded on the ROADMAP as needing investigation.

## Gaps vs `vendor:cgltf`

- Official multi-file / wasm layout; we emit one unit
- Pointer multipointers often stay `^T` (see regenerate diagnostics)
- Header-only static inlines are skipped (no external symbol) — by design
