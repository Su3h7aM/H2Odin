# Example: raylib (validation benchmark)

Generate Odin bindings for [raylib](https://www.raylib.com) **v6.0** and
compare them with the hand-written package in Odin's `vendor:raylib`.

## Regenerate

```sh
make build
./build/h2odin examples/raylib
odin check examples/raylib -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Reference

| | Generated | Official (`vendor:raylib`) |
|--|-----------|----------------------------|
| Header | `raylib.h` (tag `6.0`) | raylib 6.0 API surface |
| Package | `raylib` | `raylib` |
| Proc names | C PascalCase (`InitWindow`) | same |
| Math types | `Vector2`/`3`/`4` as arrays; `Color` as `distinct [4]u8`; `Quaternion`; `Matrix` | same shapes via hand overrides |
| Leaf ints | idiomatic `i32` / `u32` / … | often `c.int` (ABI-identical on this target) |

## Config highlights (`H2Odin.lua`)

- `type_mode = "idiomatic"`
- `types.overrides` for Vector/Color/Quaternion/Matrix to match the vendor shapes
- No strip/recase — raylib C is already PascalCase

## Known gaps vs the hand binding

These are intentional generator limitations or deferred polish, not silent
ABI lies:

1. **Foreign import** — single `system:raylib`. Official uses multi-OS static/shared libs and system frameworks.
2. **Palette constants** — hand binding hard-codes `LIGHTGRAY`, `RAYWHITE`, …; the C header only has macros/comments, so we do not invent them.
3. **`#by_ptr` / `require_results` / default calling convention** — not emitted (no generator surface yet).
4. **Pointer lowering** — many `T*` stay `^T` where the hand binding uses multipointers or `cstring` with more context; see diagnostics on regenerate.
5. **Extra modules** — official also ships `raymath`, `raygui`, `rlgl`, easings. This example is `raylib.h` only.

Use this package as a **quality benchmark**, not as a drop-in replacement for
`vendor:raylib` in production games.
