# Example: miniaudio (validation benchmark)

Generate bindings for [miniaudio](https://miniaud.io) (~95k-line single header,
API path only — `MINIAUDIO_IMPLEMENTATION` not defined) and compare with Odin's
hand-written `vendor:miniaudio`.

## What this exercises

- Extreme single-header scale (parse + emit time, diagnostic volume)
- Backend `#ifdef` maze (ALSA/Pulse/WASAPI/…) without forcing `MA_NO_*`
- Dense device/engine/sound config structs
- Many callback function-pointer fields
- Pure void opaque tags (`typedef void ma_data_source;`, `ma_node`, …)
- `ma_` prefix strip colliding with field names (`format: format`, `thread: thread`)

## Regenerate

```sh
make build
./build/h2odin examples/miniaudio
odin check examples/miniaudio -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Status (present capabilities)

| Step | Result |
|------|--------|
| Generate without workaround | **PANIC** — same void-typedef path as curl |
| Generate with workaround | OK (~0.3s, ~6500-line output, ~950 procs) after dropping pure void tags |
| `odin check` | **FAIL** — prefix-strip field/type cycles + dangling removed opaques |
| Scale | Stress test: large IR, many pointer-lowering diagnostics |

### Config workaround (not a fix)

`symbols.remove.names` drops pure `typedef void ma_*` tags. Remaining
references still name those types → undeclared names under `odin check`.
Prefix strip of `ma_` turns types like `ma_format` / `ma_thread` into
`format` / `thread`, which then collide with fields of the same name.

## Findings requiring investigation (ROADMAP)

1. **Pure void opaque typedefs** (shared with curl).
2. **Strip-induced type/field name collisions** producing illegal declaration
   cycles (`format: format`, `thread: thread`).
3. **Incomplete workaround surface** — removing a typedef without rewriting
   references yields undeclared type names.

## Gaps vs `vendor:miniaudio`

- Official multi-file layout (types / procs / backends / wasm)
- Heavy hand curation of platform threads and backend structs
- Default calling convention / link_prefix blocks only (no panic path)
