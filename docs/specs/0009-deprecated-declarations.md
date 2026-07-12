# Spec 0009 — Deprecated C declarations: propagate by default, drop on opt-in

**Status:** accepted
**Date:** 2026-07-11

## Context

C headers mark declarations deprecated — `__attribute__((deprecated("msg")))`,
`__declspec(deprecated)`, C23 `[[deprecated]]`. libclang exposes this
uniformly: `clang_getCursorAvailability` returns `Deprecated` for functions,
variables, records, and typedefs alike, and
`clang_getCursorPlatformAvailability` recovers the attribute's message string.
Both are in the vendored bindings and verified working by probe (2026-07
review): a header's `deprecated("use new_fn instead")` comes back verbatim.

Today extraction discards all of it. The dogfood case: our own pinned
`Index.h` marks the five `clang_getRemappings*` functions `CINDEX_DEPRECATED`,
and the generated `vendored/libclang/Index.odin` emits them indistinguishable
from live API.

On the Odin side (verified against `dev-2026-07a`):

- `@(deprecated = "msg")` is **documented for procedures**
  (odin-lang.org/docs/overview/#deprecatedstring: "Mark a procedure as
  deprecated") and works on procs in a `foreign` block; use sites warn with
  the message.
- It is also **accepted on type declarations** and warns at their use sites —
  verified working, but beyond the documented surface (see Decision).
- It is **rejected** on constants and variables ("Unknown attribute element
  name").

## Decision

Deprecation is a *fact* about the header, so it crosses the pipeline the way
facts do:

**Extraction** records, per declaration: `deprecated: bool` and the attribute
message (arena-copied, empty when the attribute carries none). No judgment,
no filtering.

**Emission** propagates by default — a deprecated C API becomes a deprecated
Odin declaration:

- Procedures and types: `@(deprecated = "msg")` above the declaration. When
  the C attribute has no message, a fixed generated one: `"deprecated in the
  C header"`. For types this leans on verified-but-undocumented compiler
  behavior; the risk is acceptable because it cannot affect ABI or behavior,
  and if a future compiler drops it, `odin check` of the generated package
  fails loudly (the e2e suite and example checks catch it) — the fallback is
  then the doc-comment form below.
- Constants and variables (no Odin attribute exists): the message is
  prepended to the declaration's doc comment as a `Deprecated: msg` line.
  This line is semantic, not prose — it is emitted even when
  `config.comments = false`.

**Transformation** owns the opt-in drop, as a fourth declarative tier of the
existing removal section:

```lua
config.symbols.remove.deprecated = true
```

and the symbol callback view gains `sym.deprecated` (boolean), so a `where`
predicate can express partial policies ("drop deprecated consts, keep
deprecated procs"). Views grow compatibly; no existing config breaks.

**Why propagate rather than drop by default.** Dropping silently breaks
existing callers of a still-working API; the C header's own position is "this
works but stop using it", and `@(deprecated)` is Odin's native spelling of
exactly that. The generated binding stays faithful; the warning nudges. Users
who want the harder line opt into removal. (Consumers building with
`-warnings-as-errors` turn every use into an error — that is their flag doing
its job, not the generator's concern.)

**Why not a diagnostic category.** Deprecation is the *header's* statement,
not a generator uncertainty. Nothing was guessed, so nothing belongs in the
diagnostics report.

## Consequences

- `./scripts/regen-libclang` annotates exactly the five `clang_getRemappings*`
  procs in `vendored/libclang/Index.odin` — the built-in acceptance test.
  h2odin itself calls none of them, so its own build stays warning-free.
- The IR grows two fields per declaration; the Lua symbol view grows one.
- `docs/config-spec.md` symbols section and callback-view list gain the new
  surface (updated with this spec).

## Acceptance

- Fixture header with a deprecated proc (with message), type, variable, and
  constant:
  - default run emits `@(deprecated = "…")` on the proc and type, and the
    `Deprecated:` doc line on the variable and constant — message text
    preserved verbatim;
  - `comments = false` still emits the `Deprecated:` lines;
  - `symbols.remove.deprecated = true` drops all four;
  - a `where` predicate reading `sym.deprecated` sees `true` for them.
- Attribute without a message → the fixed fallback text.
- `./scripts/regen-libclang` + `git diff`: exactly five procs gain the attribute;
  `odin check` on the package and all examples stays green.

## See also

- [`0008-symbol-collision-validation.md`](0008-symbol-collision-validation.md)
  — sibling post-review hardening spec.
- [`config-spec.md`](../config-spec.md) — symbols removal tiers, callback
  views.
- 2026-07 libclang usage review notes in [`ROADMAP.md`](../../ROADMAP.md)
  (Code health).
