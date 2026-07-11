# Spec 0008 — Post-rename symbol-collision validation

**Status:** proposed
**Date:** 2026-07-11

## Context

The transformation pipeline ends with `filter_declarations` +
`apply_renames` (`src/transform.odin`). Nothing after that checks that the
final Odin names are unique in their scope. Distinct C symbols can collapse
into one Odin name through several independent doors:

- `naming.strip_prefixes` — `glOpen` and `vkOpen` both become `Open`;
- `naming.overrides` / the `naming.override` callback mapping two C names
  to the same spelling;
- enum-member prefix stripping (`member_strip_prefix`);
- synthesized declarations (macro-group enums, `enums.bit_sets` names)
  landing on a name an existing declaration already uses;
- keyword-safe default renames coinciding with a real C symbol.

A collision at package scope emits Odin that fails `odin check`
(redeclaration); a collision among enum members or struct fields can
*silently merge* two C meanings. Both violate "correctness over
convenience".

The pieces already exist in intent: [`config-spec.md`](../config-spec.md)
lists "Apply collision handling" as pipeline step 13 and shows
`symbol_collision = "error"` in its examples, and `.Symbol_Collision` is a
registered category in `src/diagnostics.odin` — but no code emits it.

## Decision

Add a scope-aware validation pass, `validate_symbol_names`, that runs
immediately after `apply_renames` as the final transformation step. It
**detects and reports; it never auto-renames.** A collision has no
conservative default spelling — suffixing one side would silently invent
meaning — so the generator fails closed and the user resolves it via
`naming.overrides` (or the section-local override that caused it).

Scopes checked, each an independent namespace:

- **Package scope** — all emitted top-level names together: types, procs,
  variables, constants, and synthesized decls (macro-group enums, bit-set
  names). Odin has one flat package namespace; the foreign block does not
  open a new one.
- **Per record** — field names of each struct/union/bit_field.
- **Per procedure** — parameter names.
- **Per enum** — member names.
- **Odin lexical binding conflicts** — a field or parameter whose final name
  shadows a type name used in its own declaration (`format: format`,
  `thread: thread`). These are not duplicate symbols, but Odin resolves them
  as illegal declaration cycles, so output-validity validation must catch them
  in the same final pass. This case was exposed by the miniaudio/cgltf
  validation corpus.

Each collision emits one `symbol_collision` diagnostic naming **all
colliding original C spellings**, the resulting Odin name, and the scope
(`package`, `struct Foo`, `proc bar`, `enum Baz`). A lexical binding conflict
names the member/parameter and the referenced type it shadows.

Default severity is **error** (matching the north-star examples), not the
usual `warn` default: colliding output is not merely suspect, it is broken.
Per the existing flow, output is still written and the run exits non-zero;
`config.diagnostics` can downgrade to `warn` explicitly.

## Consequences

- `.Symbol_Collision` gains its emitter; the category stops being dead.
- Configs that today silently produce broken or meaning-merged output start
  failing loudly. That is the point; there is no compatibility concern
  because such output was never valid.
- The pass is pure IR-walking (a per-scope name set), testable without Lua
  or libclang.
- `config-spec.md` step 13 ("Apply collision handling") becomes real, in
  its detect-and-report form. Auto-resolution strategies, if ever wanted,
  would be a separate spec — nothing here precludes one.

## Acceptance

- Two procs whose stripped names coincide → one `symbol_collision` error
  listing both C names; exit non-zero; e2e fixture covers it.
- Same for: two `naming.overrides` entries mapping to one name; enum
  members colliding after `member_strip_prefix`; a `enums.bit_sets` name
  colliding with an existing type; parameter names within one proc; and a
  field/parameter shadowing the final name of a type used by its declaration.
- A clean config emits no `symbol_collision` diagnostics (all example
  projects stay green).
- `config.diagnostics.symbol_collision = "warn"` downgrades the severity.
- `docs/configuration.md` drops `symbol_collision` from the
  "reserved (no emitter yet)" comment.

## See also

- [`config-spec.md`](../config-spec.md) — pipeline step 13, severity examples.
- `src/diagnostics.odin` — existing `.Symbol_Collision` category.
- `src/transform_naming.odin`, `src/transform_symbols.odin` — the rename
  pipeline this validates.
