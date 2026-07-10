# Spec 0004 — Explicit backing width for generated `bit_set`s

**Status:** proposed
**Date:** 2026-07-10

## Context

`enums.bit_sets` (Milestone 9) replaces a C flag enum with
`Name :: bit_set[Enum]`. The IR (`Bit_Set_Decl`) records only the element
enum; emission writes `bit_set[E]` with no explicit backing type, so Odin
sizes the set from the highest declared bit position.

That size is not the C ABI size. C flag parameters are typically `unsigned
int` (4 bytes) regardless of how many flag bits exist. The self-hosted
libclang package made this concrete:

- `Translation_Unit_Flags :: bit_set[Translation_Unit_Flag]` is **2 bytes**
  (highest flag bit is below 16), but every C parameter that accepts it
  (`clang_parseTranslationUnit` `options`) is a 4-byte `unsigned`.
- H2Odin's own Extraction passes `{.Detailed_Preprocessing_Record}` at that
  call site (`src/extract.odin`). It works today only because x86-64
  argument passing happens to zero-extend small register values — that is an
  accident of one target's calling convention, not a proven layout.

This violates *correctness over convenience*: the substitution changes the
parameter's size and is not proven ABI-safe.

## Decision

1. **Every generated `bit_set` carries an explicit backing type:**
   `Name :: bit_set[Enum; uN]`, never bare `bit_set[Enum]`.

2. **The width is proven, not configured.** `Bit_Set_Decl` records the
   backing width taken from what libclang measured for the declaration the
   bit_set replaces — the C enum's underlying integer type (the same
   measurement idiomatic mode already trusts for enum backing). No new
   config surface: the width is a fact of the header, so per the provability
   rule the generator decides it automatically.

3. **Unsigned spelling.** The backing is spelled as the fixed-width unsigned
   type of the measured size (`u32` for a 4-byte enum). A flag set is a bag
   of bits; signedness of the C enum's backing does not change its layout,
   and `bit_set` requires an integer backing whose width is what the ABI
   cares about.

4. **Fail closed.** If the measured width cannot back the set (a member's
   log2 position ≥ N bits — possible only with a config error or a pathological
   header), skip the bit_set rewrite, keep the plain enum, and emit the
   existing `bit_set_non_power_of_two`-style diagnostic path (a new message
   under the same fail-closed posture, category `bit_set_backing_mismatch`).

## Consequences

- `size_of(Translation_Unit_Flags)` becomes 4, matching `unsigned`; the
  self-host call site becomes ABI-faithful instead of accidentally working.
- Regenerating the libclang package changes the spelling of every
  `enums.bit_sets` output — checked-in examples and the vendored package
  must be regenerated in the same change.
- `docs/configuration.md` / `docs/config-spec.md` examples that show
  `bit_set[E]` output update to the explicit-backing form.

## Acceptance

`size_of` equality between the generated bit_set and the measured C enum
size, asserted in a unit fixture (same hard bar as spec 0001: "looks right
but wrong size" is a fail), plus regenerated examples passing `odin check`.
