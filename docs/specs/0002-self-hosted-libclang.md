# Spec 0002 — Self-hosted libclang bindings, in the Odin naming convention

**Status:** accepted (planned — Milestone 13, not yet implemented)
**Date:** 2026-07-09

## Context

Extraction imports a vendored, hand-written libclang package
(`import clang "vendored:libclang"`, Karl Zylinski's bindings). H2Odin exists
to generate exactly this kind of package, so the strongest possible proof of
the generator — and the end of maintaining a hand binding — is to generate
the bindings Extraction itself uses.

A dry run against `clang-c/Index.h` already produces ~6k lines that pass
`odin check`, but the output is not a drop-in replacement:

- **Bit-fields**: `CXIndexOptions` emits opaque (spec 0001 is the fix).
- **Naming**: the hand package renames (`clang_createIndex` → `createIndex`,
  `CXTranslationUnit` → `Translation_Unit`); H2Odin defaults to C names.
- **Multi-header capture**: the `clang-c/*.h` family is a set of headers that
  include each other, and today "ours" means "the current TU's main file" —
  a typedef declared in a sibling input header is resolved transparently at
  use sites, losing its name.
- **Curation**: flag enums, pointer out-params, platform `foreign import`
  branches are hand-tuned in the vendored package.

## Decision

1. **Self-hosted libclang bindings are the next project goal** (Milestone 13),
   with bit-field emission (spec 0001, Milestone 12) as its explicit
   prerequisite. Wrappers (Milestone 6) stay deferred and independent.

2. **The generated package uses the Odin naming convention**, not the C
   names and not the hand package's hybrid. Concretely, driven by a
   checked-in `config.lua` using the same approach as the sqlite3 example
   (strip affixes + `h2o.naming.snake_case` / `ada_case`):

   | C | Generated Odin |
   |---|---|
   | `clang_createIndex` | `create_index` |
   | `clang_getCursorKind` | `get_cursor_kind` |
   | `CXTranslationUnit` | `Translation_Unit` |
   | `CXCursor_FunctionDecl` (member) | `.Function_Decl` |
   | `CINDEX_VERSION_MAJOR` | `VERSION_MAJOR` |

   The package name carries the namespace, so call sites read
   `clang.create_index(...)`, `clang.Translation_Unit`. Configuration selects
   these names through the existing naming machinery; the generator authors
   every byte, as always.

3. **`src/extract.odin` migrates to the generated names.** The alternative —
   generating names that match the hand package so Extraction never changes —
   was rejected: it would permanently pin our config to someone else's
   naming choices, and the hand package's proc names (`createIndex`) are not
   the Odin convention anyway. Type names barely move (the hand package
   already uses Ada_Case types); the churn is mostly proc call sites, in one
   file, in one commit.

4. **The import path stays `vendored:libclang`; the generated package
   replaces the hand-written one.** The pinned headers live flat under
   `vendored/libclang/headers/` (`#include "Foo.h"` + `-I headers` so the
   pin is used, not system `/usr/include/clang-c`) and remain the generation
   input — regeneration is reproducible. Config lives next to them;
   generated Odin goes to `vendored/libclang/bindings/` until the hand
   package is removed.

5. **Bootstrap is generation-over-generation.** Generation N is produced by
   an `h2odin` binary built against the checked-in bindings from generation
   N−1. The first generation is built against the hand package; after the
   switch is verified (`make test`, examples, `odin check`), the hand package
   is deleted and the cycle sustains itself because the generated output is
   checked in. A `make regen-libclang` (name flexible) target encodes the
   workflow.

## Definition of done

1. Checked-in config generates the package from the pinned
   `vendored/libclang/headers/` via `config.inputs` into
   `vendored/libclang/bindings/`.
2. Bit-field layouts correct for the types Extraction needs
   (`CXIndexOptions` at minimum) — spec 0001 acceptance.
3. `src/extract.odin` builds and runs against the generated package.
4. `make test` (unit + e2e) and the checked-in examples stay green.
5. The hand-written package is removed (not dual-tracked) once verified.
6. Regeneration workflow and header pinning documented.

## Out of scope

- Windows multi-lib `foreign import` stanza parity with the hand package
  (H2Odin targets Unix `system:clang` first; document the gap).
- Function-like macros (`CINDEX_VERSION_ENCODE`) — skipped by design.
- Resolving every `pointer_lowering_guess` in the generated output; curation
  beyond what Extraction actually calls is polish, not the goal.

## Consequences

- H2Odin becomes its own first production consumer; regressions in the
  generator break the generator's own build — the strongest CI signal we can
  get for free.
- Multi-header "ours" scoping must be fixed in Extraction (input-set
  awareness instead of main-file-only), which benefits every multi-header
  user, not just self-host.
- The `known_tokens` dictionary and naming callbacks get their first
  large-scale, dogfooded workout (`getNumArgTypes`, `USR`, `PCH`, …ambiguous
  splits will surface `naming_ambiguity` diagnostics to resolve in config).
