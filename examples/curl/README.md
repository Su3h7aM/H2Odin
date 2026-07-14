# Example: libcurl (validation benchmark)

Generate bindings for [libcurl](https://curl.se/libcurl/) headers vendored
alongside Odin's `vendor:curl` (`vendor_curl`) and assess the generator against
a classic multi-header C API.

## What this exercises

- Multi-root public API split (`curl.h`, `multi.h`, and `urlapi.h`), with
  non-standalone API/support headers folded into the core root
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
| Layout | core / multi / URL API generated files |
| Foreign procs | Public API roots plus their folded support headers |
| `@(require_results)` | 7 (curated across the public roots) |

## Gaps vs `vendor:curl`

- `easy.h`, `header.h`, `options.h`, and `websockets.h` are not standalone C
  translation units, so they remain folded into `curl.odin` rather than
  matching every official topic file
- Generated file names follow headers rather than the official `curl_*` names
- OS-specific socket types (`platform_sockaddr`)
- Hand-curated CURLOPT tables and per-OS calling conventions
- Single `system:curl` import (`foreign.targets` available when needed)
- Pointer multipointers often stay `^T` (see regenerate diagnostics)
