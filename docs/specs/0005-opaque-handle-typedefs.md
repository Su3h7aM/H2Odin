# Spec 0005 — Opaque handle typedefs emit `distinct rawptr`

**Status:** accepted
**Date:** 2026-07-10

## Context

C libraries expose opaque handles in two idioms, and they differ in what the
C type system itself guarantees:

1. **`typedef void *CXIndex;`** — untyped in C. Every such handle is
   interchangeable with every other `void*`. Faithful emission is a plain
   `Index :: rawptr` alias, which is what H2Odin emits.
2. **`typedef struct CXTranslationUnitImpl *CXTranslationUnit;`** (pointer to
   an *incomplete* record) — **type-safe in C**: pointers to different
   incomplete structs are incompatible, and passing a `CXTranslationUnit`
   where a `CXTargetInfo` is expected is a C compile error.

For idiom 2, H2Odin's faithful emission was `Foo_Impl :: struct {}` +
`Foo :: ^Foo_Impl`. That preserved C's distinctness but lied about the
record: `size_of(Foo_Impl) == 0` and it can be instantiated, while the C type
is incomplete — unknown size, never instantiable. The self-host libclang
config then collapsed these handles to bare `rawptr` aliases via
`types.overrides` (hand-binding style, and to avoid the misleading empty
structs) — which destroyed the type discipline the C header itself has: every
handle became assignable to every other. The config had to author that
workaround because the generator has no concept of an opaque handle.

## Decision

1. **A typedef whose underlying type is a pointer to an incomplete record
   emits `Foo :: distinct rawptr` automatically.** This is provable from the
   header — C already distinguishes these types, so distinctness is a fact of
   the header, not user intent. The spelling is ABI-identical (one pointer)
   and more honest than a pointer to an empty struct. The `*Impl` record
   itself is not emitted: it is incomplete, referenced only through the
   handle, and has nothing true to say.

2. **`void*` typedefs stay plain `rawptr` aliases by default.** C states no
   distinction, so adding one is intent, not fact — per the provability rule
   it belongs in configuration: a `types.distinct` list
   (`config.types.distinct = { "CXIndex", "CXClientData" }`) opts named
   typedefs into `distinct rawptr`. Config selects; the generator authors the
   spelling.

3. **Aliased handles stay aliases.** If two typedefs point at the *same*
   incomplete record, they are the same type in C; emitting two independent
   `distinct` types would reject interchanges C allows. The first typedef
   (in declaration order) gets `distinct rawptr`; later typedefs of the same
   record emit as aliases of the first.

4. **Completed records opt out.** If the record is completed anywhere in the
   input set, it is not opaque — normal record emission applies and the
   typedef stays a true pointer to it.

## Consequences

- The libclang config drops its `types.overrides` collapse block and the
  matching `symbols.remove` entries for the `*Impl` records; the package is
  regenerated and Extraction recompiled against it (call sites already
  traffic in the typedef names; `nil` assigns to `distinct rawptr` freely).
- The generated libclang package becomes as handle-safe as the C header —
  and, with `types.distinct` for `CXIndex`/`CXClientData`, as safe as the
  replaced hand binding.
- Client code that stores handles in generic `rawptr` slots needs an
  explicit cast. That is the feature.

## Acceptance

A fixture with two incomplete-record handles must emit `distinct rawptr` for
both and reject cross-assignment under `odin check`; a fixture with two
typedefs of one record must keep them mutually assignable; regenerated
examples and the libclang package pass `odin check` and `make test`.
