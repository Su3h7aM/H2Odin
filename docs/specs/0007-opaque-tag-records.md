# Spec 0007 — `types.opaque`: handle-style emission for incomplete tag records

**Status:** accepted
**Date:** 2026-07-10

## Context

Spec 0005 settled two opaque-handle idioms. C has a third:

```c
typedef struct sqlite3_stmt sqlite3_stmt;   /* incomplete tag typedef */
int sqlite3_stmt_readonly(sqlite3_stmt *pStmt);
```

Here the named type is the *incomplete record itself*, and the API always
takes a pointer to it (`sqlite3_stmt *`). sqlite3 uses this for `sqlite3`,
`sqlite3_stmt`, `sqlite3_value`, `sqlite3_context`, ….

Spec 0005 correctly does not match this (there is no pointer-to-incomplete
*typedef*), and current emission is faithful:

```odin
Stmt :: struct {}
// use sites: ^Stmt, ^^Stmt
```

This is already **type-safe** — named empty structs are distinct nominal
types in Odin, so `^Stmt` vs `^Value` preserves exactly the discipline the C
header has. Its only defect is honesty: `size_of(Stmt) == 0`, `Stmt{}`
instantiates, and `stmt^` dereferences, all of which C forbids for an
incomplete type. Hand bindings often prefer the handle style instead:
`Stmt :: distinct rawptr` with APIs taking `Stmt`.

Two facts frame the decision:

- An incomplete C type **cannot** be used by value — "always behind a
  pointer" is guaranteed by the language, not observed from usage. So
  collapsing `^Stmt` to a `distinct rawptr` handle is always ABI-sound for a
  genuinely incomplete record.
- Both spellings are correct; choosing between them is shape and ergonomics.
  `^Stmt` keeps C and Odin call sites parallel (the project's foreign-porting
  posture); `Stmt`-as-handle reads like hand bindings. Sound-but-optional is
  precisely what the provability rule assigns to configuration.

## Decision

1. **The default stays faithful.** An incomplete tag record emits
   `Stmt :: struct {}` and use sites keep their pointer levels (`^Stmt`,
   `^^Stmt`). No diagnostic — nothing is guessed.

2. **`config.types.opaque` opts named records into handle style:**

   ```lua
   config.types.opaque = { "sqlite3", "sqlite3_stmt", "sqlite3_value" }
   ```

   For each named record: emit `Name :: distinct rawptr`, suppress the
   record declaration, and collapse one pointer level at every reference —
   `T*` → `Name`, `T**` → `^Name`. This is a reference rewrite across the
   IR, not a declaration re-spelling.

3. **Fail closed on completeness.** If a record named in `types.opaque` is
   *complete* anywhere in the input set, the collapse would change layout;
   the generator refuses that entry with a diagnostic
   (`opaque_record_complete`, error-by-default posture is justified here
   since the config asked for something unsound) and emits the record
   faithfully.

4. **Separate key from `types.distinct`.** They sound similar but differ in
   kind: `types.distinct` (spec 0005) re-spells a *typedef declaration* in
   place, touching no references; `types.opaque` rewrites *every reference*
   to a record by collapsing a pointer level. Overloading one key with both
   behaviors — dispatching on what the name happens to refer to in the
   header — would make the config's meaning implicit. Two keys, two
   contracts.

## The three opaque idioms, in one place

| C idiom | C type-safety | Default emission | Config |
|---|---|---|---|
| `typedef struct Impl *H;` | distinct | `H :: distinct rawptr` (automatic, spec 0005) | — |
| `typedef void *H;` | none | `H :: rawptr` alias | `types.distinct` hardens (spec 0005) |
| `typedef struct T T;` + `T *` | distinct | `T :: struct {}` + `^T` | `types.opaque` collapses to handle (this spec) |

## Consequences

- The sqlite3 example can adopt `types.opaque` to demonstrate the handle
  style (and regenerates); leaving it faithful is equally valid — the
  example should pick one and say why.
- Pointer-collapsing happens in Transformation (it consults policy and
  rewrites decided type references); Extraction keeps recording the faithful
  incomplete record, and Emission stays a serializer.

## Acceptance

A fixture with an incomplete tag record used as `T*`/`T**`: default output
emits `struct {}` + `^T`/`^^T`; with `types.opaque` it emits
`distinct rawptr` + `T`/`^T`; naming a *complete* record fails closed with
the diagnostic; all variants pass `odin check`.
