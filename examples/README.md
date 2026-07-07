# Examples

Example headers and Lua configs used while developing H2Odin.

Each example contains the source header, the Lua config, and the generated
Odin binding. Regenerate the bindings after changing H2Odin or the configs:

```sh
make build

./build/h2odin -config:examples/fff/config.lua examples/fff/fff.h > examples/fff/fff.odin
./build/h2odin -config:examples/sqlite3/config.lua examples/sqlite3/sqlite3.h > examples/sqlite3/sqlite3.odin

odin check examples/fff -no-entry-point
odin check examples/sqlite3 -no-entry-point
```

The configs default to idiomatic mode. That means generated declarations keep
the C ABI while using native Odin spellings where H2Odin can prove they are
equivalent on the target.
