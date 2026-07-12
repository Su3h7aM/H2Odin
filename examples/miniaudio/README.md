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
  → `data_source` / `node` / `vfs` as `distinct rawptr`
- Field/type shadowing after `ma_` strip: `naming.override` renames fields
  `format` / `thread` / `log` → `format_` / `thread_` / `log_`

## Regenerate

```sh
./scripts/build
./build/h2odin examples/miniaudio
odin check examples/miniaudio -no-entry-point -collection:vendored=$(pwd)/vendored
```

Or the full corpus gate: `./scripts/validate-examples`.

## Status

| Step | Result |
|------|--------|
| Generate | OK (~0.3s, large single-file package) |
| `odin check` | **OK** |
| Opaque handles | pure `typedef void` → `distinct rawptr` |
| Shadowing | resolved via `naming.override` (spec 0008) |
| Scale | Stress test: many `pointer_lowering_guess` diagnostics remain |

## Gaps vs `vendor:miniaudio`

- Official multi-file layout (types / procs / backends / wasm)
- Heavy hand curation of platform threads and backend structs
- Pointer multipointers and out-params largely stay `^T` (quality work, not
  a validity blocker)
