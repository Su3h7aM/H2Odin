---
name: odin-lang
description: >-
  Write, review, explain, or debug code in the Odin programming language (.odin files). Odin is a
  niche, low-level, manually-memory-managed systems language whose rules differ sharply from
  mainstream languages and post-date most training data, so DO NOT rely on memory or C/Go/Rust
  intuition — consult this skill whenever a task involves Odin. Trigger this skill for ANY Odin
  work: writing procedures/structs/unions, manual memory management (allocators, new/free,
  make/delete, defer, context.temp_allocator), the implicit `context`, error handling with
  multiple return values (or_else, or_return), slices/maps/dynamic arrays, enums, tagged unions,
  Maybe, `using`, compile-time constants, or anything mentioning "Odin", ".odin", `odin run`,
  `odin build`, `core:fmt`, or Karl Zylinski's book. Use it even for small snippets — Odin's
  `::` vs `:=` vs `:`, "zero is initialization", distinct types, and no-exceptions error model
  are easy to get subtly wrong without it.
---

# Odin programming language

Odin is a compiled, statically-typed, **manually memory-managed** systems language. It is
data-oriented, deliberately simple, and has **no classes, no methods, no exceptions, no
garbage collector, and no implicit type conversions between variables**. Write Odin the Odin
way — do not transliterate C, Go, or Rust.

Before writing non-trivial Odin, skim the relevant reference file:
- `references/language-reference.md` — full syntax: declarations, types, untyped constants, structs, enums, unions/Maybe, pointers, procedures, control flow, slices, maps, `using`, iterators, `defer`.
- `references/memory-and-context.md` — allocators, `new`/`free`, `make`/`delete`, dynamic arrays, the temp allocator, ownership rules, and the implicit `context`.
- `references/error-handling.md` — the multiple-return-value error model, `or_else`, `or_return`, `#optional_ok`, `#optional_allocator_error`.

## The five ideas that define Odin

1. **Zero Is Initialization (ZII).** Every variable is zero-initialized by default — no garbage memory, no `undefined`. Design types so their zero value is valid and useful (`0`, `false`, `""`, `nil`, first enum member). This is why "no error" is the zero value, why `nil` is a union's default, and why `x: T` alone is safe.
2. **Explicitness over magic.** No implicit conversions between typed variables, no hidden control flow, no operator surprises. What you write is what runs.
3. **Manual memory management.** You decide when dynamic memory is freed. The skill of Odin is reasoning about **lifetimes**: "for how long does this memory need to exist?"
4. **Errors are just values.** A procedure that can fail returns an extra value (as the **last** return value). You check it. There is no `throw`/`catch`.
5. **Data and procedures are separate.** Structs hold data; procedures process data. No methods live inside structs.

## Smallest program & running it

```odin
package hellope

import "core:fmt"

main :: proc() {
    fmt.println("Hellope!")
}
```

Every file starts with a `package` line. Build & run the package in the current directory with `odin run .` (the `.` means "this directory"). Build without running: `odin build .`. No semicolons needed. Useful flags: `-vet` (catches unused imports/vars and more), `-vet-style`/`-strict-style`, `-debug` and `-sanitize:address` (find memory bugs), `-no-bounds-check` (release-only speedup).

## The declaration rules — get these right first

The single most common source of mistakes. `:` introduces a declaration; `::` is a **compile-time** (constant) declaration; `:=` declares a variable with inferred type; a lone `=` reassigns something that already exists.

```odin
number: int              // declare, zero-initialized to 0
number: int = 7          // declare with explicit type + value
number := 7              // declare + infer type (int here)
number = 12              // REASSIGN existing variable (no : and no second :)

CONST     :: 12          // named compile-time constant  (SCREAMING_SNAKE_CASE)
Rectangle :: struct {..} // type definition  (Ada_Case)
main      :: proc() {..} // procedure definition  (snake_case)
```

Rule of thumb: **use `:=`/`:` only when creating something new; use plain `=` to change an existing value.** Assigning to a name that doesn't exist yet with `=` fails to compile. Leave a variable uninitialized (rarely wanted) with `x: int = ---`.

## Distinctive rules that are easy to get wrong

- **No implicit conversion between typed variables.** `f: f32 = an_int` fails; write `f := f32(an_int)`. A type name followed by `()` is a cast. (But *untyped constants* like `7` or `0.5` DO implicitly adapt — `x: f32 = 7` is fine. See language-reference.)
- **Pointers:** `^T` is the type ("pointer to T"), `&x` takes an address, `p^` dereferences (the `^` goes *after* the name to read/write through it). `nil` is the zero value; reading/writing through `nil` crashes. Indexing a pointer-to-array auto-dereferences: `p[i]`, not `p^[i]`.
- **Enums are distinct from integers.** Compare with members (`if ct == .Laptop`), not numbers. To compare with an int you must cast: `int(ct) == 5`. The zero value is the member with value `0` — make that a sensible default (often a `None`/`Invalid` member).
- **`switch` needs no `break`** (cases don't fall through; use `fallthrough` if you want that). A `switch` over an enum must cover all members unless you prefix `#partial`. Prefer covering all members so adding one later gives a compile error at every switch.
- **Multiple return values need parentheses:** `-> (f32, bool)`. You must handle all-or-none of the returns; discard one with `_`. Use `_ :: fmt` to silence an unused import under `-vet`.
- **`for` is the only loop keyword.** `for {}` (forever), `for cond {}` (while), `for i := 0; i < n; i += 1 {}` (C-style), `for i in 0..<n {}` (half-open range) or `0..=n` (inclusive), `for v, i in collection {}`. **There is no `++`/`--`; use `i += 1`.** `if`/`for` conditions take no parentheses but always need `{ }` (or `do` for a one-liner).
- **Prefer slices (`[]T`) for parameters**, not fixed/dynamic arrays. Slicing with `arr[:]` is free (no allocation). Pass `&dyn_arr` only when the callee must `append`/grow it.
- **Don't pass pointers just to "avoid a copy."** Only use pointer params when you actually need to mutate the caller's value.

## Memory management essentials

See `references/memory-and-context.md` for the full treatment; the operational rules:

- **`new(T)` → `free(ptr)`** for a single heap value (`new` returns `^T`).
- **`make(...)` / `append(&arr, x)` → `delete(container)`** for dynamic arrays, maps, slices-with-own-memory, strings. Note `delete` takes the value; `clear(&arr)` takes a pointer and keeps the capacity (just resets length).
- Allocating procs take a trailing `allocator := context.allocator`. To use temporary memory, pass `context.temp_allocator` and periodically call `free_all(context.temp_allocator)` (e.g. once per frame/loop). Temp-allocated memory is **not** individually freed.
- **Copying a container copies its header, not its memory** — both share the same backing buffer, which becomes dangerous if one grows. Clone explicitly (e.g. `slice.clone_to_dynamic(arr[:])`).
- **`defer`** runs a statement at end of the current scope (multiple defers run in reverse order) — ideal for cleanup that must happen on every exit path: `f := os.open(...); defer os.close(f)`. Don't overuse it; reserve it for genuine cleanup.
- For short-lived "script" programs you may ignore freeing entirely: the OS reclaims everything on exit.

## Error handling essentials

See `references/error-handling.md` for depth. The model:

- **Errors are the LAST return value.** Represent them as a `bool` (ok/not), an `enum` (several named failures — make `None` the zero value), or a `union` (different errors, each carrying data).
- **`or_else`** supplies a fallback when the error is non-zero: `config := load_config(path) or_else DEFAULT_CONFIG`.
- **`or_return`** propagates: if the call's last return is a non-zero error, set this procedure's error return and return immediately. It requires **named return values** when there's more than one return. Don't over-propagate — handle errors that are properly yours to handle.

```odin
Load_Error :: enum { None, File_Unreadable, Invalid_Format }   // None == 0 == zero value

load_config :: proc(path: string) -> (Config, Load_Error) {
    data, ok := os.read_entire_file(path, context.temp_allocator)
    if !ok { return {}, .File_Unreadable }
    result: Config
    if json.unmarshal(data, &result) != nil { return {}, .Invalid_Format }
    return result, .None
}
```

## Naming conventions (from the core library)

- `snake_case` for variables and procedures (`find_cat_with_name`, `some_value`).
- `Ada_Case` for types (`Cat`, `Person_Stats`, `Load_Config_Error`).
- `SCREAMING_SNAKE_CASE` for constants (`DEFAULT_CONFIG`, `MAX_ENTITIES`).

## When unsure, verify — don't guess

Odin is pre-1.0 and moves; the standard library is large and specific. If unsure about a `core:`/`vendor:` package, a procedure signature, or a recent language change, say so and check the official docs (odin-lang.org/docs, pkg.odin-lang.org) rather than inventing an API. Prefer idiomatic patterns from this skill over clever ones.
