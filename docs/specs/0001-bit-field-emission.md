# Spec 0001 — C bit-fields become Odin `bit_field` regions, proven from measured layout

**Status:** accepted (planned — Milestone 12, not yet implemented)
**Date:** 2026-07-09

## Context

Any C struct containing a bit-field is emitted today as an opaque `struct {}`
with an `opaque_layout_fallback` diagnostic. Extraction detects the bit-field
(`clang_Cursor_isBitField`) and *drops the member without recording its
width*; the whole record is then marked `has_unrepresentable_fields`. That is
honest, but it makes by-value use of such structs impossible — and the
self-hosting goal (spec 0002) needs by-value construction of libclang's
`CXIndexOptions`, which carries a run of bit-fields.

Odin has a first-class `bit_field` construct that can express C bit-field
layouts. The hand-written libclang binding we currently vendor models
`CXIndexOptions` as:

```odin
using _: bit_field u16 {
	ExcludeDeclarationsFromPCH: u16 | 1,
	DisplayDiagnostics:         u16 | 1,
	StorePreamblesInMemory:     u16 | 1,
	_:                          u16 | 13, // reserved
},
```

The hard part is ABI fidelity: C bit-field packing depends on the allocation
unit, target ABI (Itanium vs MSVC rules), endianness, zero-width members, and
interleaving with ordinary fields. The project invariant is *correctness over
convenience*: never invent a layout.

## Decision

1. **Extraction records facts, drops nothing.** For every `FieldDecl`,
   capture `is_bitfield`, `bit_width` (`clang_getFieldDeclBitWidth`), and the
   measured bit offset from the start of the record
   (`clang_Cursor_getOffsetOfField`), alongside the existing name/type/doc.
   These are target-measured facts, so they belong in Extraction/IR, exactly
   like `Type_Builtin.size`. A width or offset libclang cannot answer (value
   < 0, dependent context) keeps the record unrepresentable.

2. **Emission derives the `bit_field` region from measured offsets — never
   from heuristics.** A maximal run of adjacent bit-field members becomes one
   anonymous region, `using _: bit_field uN { ... }`. The backing type `uN`
   and its byte position must be *proven*: the region's byte span (from the
   first member's bit offset to the last member's end, padded per the
   measured offsets of the surrounding fields and record size) must land on a
   whole `u8`/`u16`/`u32`/`u64` at a byte offset the emitted Odin struct
   reproduces. Reserved gaps inside a run emit as `_: uN | width`. This
   reproduces what the measured target ABI actually did, so it is not
   Itanium-vs-MSVC guessing — but the *proof step* is what makes any
   unhandled corner (straddling units, zero-width separators we cannot place)
   fall back instead of lying.

3. **Fail closed, with a dedicated diagnostic.** When the measured layout
   cannot be reproduced by an Odin `bit_field` region, the record stays
   opaque and emits the new category `bit_field_layout_fallback`
   (Milestone-11 registration, default `warn`, severity configurable via
   `config.diagnostics`). `opaque_layout_fallback` remains for the other
   causes (unsupported field type, forward declarations).

4. **No config surface in v1.** Emitting representable bit-fields is the
   default and only behavior; configuration neither authors the layout nor
   selects backing types. A `structs` policy to force opacity can come later
   if a real need appears.

Resolved design questions (from the planning brief):

| Question | Resolution |
|---|---|
| Backing type: C declared type or re-packed `uN`? | Neither by rule — derived from measured offsets/span; re-packing (e.g. a 16-bit run in a `unsigned` unit → `u16`) is allowed exactly when the proof holds. |
| Anonymous / reserved members? | Always `_` with the measured width; padding is preserved, never dropped. |
| `using _:` vs a named region field? | Always anonymous `using _:` — C bit-field members read as members of the struct, and `using` preserves that. |
| New diagnostic vs reuse `opaque_layout_fallback`? | New `bit_field_layout_fallback`, so config can treat "bit-field we could not prove" differently from "type we cannot represent". |
| ABI scope? | The layout is whatever libclang measured on the extraction target, so no per-ABI rule tables are kept. Acceptance tests target Unix/Itanium first; MSVC-specific fixtures are out of scope for v1 and documented as such. |

## Acceptance

`size_of` / field-offset equality with the C struct on the extraction target
(or with the known-good hand binding of `CXIndexOptions`) is the hard bar.
Output that reads correctly but has the wrong size is a failure, not a
partial success. Structs that keep falling back must do so with a clear
diagnostic, never silently.

## Consequences

- `Field` grows bit-field facts; `has_unrepresentable_fields` narrows to
  genuine failures. The current half-state (a record marked unrepresentable
  still carrying a partial `fields` slice, whose fields even produce
  `pointer_lowering_guess` diagnostics for output that never appears) gets
  cleaned up as part of the same work.
- Emission gains its first layout computation. It stays a serialization of
  facts (grouping adjacent runs and checking the proof is arithmetic over
  measured numbers, not policy), but it is the most decision-adjacent code in
  Emission — keep it in its own file with the proof spelled out.
- Blocks: spec 0002 (self-hosted libclang bindings).
