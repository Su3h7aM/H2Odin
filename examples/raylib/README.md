# Example: raylib (validation benchmark)

Generate Odin bindings for [raylib](https://www.raylib.com) **v6.0** and
compare them with the hand-written package in Odin's `vendor:raylib`.

## Regenerate

```sh
./scripts/build
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
- `procs.params` multipointers: `SetWindowIcons.images`, `GenImageFontAtlas.glyphs`,
  `UnloadModelAnimations.animations`
- `procs.require_results` on Load* loaders (model/texture/font/sound/…)

## Declaration-level metrics (curated)

| Metric | Count |
|--------|------:|
| Foreign procs (approx.) | 600 |
| `[^]T` sites | 3 |
| `#by_ptr` params | 0 |
| `@(require_results)` | 12 |

## Known gaps vs the hand binding

These are intentional scope choices, not silent ABI substitutions:

1. **Foreign import** — single `system:raylib`. Official uses multi-OS static/shared libs and system frameworks (`foreign.targets` is available when a package needs that shape).
2. **Palette constants** — hand binding hard-codes `LIGHTGRAY`, `RAYWHITE`, …; the C header only has macros/comments, so we do not invent them.
3. **`#by_ptr`** — not used on this surface (vendor does on some math-ish call sites); multipointer + require_results are curated instead.
4. **Pointer lowering** — many `T*` stay `^T` where the hand binding uses multipointers or `cstring` with more context; see diagnostics on regenerate.
5. **Extra modules** — `raymath` and easings are Odin implementations of
   companion header-only APIs; `raygui` and `rlgl` likewise come from separate
   headers/libraries. None of those headers is included by or vendored beside
   this example's `raylib.h`, so the multi-header ownership model cannot split
   them out without expanding the corpus to additional upstream APIs.

Use this package as a **quality benchmark**, not as a drop-in replacement for
`vendor:raylib` in production games.
