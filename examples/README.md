# Examples

Example headers and Lua configs used while developing H2Odin.

Each example contains the source header, the Lua config, and the generated
Odin binding. Configs use `config.inputs` (paths relative to the config
file), so the header path is optional on the CLI. Regenerate after changing
H2Odin or the configs:

```sh
make build

./build/h2odin -config:examples/fff/config.lua > examples/fff/fff.odin
./build/h2odin -config:examples/sqlite3/config.lua > examples/sqlite3/sqlite3.odin

odin check examples/fff -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored
```

The configs default to idiomatic mode. That means generated declarations keep
the C ABI while using native Odin spellings where H2Odin can prove they are
equivalent on the target.

### What each config shows

| Example | Highlights |
|---------|------------|
| `fff` | `foreign.link_prefix` + `naming.strip_prefixes` (no per-proc `@(link_name)`); `config.inputs` |
| `sqlite3` | Same link-prefix pattern; `types.map` for 64-bit typedefs; `macros.groups` result-code enum |
