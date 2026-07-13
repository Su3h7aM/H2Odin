# Example: C bit-fields

This focused example verifies C bit-field extraction and Odin `bit_field`
emission. H2Odin emits a region only when libclang's measured size, alignment,
and offsets prove that the generated layout matches C; otherwise it falls back
conservatively with a diagnostic.

```sh
./scripts/build
./build/h2odin examples/bit_fields
odin check examples/bit_fields -no-entry-point -collection:vendored=$(pwd)/vendored
```
