# Examples

Example headers and Lua configs used while developing and **validating** H2Odin.

Each example contains the source header(s), an `H2Odin.lua` config, and the
generated Odin binding. Headers and output live in the config
(`config.inputs`, `config.output_folder`); the CLI takes the project
directory and loads `H2Odin.lua`.

## Regenerate and check (corpus gate)

```sh
./scripts/validate-examples
```

That target rebuilds `build/h2odin`, regenerates every **gate** package below,
runs `odinfmt` on `examples/`, and `odin check`s them. Equivalent manual loop:

```sh
./scripts/build
for ex in fff sqlite3 bit_fields raylib box3d cgltf curl miniaudio ggml; do
  ./build/h2odin "examples/$ex"
  odin check "examples/$ex" -no-entry-point -collection:vendored=$(pwd)/vendored
done
```

Configs default to idiomatic mode where noted. Generated declarations keep
the C ABI while using native Odin spellings where H2Odin can prove they are
equivalent on the target. Curated packages also exercise `pointer = "multi"`,
`procs.require_results`, idiomatic `#by_ptr`, and selected wrappers.

## Development fixtures

| Example | Highlights |
|---------|------------|
| `fff` | `foreign.link_prefix` + `naming.strip_prefixes`; field/param `cstring` overrides |
| `sqlite3` | large real header; `types.map`; `macros.groups` for SQLITE_* families; opaque handles |
| `bit_fields` | bit-field layout proof / emission |

## Validation benchmarks

These target Odin's hand-written **`vendor:`** packages as high-quality
references. The goal is not byte-identical output, but practical bindings
that pass `odin check` and match naming and shape where the generator can do
so without inventing library semantics.

| Example | Official reference | Role | `odin check` |
|---------|-------------------|------|--------------|
| [`raylib`](raylib/) | `vendor:raylib` (6.0) | Large C API, PascalCase, math overrides, multi/require_results | pass |
| [`box3d`](box3d/) | `vendor:box3d` | Topic-split roots, prefix strip + handles, `#by_ptr` defs | pass |
| [`cgltf`](cgltf/) | `vendor:cgltf` | Single-header scene graph, `#by_ptr options` | pass |
| [`curl`](curl/) | `vendor:curl` | Vendor-like multi-root split, `typedef void` opaques, POSIX types | pass |
| [`miniaudio`](miniaudio/) | `vendor:miniaudio` | ~95k-line single-header, multi/`#by_ptr`/require_results | pass |
| [`ggml`](ggml/) | [ggml-org/ggml](https://github.com/ggml-org/ggml) | Multi-header tensor API, dual `ggml`/`gguf` prefixes | pass |

“Functional” for this corpus means: generation does not panic; every emitted
type resolves; final names are valid in their Odin scopes; transitive foreign
declarations follow an explicit policy; and the package passes `odin check`.
Byte-for-byte parity and library-specific hand-written helpers are not part of
that gate.

When a regenerate diverges from the official package in a new way, prefer
fixing the generator or documenting the intentional choice in that example's
README over papering over it in the config alone.
