# Error handling in Odin

**Odin has no exceptions** — no `throw`, no `try`/`catch`, no hidden control flow. An error is an ordinary extra return value you are expected to check. Everything else is ergonomics on top of that.

## The one rule everything depends on

**Return the error as the LAST return value.** The helper operators (`or_else`, `or_return`) inspect the *last* return value to decide success vs failure. Put it anywhere else and they stop working. Results first, error last.

Success is represented by the **zero value** of the error type. This is why enum error types put `None` first (value 0) and why the operators can check "is the error zero?" without knowing your specific type.

## Three ways to represent an error

### 1. `bool` — did it work?

```odin
find_cat :: proc(cats: []Cat, name: string) -> (Cat, bool) {
    for c in cats {
        if c.name == name { return c, true }
    }
    return {}, false          // {} is the zero Cat; false says "don't trust it"
}

if cat, ok := find_cat(cats, "Molly"); ok {
    fmt.printfln("Found %v, age %v", cat.name, cat.age)
}
```

The bool communicates "is it OK to use the other return values?"

### 2. `enum` — which of several failures?

```odin
Load_Config_Error :: enum { None, File_Unreadable, Invalid_Format }  // None = 0 = zero value

load_config :: proc(filename: string) -> (Config, Load_Config_Error) {
    data, ok := os.read_entire_file(filename, context.temp_allocator)
    if !ok { return {}, .File_Unreadable }
    result: Config
    if json.unmarshal(data, &result, allocator = context.temp_allocator) != nil {
        return {}, .Invalid_Format
    }
    return result, .None
}

config, err := load_config("config.json")
if err != .None {
    fmt.eprintln("Failed:", err)     // eprintln -> standard error stream
    config = DEFAULT_CONFIG
}
```

`fmt.eprintln` prints to stderr (separate from stdout). With a logger set up you can use `log.error(...)` instead.

### 3. `union` — which error, *plus* attached data

When an error needs to carry detail (a message, a location), make the error type a union of error types; each variant can be its own struct:

```odin
Error :: union { Parse_Error, Open_File_Error, Help_Request, Validation_Error }
Validation_Error :: struct { message: string }   // carries a payload
```

This is what the standard library does (e.g. `core:flags`). Most expressive: you get both "which kind" and "the details."

## `or_else` — fallback value on error

```odin
config := load_config("config.ini") or_else DEFAULT_CONFIG
```

Mechanics: looks at the last return (the error); if it's the zero value, you get the real result; if non-zero, you get the right-hand value instead. `config` is always valid afterward. Trade-off: you lose the chance to log *why* it failed.

## `or_return` — propagate the error upward

The workhorse; ubiquitous in the standard library. "If this failed, set *my* error return to that error and return immediately."

```odin
clone :: proc(s: string, allocator := context.allocator, loc := #caller_location)
    -> (res: string, err: mem.Allocator_Error) #optional_allocator_error {
    c := make([]byte, len(s), allocator, loc) or_return   // on error: err = that error; return now
    copy(c, s)
    return string(c[:len(s)]), nil                        // nil error = success
}
```

- If `make`'s error is non-zero → `clone`'s named `err` is set to it and `clone` returns immediately. The error bubbles up. `or_return` **consumes** the error (after that line only the result remains).
- If the error is zero → the result is assigned to `c` and execution continues.

**Why named returns?** `or_return` sets `err` on early return but never touches `res` (it keeps its zero value). For that, the returns need names to assign to — so `or_return` **requires named return values when there is more than one return**. This is exactly why "naked returns" exist in the language.

**Don't over-propagate.** It's tempting to wrap everything in one big error union and `or_return` all of it — but that dumps every failure on your caller when some errors are yours to handle locally. Deciding "handle here vs pass up" is a real design choice. In `clone`, passing up is right *because the caller supplied the allocator*, so allocation failures are the caller's business.

Loop variants: `or_continue` (skip to next iteration on error) and `or_break` (exit the loop on error).

## Opting out of checking: `#optional_allocator_error` and `#optional_ok`

Normally you must handle every return value. These tags let callers skip one.

`#optional_allocator_error` (seen on `clone` above) lets callers ignore the allocation error:

```odin
s := strings.clone("Hellope!")   // no error variable required
```

Rationale: allocation almost never fails on normal machines, and if it does you're out of memory and probably crashing anyway. Works only with `Allocator_Error`.

`#optional_ok` does the same for a trailing `bool`:

```odin
divide_and_double :: proc(n, d: f32) -> (f32, bool) #optional_ok {
    if d == 0 { return 0, false }
    return (n/d)*2, true
}
num := divide_and_double(25, 5)   // ignoring the bool is allowed
```

But usually **don't** ignore it: `divide_and_double(0, 10)` and `divide_and_double(10, 0)` both return `0`, yet one is a valid result and one is a divide-by-zero error. Discard the bool and the two become indistinguishable — the error value was the only thing telling them apart. That is the whole argument for Odin's model: the error isn't decoration, it's information you choose to keep or discard.

## Summary

Errors are the last return value; success is the zero value; `bool`/`enum`/`union` scale with the detail you need; `or_else` gives a fallback, `or_return` propagates (and forces named returns); `#optional_*` tags let you opt out of checking at the cost of the information the error carried.
