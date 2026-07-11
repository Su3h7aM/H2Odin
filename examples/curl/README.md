# Example: libcurl (validation benchmark)

Generate bindings for [libcurl](https://curl.se/libcurl/) headers vendored
alongside Odin's `vendor:curl` (`vendor_curl`) and assess the generator against
a classic multi-header C API.

## What this exercises

- Multi-header umbrella (`curl.h` pulls easy/multi/urlapi/…)
- Opaque handles as **`typedef void CURL;`** (not incomplete structs)
- Huge option / info surfaces (`CURLOPT_*`, `CURLINFO_*` as enums + macros)
- Callback typedefs (write/read/progress/…)
- Platform socket typedefs and system includes (`sys/socket.h`, …)
- Deprecation attributes on evolving API

## Regenerate

```sh
make build
./build/h2odin examples/curl
odin check examples/curl -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Status (present capabilities)

| Step | Result |
|------|--------|
| Generate without workaround | **PANIC** — `void type has no ABI spelling` on pure `typedef void CURL` |
| Generate with workaround | OK (drops `CURL` / `CURLSH` / `CURLM` decls via `symbols.remove.names`) |
| `odin check` | **FAIL** — see findings below |
| Proc count (approx.) | ~72 foreign procs |

### Config workaround (not a fix)

`H2Odin.lua` removes the pure void opaque typedefs so emission does not panic.
Uses of `CURL *` then peel toward `rawptr`, but many callback typedefs still
spell `^CURL` and fail to resolve. This is **documentation of the limit**, not
an acceptable permanent policy.

### Findings requiring investigation (ROADMAP)

1. **Pure `typedef void Name` opaque handles** — emission panics; no path to
   `Name :: distinct rawptr` / incomplete struct today.
2. **Removing those typedefs leaves dangling type names** in function-pointer
   typedefs and signatures.
3. **`sockaddr` redeclaration / illegal cycle** — this combines two defects:
   configured `struct curl_sockaddr` is stripped to top-level `sockaddr`, while
   its field referencing system `struct sockaddr` causes that external record
   to be captured and emitted as a second `sockaddr`. Final-name validation
   must catch the collision, and external-type provenance needs its own rule.

## Gaps vs `vendor:curl`

- Official multi-file package + OS-specific socket types
- Hand-curated CURLOPT tables and calling conventions
- No multi-lib / versioned `foreign import`
