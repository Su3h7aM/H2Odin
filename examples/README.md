# Examples

Example headers and Lua configs used while developing H2Odin.

Each example contains the source header, an `H2Odin.lua` config, and the
generated Odin binding. Headers and output live in the config
(`config.inputs`, `config.output_folder`); the CLI takes the project
directory and loads `H2Odin.lua`. Regenerate after changing H2Odin or the
configs:

```sh
make build

./build/h2odin examples/fff
./build/h2odin examples/sqlite3

odin check examples/fff -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored
```

The configs default to idiomatic mode. That means generated declarations keep
the C ABI while using native Odin spellings where H2Odin can prove they are
equivalent on the target.

### What each config shows

| Example | Highlights |
|---------|------------|
| `fff` | `foreign.link_prefix` + `naming.strip_prefixes` (no per-proc `@(link_name)`); `inputs` + `output_folder` |
| `sqlite3` | Same link-prefix/output pattern; `types.map` for 64-bit typedefs; `macros.groups` for result codes, open flags, authorizer actions, and other SQLITE_* families |
