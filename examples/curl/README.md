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
| Foreign procs (approx.) | 41 (decls whose home is `curl.h` only) |
| `@(require_results)` | 7 (honest subset declared in `curl.h`) |

## Gaps vs `vendor:curl`

- **Input membership:** `easy.h` / `multi.h` / `urlapi.h` are included by
  `curl.h` but are not config inputs, so their procedures are not emitted.
  Listing them alone fails parse (`CURL_EXTERN` / types come from `curl.h`).
  Expanding the input surface is future work; require_results only lists
  symbols that actually appear.
- Official multi-file package + OS-specific socket types (`platform_sockaddr`)
- Hand-curated CURLOPT tables and per-OS calling conventions
- Single `system:curl` import (`foreign.targets` available when needed)
- Pointer multipointers often stay `^T` (see regenerate diagnostics)
