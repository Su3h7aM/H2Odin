# Example: Box3D (validation benchmark)

Generate Odin bindings for [Box3D](https://box2d.org/) (Erin Catto's 3D
physics library) and compare them with the hand-written package in Odin's
`vendor:box3d`.

Public headers are copied from the Odin vendor tree
(`vendor/box3d/src/include/box3d/`) so the generated surface tracks the same
API revision as the official binding.

## Regenerate

```sh
./scripts/build
./build/h2odin examples/box3d
odin check examples/box3d -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Reference

| | Generated | Official (`vendor:box3d`) |
|--|-----------|----------------------------|
| Headers | `include/box3d/*.h` (umbrella `box3d.h`) | same upstream |
| Package | `box3d` | `vendor_box3d` |
| Layout | one merged `box3d.odin` | split: types / math / collision / id / … |
| Proc names | strip `b3` + `link_prefix` (`CreateWorld`, `World_Step`) | same pattern |
| Handles | `WorldId`, `BodyId`, … as structs | same |
| Math | `Vec2`/`Vec3`/`Pos` as float arrays | same for single precision |

## Config highlights (`H2Odin.lua`)

- `foreign.link_prefix = "b3"` with matching `naming.strip_prefixes`
- `types.overrides` for `b3Vec2` / `b3Vec3` / `b3Pos` → `[N]f32`
- Keeps PascalCase after strip (matches official; no snake_case)
- `#by_ptr` on CreateWorld / Create*Shape definition and geometry parameters
- `require_results` on those Create* factories

## Declaration-level metrics (curated)

| Metric | Count |
|--------|------:|
| Foreign procs (approx.) | 417 |
| `[^]T` sites | 0 |
| `#by_ptr` params | 5 |
| `@(require_results)` | 5 |

## Known gaps vs the hand binding

1. **File layout** — one merged unit instead of topic-split files.
2. **`#by_ptr` coverage** — curated on the main Create* shape factories; not
   every official call site is mirrored.
3. **`b3Quat`** — C is `{ Vec3 v; float s }` (16 bytes). Official uses
   `quaternion128`. We keep the struct for ABI fidelity.
4. **Math helpers** — official reimplements many pure math functions in Odin
   (`box3d_math.odin`). We only bind what the headers export as linkable
   symbols; static inlines are skipped by design.
5. **ID helper procs** — `IS_NULL`, `StoreWorldId`, … are hand-written
   `#force_inline` wrappers in the official package, not C exports.
6. **Pointer lowering** — diagnostics list multipointer / out-param guesses.
7. **Input surface** — only `box3d.h` is listed; collision.h helpers such as
   `b3CreateMesh` are transitive and not emitted as "ours".

## Bug dogfood

Generating this package exposed a libclang USR collision for multiple C11
anonymous unions in one struct (`TreeNode`). Fixed in Extraction: anonymous
records are not interned by USR.
