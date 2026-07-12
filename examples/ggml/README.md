# Example: ggml (validation)

Generate bindings for [ggml](https://github.com/ggml-org/ggml) (tensor / ML
library used by llama.cpp and related projects).

Pinned headers from commit `af97976` (see `GGML_COMMIT.txt`) under `include/`.

## What this exercises

- Multi-header public API: `ggml.h`, `ggml-alloc.h`, `ggml-backend.h`,
  `ggml-cpu.h`, `gguf.h` (no CUDA/Metal/Vulkan backends)
- Dense tensor / graph API, opaque contexts, large enums, function pointers
- Prefix strip + `link_prefix` (`ggml_` / `gguf_` / `GGML_` / `GGUF_`)

## Regenerate

```sh
./scripts/build
./build/h2odin examples/ggml
odin check examples/ggml -no-entry-point -collection:vendored=$(pwd)/vendored
```

## Status

| Step | Result |
|------|--------|
| Generate | Completes (writes `ggml.odin`) but **exit 1** — 8× `error[symbol_collision]` plus many `pointer_lowering_guess` warnings |
| `odin check` | **FAIL** (redeclarations + unresolved types) |

**Not part of** `./scripts/validate-examples` until green. Tracked as a
corpus stress case, not a merge-gate package.

### Generator findings (do not paper over in config alone)

Observed with current H2Odin after `ggml_`/`gguf_` strip:

1. **Package-scope name collisions (spec 0008)** when the same short name comes
   from both `ggml` and `gguf` APIs, or from a type and a proc:
   - `type` (enum in both libraries after strip)
   - `context_` (opaque handle in both)
   - `init_params` (struct in both)
   - `backend_dev_type`, `backend_graph_copy` (type vs other decl)
   - `type_name`, `free` (procs from both namespaces)
2. **Param shadowing type:** `graph_dump_dot` parameter `cgraph` vs type `cgraph`.
3. **Incomplete / wrong spellings in output:** e.g. `ggml_backend_buffer`,
   `ggml_threadpool` left with a C-style name while other symbols strip to
   `backend_buffer_t` / similar — `odin check` reports “is not a type”.
4. **Keyword-ish names:** stripped `type` is an awkward package-level enum name
   in Odin even without a second collision.

These are generator/config-corpus issues; no generator fix is applied in this
example commit.

## Scope

Backend-specific headers (`ggml-cuda.h`, `ggml-metal.h`, …) are intentionally
out of this package.
