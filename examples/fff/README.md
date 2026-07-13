# Example: fff

This example generates bindings for the fff file-search library. It exercises
`foreign.link_prefix`, kind-specific prefix stripping, and targeted `cstring`
overrides where the C API's semantics are stronger than its pointer types.

```sh
./scripts/build
./build/h2odin examples/fff
odin check examples/fff -no-entry-point -collection:vendored=$(pwd)/vendored
```

The remaining pointer-lowering warnings are intentional: H2Odin keeps `^T`
when array, ownership, or string semantics cannot be proven from the header.
