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

odin check examples/fff        -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/sqlite3    -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/bit_fields -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/raylib     -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/box3d      -no-entry-point -collection:vendored=$(pwd)/vendored
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

| Example | Official reference | Role |
|---------|-------------------|------|
| [`raylib`](raylib/) | `vendor:raylib` (raylib 6.0) | Large C API, PascalCase names, math type overrides |
| [`box3d`](box3d/) | `vendor:box3d` | Prefix strip + link_prefix, handle structs, multi-header umbrella |

When a regenerate diverges from the official package in a new way, prefer
fixing the generator or documenting the gap in that example's README over
papering over it in the config alone.
