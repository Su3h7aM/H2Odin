# Odin language reference

Detailed syntax reference. Read the section you need.

- [Declarations & assignment](#declarations--assignment)
- [Basic types](#basic-types)
- [Constants & untyped types](#constants--untyped-types)
- [Control flow: if, switch, for](#control-flow)
- [Fixed arrays](#fixed-arrays)
- [Procedures](#procedures)
- [defer](#defer)
- [Pointers](#pointers)
- [Structs](#structs)
- [`using` (subtype composition)](#using)
- [Enums](#enums)
- [Unions (tagged) & Maybe](#unions)
- [Slices](#slices)
- [Maps](#maps)
- [Sets](#sets)
- [Custom iterators](#custom-iterators)

## Declarations & assignment

`:` = declaration. `::` = compile-time (constant) declaration. `:=` = declare + infer type. `=` = reassign an existing thing.

```odin
number: int         // declare, zero-initialized (0)
number: int = 7     // declare, explicit type, value
number := 7         // declare, infer type -> int
number = 12         // reassign (must already exist)
x: int = ---        // declare but DO NOT initialize (rare, perf-only)
```

`//` line comment, `/* ... */` block comment (block comments nest). Assigning with `=` to a name that doesn't exist is a compile error.

## Basic types

- Signed ints: `int i8 i16 i32 i64 i128` (`int` is register-width, i.e. i64 on 64-bit).
- Unsigned ints: `uint u8 u16 u32 u64 u128 uintptr`.
- Floats: `f16 f32 f64`. Default float type is `f64`. Many programmers use `f32` by default for size.
- Bools: `bool b8 b16 b32 b64` (`bool` == `b8`; zero value `false`). Use `bool` in normal code.
- `string`: UTF-8 text, zero value `""`. **Knows its own length** (`len(s)`), not null-terminated. `cstring` is the null-terminated C-interop variant. `string16`/`cstring16` are UTF-16 (Windows API).
- `rune`: a single Unicode code point, internally an `i32`. Literal: `'A'`.

`size_of(T)` gives a type's byte size. Conditions must be `bool` — you cannot use an int as a condition (`if n > 0` not `if n`).

## Constants & untyped types

A plain literal like `7`, `0.5`, `true`, `"cat"`, `'A'` is a **constant** with an *untyped* type that exists only at compile time. Untyped constants **implicitly convert** to any compatible type that can hold the value — this is why `x: f32 = 7` works even though a typed `int` variable would not implicitly convert to `f32`.

- Untyped Integer (`7`): converts to any int/float that can accommodate it; default inferred type `int`.
- Untyped Float (`7.42`): converts to any float; to an int only if it has no fractional part; default `f64`.
- Untyped Boolean, String, Rune similarly, defaulting to `bool`, `string`, `rune`.

"Accommodate" matters: `x: i8 = 10000` fails (i8 max is 127). Named constants use `::`:

```odin
MAX :: 100          // untyped integer constant
TYPED : f32 : 7.42  // explicitly-typed constant (rare)
```

## Control flow

**if** — no parens around the condition, always braces (or `do` for one statement):

```odin
if a > 7 && (b == 12 || c == 42) {
    ...
} else if x == 2 {
    ...
} else {
    ...
}

if cond do single_statement()   // one-liner form
```

`&&`/`||` short-circuit; `&&` binds tighter than `||`. Flip a bool with `!`. `if init; cond {}` allows a scoped declaration: `if v, ok := m[k]; ok { ... }`.

**switch** — no `break` needed; cases don't fall through (use `fallthrough` to opt in):

```odin
switch ct {
case .Laptop:  fmt.println("laptop")
case .Desktop: fmt.println("desktop")
}
```

An enum `switch` must be exhaustive unless prefixed with `#partial`. Prefer exhaustive so adding an enum member forces you to update each switch.

**for** — the only loop keyword:

```odin
for { }                         // infinite (use break to exit)
for cond { }                    // while-style
for i := 0; i < 10; i += 1 { }  // C-style (no ++/--; use i += 1)
for i in 0..<10 { }             // half-open range 0..9
for i in 0..=10 { }             // inclusive range 0..10
for v in collection { }         // value
for v, i in collection { }      // value + index
for &v in collection { }        // v is mutable (addressable), edits the element
#reverse for v in arr { }       // iterate backwards
```

Labels break/continue outer loops: `outer: for ... { for ... { break outer } }`. `continue label` likewise.

## Fixed arrays

```odin
ten: [10]int                        // 10 ints, all zero
ten := [10]int{ 1, 2, 3, /*...*/ }  // literal
x := ten[2]                         // index
ten[6] = 7                          // set
```

Fixed arrays are value types — assigning one copies all elements. Their memory lives on the stack (or inline in a struct). See memory reference for heap-allocating them.

## Procedures

```odin
add :: proc(a: int, b: int) -> int { return a + b }
add :: proc(a, b: int) -> int { return a + b }     // shared type
```

- **Default parameter values & named args:** `proc(x: int, y := 10)`; call `f(y = 5, x = 1)`.
- **Multiple returns need parentheses:** `-> (int, bool)`. Handle all-or-none; discard with `_`.
- **Named returns:** `-> (res: int, ok: bool)` — these act like zero-initialized locals; a bare `return` (a "naked return") returns their current values. Required for `or_return` with >1 return.
- Force callers to use the result with `@require_results` before the proc.
- **Nested procedures** are allowed but do NOT capture the parent's locals (only globals, constants, and their own params are visible).
- **Parameters are immutable** (you cannot reassign a parameter). To mutate the caller's data, take a pointer (`^T`) — but see the guidance below.
- **Don't use pointer params merely to avoid a copy.** Only take `^T` when you truly need to modify the caller's value; otherwise pass by value (or a slice).
- There are **no methods** — data (structs) and behavior (procedures) are separate. To store behavior in data, a struct field can be a procedure value (function-pointer style), useful for interfaces/abstractions.

## defer

`defer stmt` runs `stmt` at the end of the enclosing scope, on every exit path (including early `return`). Multiple defers run in **reverse** order. Ideal for paired setup/cleanup:

```odin
f := os.open("file.txt")
defer os.close(f)
// ... use f; os.close runs however this scope ends
```

A `defer` inside an inner block runs at the end of that block, not the whole procedure. Don't overuse it — it hurts linear readability; reserve it for cleanup that must happen regardless of exit path.

## Pointers

```odin
number := 7
p := &number      // p : ^int  — address of number
p^ += 1           // dereference: read/write THROUGH the pointer
```

`^T` (type: pointer-to-T). `&x` (take address). `p^` (dereference; `^` after the name). `nil` is the zero value — reading/writing through `nil` crashes, so guard with `if p != nil`. Copying a pointer copies only the address; two pointers can refer to the same memory. Indexing a pointer to an array/slice auto-dereferences: use `p[i]`, not `p^[i]`.

## Structs

```odin
Rectangle :: struct { x, y, width, height: f32 }

r: Rectangle                                  // all fields zero
r := Rectangle{ width = 20, height = 10 }     // designated init; unset fields are zero
r  = { x = 10, width = 5 }                    // reassign existing (type inferred; all-else zeroed)
r := Rectangle{ 20, 20, 200, 200 }            // positional init (must list ALL fields)
r.width = 30                                  // field access with .
```

Designated initializers zero every unmentioned field (and even the padding). Structs nest by value — an inner struct's memory lives directly inside the outer one. `size_of(T)` reports the size.

Prefer `r := Rectangle{...}` over `r: Rectangle = {...}` — it reads consistently with places where the type name is mandatory (unions, passing a literal to a proc).

## using

`using` on a struct field promotes the inner fields so you can access them directly, and enables passing the outer type where the inner is expected (subtype-style composition):

```odin
Entity :: struct { id: int, position: [2]f32 }
Player :: struct { using entity: Entity, can_jump: bool }

p := Player{ id = 7, position = {5, 2}, can_jump = true }
_ = p.position                       // reach Entity fields directly
print_position :: proc(e: Entity) { fmt.println(e.position) }
print_position(p)                    // Player accepted where Entity expected
```

(If you want no extra fields at all, a plain alias `Player :: Entity` suffices.) Avoid `using` on plain variables/parameters — it's discouraged.

## Enums

```odin
Computer_Type :: enum { Laptop, Desktop, Mainframe }  // 0, 1, 2
ct: Computer_Type          // zero value = Laptop (0)
ct  = .Mainframe           // shorthand for Computer_Type.Mainframe
```

Explicit values: `enum { Laptop = 1, Desktop, Mainframe }` (subsequent members count on). Custom backing type: `enum u8 { Cat, Rabbit }` (default backing is `int`; only specify for C interop). Enums are **distinct from ints** — cast to compare with a number: `if int(ct) == 5`. Give the `0` value a sensible meaning, since zero-init lands there.

## Unions

Tagged unions store *which* variant they hold (a hidden tag) plus that variant's data. Size = biggest variant + tag.

```odin
My_Union :: union { f32, int, Person_Data }
val: My_Union = int(12)                 // must name the type when assigning
val = Person_Data{ health = 76, age = 14 }   // NOT { ... } alone — type name required

switch v in val {          // branch on current variant
case int:         // v is int here
case f32:         // v is f32 here
case Person_Data: fmt.println(v.age)
}
switch &v in val { case int: v = 7 }    // &v to mutate in place

if f, ok := val.(f32); ok { /* f is the f32 */ }   // check one variant
f := val.(f32)                                     // asserts (crashes) if not f32
if f, ok := &val.(f32); ok { f^ = 7 }              // & -> pointer, to mutate
```

**Zero value is `nil`** (holds no variant) unless declared `union #no_nil { ... }`, in which case the zero value is the first variant. A common pattern: give a struct a `variant: Some_Union` field for per-kind data.

**Maybe** is a built-in single-variant union — a value that's either present or `nil`:

```odin
time: Maybe(int)                        // nil
time = 5
if t, ok := time.?; ok { /* use t */ }  // .? is .(int) with the type filled in
t := time.?                             // asserts if nil
```

(For C-style overlapping-memory unions with no tag, use `struct #raw_union { ... }` — no safety, you track the active field yourself.)

## Slices

A slice `[]T` is a **window into part of an array** — internally just a pointer + length. Creating one allocates nothing.

```odin
nums: [50]int
first20 := nums[0:20]    // []int viewing indices 0..19 (end is exclusive)
last20  := nums[30:]     // 30..end
all     := nums[:]       // whole thing
```

Works on fixed arrays, dynamic arrays, etc. Because a slice shares the source's memory, `for &v in s { v = ... }` mutates the original. **Prefer slices for procedure parameters** — one proc then works with any backing array, and `arr[:]` to pass is free. Bounds are checked at runtime (disable in release with `-no-bounds-check` only when safe).

For a slice that owns heap memory, `make([]T, n)` then `delete(s)` (see memory reference).

## Maps

```odin
ages: map[string]int          // no allocation yet
ages["Karl"] = 35             // insert (may allocate/grow)
a := ages["Karl"]             // lookup; missing key -> zero value
if a, ok := ages["Karl"]; ok { /* existed */ }
has := "Karl" in ages         // membership
no  := "Karl" not_in ages
delete_key(&ages, "Karl")     // remove one entry
delete(ages)                  // free the whole map
for k, v in ages { }          // iterate; for k, &v to mutate values (keys are immutable)
```

Use `make(map[K]V, context.temp_allocator)` (optionally a capacity) for a custom allocator. If you know all keys at compile time, prefer an **enumerated array** (`[Enum]T`) over a map — it's far faster (the enum is the index).

## Sets

Odin has no dedicated set; use a map with an empty-struct value (`struct{}` is 0 bytes):

```odin
seen: map[string]struct{}
seen["Pontus"] = {}                 // add
if "Pontus" in seen { }             // contains
delete_key(&seen, "Pontus")         // remove
```

(This is distinct from `bit_set`, which is for small fixed sets of enum members.)

## Custom iterators

An iterator is any proc returning `(value, second_var, continue_bool)`, driven by a `for x in iter(&it)` loop:

```odin
Slots_Iterator :: struct { index: int, data: []Slot }

slots_iter :: proc(it: ^Slots_Iterator) -> (val: Slot, idx: int, cond: bool) {
    cond = it.index < len(it.data)
    for ; cond; cond = it.index < len(it.data) {
        if !it.data[it.index].used { it.index += 1; continue }
        val = it.data[it.index]; idx = it.index; it.index += 1; break
    }
    return
}

it := Slots_Iterator{ data = slots }
for v in slots_iter(&it) { fmt.println(v) }
```

The loop stops when the last (bool) return is `false`. For mutation, write a second variant whose first return is `^T` (`val = &it.data[...]`); then `val` in the loop is a pointer.
