# Example: SQLite

This large single-header example exercises standard C typedef mapping, opaque
handles, macro groups, callbacks, deprecation propagation, and targeted type
overrides against SQLite's public API.

```sh
./scripts/build
./build/h2odin examples/sqlite3
odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored
```

The generated package is a validation artifact. H2Odin reports unresolved
pointer semantics instead of silently imitating choices from a hand-written
binding.
