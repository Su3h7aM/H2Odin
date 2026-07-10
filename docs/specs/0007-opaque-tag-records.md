# Spec 0007 — Incomplete tag records: mode defaults + `types.opaque` overrides

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
*typedef*). Two faithful-or-better spellings exist:

```odin
// Faithful (C/Odin call sites parallel)
Stmt :: struct {}
// use sites: ^Stmt, ^^Stmt

// Handle style (hand-binding idiom)
Stmt :: distinct rawptr
// use sites: Stmt, ^Stmt
```

The empty-struct spelling is already **type-safe** (named empty structs are
distinct nominal types). Its defect is honesty: `size_of(Stmt) == 0`,
`Stmt{}` instantiates, and `stmt^` dereferences — all forbidden for C
incomplete types. The handle style is ABI-identical (one pointer) and more
honest.

Two facts frame the decision:

- An incomplete C type **cannot** be used by value — "always behind a
  pointer" is guaranteed by the language. Collapsing `^Stmt` to a
  `distinct rawptr` handle is always ABI-sound for a genuinely incomplete
  record.
- Both spellings are correct; choosing between them is taste among
  **proven ABI-identical** representations. That is exactly what
  `type_mode` is for: ABI mode spells faithfully; idiomatic mode substitutes
  native Odin spellings where the substitution is proven safe.

## Decision

1. **Mode sets the default for incomplete *named* tag records.**

   | Mode | Default emission |
   |---|---|
   | ABI | `T :: struct {}` + pointer levels (`^T`, `^^T`) |
   | Idiomatic | `T :: distinct rawptr` + one pointer level collapsed (`T* → T`, `T** → ^T`) |

   No diagnostic on either default — nothing is guessed. Complete records
   never auto-collapse under idiomatic (they are not incomplete tags).

2. **`config.types.opaque` is a per-name bool override in either direction:**

   ```lua
   config.types.opaque = {
       sqlite3_stmt = true,   -- force handle (even in ABI mode)
       sqlite3_file = false,  -- force faithful (even in idiomatic mode)
   }
   ```

   Absent keys follow the mode default. This inverts the pure opt-in list:
   the tedious “list every handle” surface dissolves under idiomatic mode,
   while still allowing both “one more handle in ABI” and “keep one tag
   faithful in idiomatic.”

3. **Fail closed on completeness when forced.** If `types.opaque[name] =
   true` names a *complete* record, collapse would change layout; the
   generator refuses that entry with `opaque_record_complete` (error by
   default) and emits the record faithfully. Idiomatic auto-skip of
   complete records is silent.

4. **Separate key from `types.distinct`.** `types.distinct` re-spells a
   *typedef declaration* in place (void* → distinct rawptr), touching no
   references. `types.opaque` rewrites *every reference* to a record by
   collapsing a pointer level. Two keys, two contracts.

5. **Widened mode contract (record this boundary).** Mode may choose among
   proven ABI-identical *spellings* of the same C entity — including, here,
   handle vs empty-struct-plus-pointer for incomplete tags. Mode may
   **never** change arity or invent wrappers (Milestone 6 territory). The
   modes were never drop-in interchangeable for client code shape; after
   this change the mode diff can be structural (`^Stmt` vs `Stmt`), not only
   leaf spellings. That is intentional and bounded by the ABI-identity rule.

## The three opaque idioms, in one place

| C idiom | C type-safety | Default emission | Config |
|---|---|---|---|
| `typedef struct Impl *H;` | distinct | `H :: distinct rawptr` (automatic, both modes — spec 0005) | — |
| `typedef void *H;` | none | `H :: rawptr` alias | `types.distinct` hardens (spec 0005) |
| `typedef struct T T;` + `T *` | distinct | ABI: `struct {}` + `^T`; idiomatic: handle | `types.opaque[name] = true/false` overrides |

## Consequences

- Idiomatic packages (sqlite3 example, libclang self-host) get handle-style
  incomplete tags without a name list; complete records stay structs.
- ABI packages keep C-parallel shapes unless they opt names in.
- Pointer-collapsing happens in Transformation; Extraction stays faithful;
  Emission stays a serializer.

## Acceptance

A fixture with an incomplete tag used as `T*`/`T**`:

- ABI (no override) → `struct {}` + `^T`/`^^T`
- Idiomatic (no override) → `distinct rawptr` + `T`/`^T`
- ABI + `types.opaque[T]=true` → handle
- Idiomatic + `types.opaque[T]=false` → faithful
- `types.opaque` forcing a complete record → `opaque_record_complete`, faithful emission

All variants pass `odin check` where they are supposed to succeed.
