# Example: ggml (validation)

Generate bindings for [ggml](https://github.com/ggml-org/ggml) (tensor / ML
library used by llama.cpp and related projects).

Pinned headers from commit `af97976` (see `GGML_COMMIT.txt`) under `include/`.

## What this exercises

- Multi-header public API: `ggml.h`, `ggml-alloc.h`, `ggml-backend.h`,
  `ggml-cpu.h`, `gguf.h` (no CUDA/Metal/Vulkan backends)
- One generated Odin file per public root, preserving core / allocation /
  backend / CPU / GGUF separation
- Dense tensor / graph API, opaque contexts, large enums, function pointers
- Dual-prefix naming: strip `ggml_` / `GGML_`; **keep** `gguf_*` Odin names so
  short names do not collide after strip
- Kind-aware renames where a C tag and procedure share a spelling
- Parameter renames where Odin would shadow a package type (`tensor`, `cgraph`)
- Explicit `[^]T` multipointers on scheduler / allocator array parameters

## Regenerate

```sh
./scripts/build
./build/h2odin examples/ggml
odin check examples/ggml -no-entry-point -collection:vendored=$(pwd)/vendored
```

Or the full corpus gate: `./scripts/validate-examples`.

## Status

| Step | Result |
|------|--------|
| Generate | OK (exit 0, no error-severity diagnostics) |
| `odin check` | **OK** |
| Foreign procs (approx.) | ~612 |
| `[^]T` sites | 6 |
| Layout | `ggml`, `ggml-alloc`, `ggml-backend`, `ggml-cpu`, and `gguf` units |
| Gate | included in `./scripts/validate-examples` |

### Honest dual-prefix strategy

| Concern | Approach in `H2Odin.lua` |
|---------|--------------------------|
| `ggml_*` / `gguf_*` short-name collisions after strip | Strip only `ggml_`; `naming.override` returns full `gguf_*` names |
| Proc vs type same C spelling (`ggml_backend_dev_type`, …) | Proc renames: `backend_dev_get_type`, `backend_graph_copy_create` |
| Incomplete tag refs (`ggml_backend_buffer`, `ggml_threadpool`) | `naming.overrides` + `types.map` → `backend_buffer_t` / `threadpool_t` |
| Param shadows type (`tensor: ^tensor -> ^tensor`) | Param rename `tensor` → `tensor_`; `cgraph` → `cgraph_` |

## Scope

Backend-specific headers (`ggml-cuda.h`, `ggml-metal.h`, …) are intentionally
out of this package. No `require_results` / `#by_ptr` curation yet — naming
correctness is the gate for this stress case.
