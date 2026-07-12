# Example: libcurl (validation benchmark)

Generate bindings for [libcurl](https://curl.se/libcurl/) headers vendored
alongside Odin's `vendor:curl` (`vendor_curl`) and assess the generator against
a classic multi-header C API.

## What this exercises

- Multi-header umbrella (`curl.h` pulls easy/multi/urlapi/…)
- Opaque handles as **`typedef void CURL;`** → `CURL :: distinct rawptr`
- Huge option / info surfaces (`CURLOPT_*`, `CURLINFO_*` as enums + macros)
- Callback typedefs (write/read/progress/…)
- System types via the built-in POSIX/libc map (`posix.sockaddr`, `libc.time_t`)
- Deprecation attributes on evolving API
- Param/type shadowing fix: `formadd` renames param `httppost` → `httppost_`
  (`naming.override` in `H2Odin.lua`)

## Regenerate

```sh
./scripts/build
./build/h2odin examples/curl
odin check examples/curl -no-entry-point -collection:vendored=$(pwd)/vendored
```

Or the full corpus gate: `./scripts/validate-examples`.

## Status

| Step | Result |
|------|--------|
| Generate | OK |
| `odin check` | **OK** |
| Opaque handles | `CURL` / `CURLM` / `CURLSH` as `distinct rawptr` |
| System types | `addr: posix.sockaddr`, `time_t` → `libc.time_t` |

## Gaps vs `vendor:curl`

- Official multi-file package + OS-specific socket types (`platform_sockaddr`)
- Hand-curated CURLOPT tables and per-OS calling conventions
- No multi-lib / versioned `foreign import`
- Pointer multipointers often stay `^T` (see regenerate diagnostics)
