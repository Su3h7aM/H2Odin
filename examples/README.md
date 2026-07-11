# Examples

Example headers and Lua configs used while developing and **validating** H2Odin.

Each example contains the source header(s), an `H2Odin.lua` config, and the
generated Odin binding. Headers and output live in the config
(`config.inputs`, `config.output_folder`); the CLI takes the project
directory and loads `H2Odin.lua`. Regenerate after changing H2Odin or the
configs:

```sh
make build

./build/h2odin examples/fff
./build/h2odin examples/sqlite3
./build/h2odin examples/bit_fields
./build/h2odin examples/raylib
./build/h2odin examples/box3d
./build/h2odin examples/cgltf
./build/h2odin examples/curl
./build/h2odin examples/miniaudio

odin check examples/fff        -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/sqlite3    -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/bit_fields -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/raylib     -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/box3d      -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/cgltf      -no-entry-point -collection:vendored=$(pwd)/vendored
# curl / miniaudio currently fail odin check — see their READMEs (validation findings)
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
that `odin check`, match naming/shape where the generator can, and surface
remaining gaps in a README next to each example.

| Example | Official reference | Role | `odin check` |
|---------|-------------------|------|--------------|
| [`raylib`](raylib/) | `vendor:raylib` (6.0) | Large C API, PascalCase, math overrides | pass |
| [`box3d`](box3d/) | `vendor:box3d` | Prefix strip + handles, multi-header umbrella | pass |
| [`cgltf`](cgltf/) | `vendor:cgltf` | Single-header, pointer-rich scene graph | pass |
| [`curl`](curl/) | `vendor:curl` | Multi-header, `typedef void` opaques, CURLOPT maze | **fail** (see README) |
| [`miniaudio`](miniaudio/) | `vendor:miniaudio` | ~95k-line single-header stress, callbacks, void tags | **fail** (see README) |

Validation is about **coverage and honest failure modes**, not only green
checks. Failures are recorded in each example README and summarized in the
[vendor-example audit](../docs/vendor-example-audit-2026-07-11.md). Closing
those failures is now [Milestone 15](../ROADMAP.md#milestone-15--close-the-real-world-validation-gaps-current-priority), ahead of broader feature work.

For this corpus, “functional” means: generation does not panic; every emitted
type resolves; final names are valid in their actual Odin scopes; transitive
foreign declarations follow an explicit policy; and the package passes
`odin check`. Byte-for-byte parity, hand-written helpers, wrappers, and full
pointer curation are not part of that gate.

When a regenerate diverges from the official package in a new way, prefer
fixing the generator (in a dedicated change) or documenting the gap in that
example's README over papering over it in the config alone.
