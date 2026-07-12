# Examples

Example headers and Lua configs used while developing and **validating** H2Odin.

Each example contains the source header(s), an `H2Odin.lua` config, and the
generated Odin binding. Headers and output live in the config
(`config.inputs`, `config.output_folder`); the CLI takes the project
directory and loads `H2Odin.lua`.

## Regenerate and check (Milestone 15 gate)

```sh
./scripts/validate-examples
```

That target rebuilds `build/h2odin`, regenerates every package below, runs
`odinfmt` on `examples/`, and `odin check`s all eight packages. Equivalent
manual loop:

```sh
./scripts/build
for ex in fff sqlite3 bit_fields raylib box3d cgltf curl miniaudio; do
  ./build/h2odin "examples/$ex"
  odin check "examples/$ex" -no-entry-point -collection:vendored=$(pwd)/vendored
done
```

Configs default to idiomatic mode where noted. That means generated
declarations keep the C ABI while using native Odin spellings where H2Odin
can prove they are equivalent on the target.

## Development fixtures

| Example | Highlights |
|---------|------------|
| `fff` | `foreign.link_prefix` + `naming.strip_prefixes`; field/param `cstring` overrides |
| `sqlite3` | large real header; `types.map`; `macros.groups` for SQLITE_* families; opaque handles |
| `bit_fields` | bit-field layout proof / emission |

## Validation benchmarks

These target Odin's hand-written **`vendor:`** packages as high-quality
references. The goal is not byte-identical output, but *practical* bindings
that `odin check`, match naming/shape where the generator can, and document
remaining intentional gaps in each example README.

| Example | Official reference | Role | `odin check` |
|---------|-------------------|------|--------------|
| [`raylib`](raylib/) | `vendor:raylib` (6.0) | Large C API, PascalCase, math overrides | pass |
| [`box3d`](box3d/) | `vendor:box3d` | Prefix strip + handles, multi-header umbrella | pass |
| [`cgltf`](cgltf/) | `vendor:cgltf` | Single-header, pointer-rich scene graph | pass |
| [`curl`](curl/) | `vendor:curl` | Multi-header, `typedef void` opaques, POSIX types | pass |
| [`miniaudio`](miniaudio/) | `vendor:miniaudio` | ~95k-line single-header stress, callbacks | pass |

“Functional” for this corpus means: generation does not panic; every emitted
type resolves; final names are valid in their Odin scopes; transitive foreign
declarations follow an explicit policy (spec 0010); and the package passes
`odin check`. Byte-for-byte parity, hand-written helpers, wrappers, and full
pointer curation are not part of that gate.

When a regenerate diverges from the official package in a new way, prefer
fixing the generator (in a dedicated change) or documenting the gap in that
example's README over papering over it in the config alone.
