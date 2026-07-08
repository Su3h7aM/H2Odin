# Manual memory management & the implicit context

Odin has **no garbage collector**. You control the lifetime of dynamically-allocated memory. This is the core skill of writing Odin well.

## Stack vs dynamic memory

Local variables live on the **stack** and are freed automatically when their procedure returns — this is *not* what "manual memory management" refers to (every language does it). Manual management is about **dynamic memory**: allocations whose size need not be known at compile time and which can **outlive the procedure that made them**. Because it outlives the stack frame, something must decide when it's freed — that's you.

> Manual memory management = manual control over the **lifetime** of dynamically-allocated memory. When freeing feels hard, the real question is always "what is this memory's lifetime?"

## Allocators

You rarely grab memory directly; you ask an **allocator**. One is always available as `context.allocator` (a heap allocator on desktop OSes; a WASM allocator in the browser). Procedures that allocate take a trailing `allocator := context.allocator` parameter, so you can override it per-call.

## Two allocate/free pairs

**Single values — `new` / `free`:**

```odin
number := new(f32)          // number : ^f32, points to heap-allocated memory
free(number)                // release it

cat := new(Cat)             // dynamically allocate a struct
cat^ = Cat{ name = "Fluffy", age = 12 }
free(cat)
```

`new(T)` returns `^T`. If you passed a custom allocator to `new`, pass the *same* allocator to `free`.

**Containers — `make` / `delete`** (dynamic arrays, maps, slices-with-memory, strings). These hold their buffer behind an internal pointer, so a plain `free` can't reach it; `delete` knows how:

```odin
arr: [dynamic]int           // empty, no allocation yet
append(&arr, 5)             // FIRST append allocates (note the & — append needs a pointer)
delete(arr)                 // free the buffer

s := make([]int, 4096)      // slice that owns 4096 ints of heap memory
delete(s)

m := make(map[string]int)
m["a"] = 1
delete(m)
```

`delete` takes the **value**; `clear(&arr)` takes a **pointer** and only resets length to 0, keeping the capacity/buffer so you can refill without reallocating. Removing single elements: `unordered_remove(&arr, i)` (fast, reorders) or `ordered_remove(&arr, i)` (preserves order, slower). Neither shrinks capacity.

## How the dynamic array grows

`[dynamic]T` is internally `{ data: rawptr, len, cap: int, allocator }`. First `append` allocates capacity for **8** elements (not 1) because allocations are expensive; it over-allocates and only reallocates when `len == cap` (capacity then grows, e.g. 8 → ~24). On growth the buffer may move to a new address and the old one is freed — which is why holding a pointer *into* a dynamic array across an append is dangerous.

Preallocate to avoid growth: `make([dynamic]int, 0, 20)` (len 0, cap 20). `make([dynamic]int, 20)` gives len 20 **and** cap 20 (20 zeroed items).

## Copies share memory — clone deliberately

Copying a container copies its **header**, not its buffer. Both copies point at the same memory:

```odin
a: [dynamic]int
append(&a, 5)
b := a          // b.data == a.data — SAME buffer
// growing `a` now may move/free a's buffer, leaving b dangling or stale
```

To get an independent copy: `b := slice.clone_to_dynamic(a[:])` (import `core:slice`). The same "header copy" logic applies to slices and strings.

## The temporary allocator — for short lifetimes

`context.temp_allocator` is for memory needed only briefly (one algorithm, one game frame). You do **not** free temp allocations individually; you wipe them all at once:

```odin
numbers := make([dynamic]int, context.temp_allocator)
append(&numbers, 5)
// ... no delete ...

free_all(context.temp_allocator)   // release everything temp-allocated so far
```

Place `free_all(context.temp_allocator)` at a natural boundary — e.g. end of a game's main loop:

```odin
for game_should_run() {
    game_update()
    game_draw()
    free_all(context.temp_allocator)   // lifetime of temp memory = one frame
}
```

Forgetting `free_all` leaks. Placing it wrong (freeing data you still need) is the other failure. The rule: **everything sharing one (arena/temp) allocator should share one lifetime.** If the temp allocator feels awkward, you're probably mixing lifetimes and need separate arena allocators (see the book's chapter 13: tracking allocator for leak detection, arena allocators for grouped lifetimes).

## Allocation can fail

`new`, `make`, `append` return an optional trailing `Allocator_Error`:

```odin
arr, err := make([dynamic]f32, 100)
if err != nil { /* e.g. .Out_Of_Memory */ }
```

On powerful systems this rarely matters; `#optional_allocator_error` (see error-handling reference) lets callers ignore it.

## Scripts can ignore all of this

All memory is freed by the OS when a program exits. For a short-lived script (runs, does work, exits), just allocate freely and don't manage anything — the process ends before leaks matter. Only long-running or large-data programs need disciplined freeing. (Similarly, allocating something once at startup that must live for the whole program needs no `free` — exit reclaims it. Add one only to satisfy leak analyzers like Valgrind/ASan.)

---

# The implicit context

Every procedure call is silently passed a hidden `context` parameter — this is where `context.allocator` comes from without you declaring it. `fmt.println("hi")` receives the current scope's `context` automatically.

The context struct's fields:

```odin
Context :: struct {
    allocator:              Allocator,   // default allocator
    temp_allocator:         Allocator,   // default temp allocator
    assertion_failure_proc: Assertion_Failure_Proc, // runs when assert() fails
    logger:                 Logger,      // used by core:log
    random_generator:       Random_Generator, // used by core:math/rand
    user_ptr:               rawptr,      // free slots for your own data
    user_index:             int,
    _internal:              rawptr,
}
```

## Injection + the scope rule

Because context flows into every call, you can change a field before a call and the callee uses your value — even code you can't modify:

```odin
context.allocator = context.temp_allocator
my_ints := make_lots_of_ints()   // everything inside now uses temp memory
```

**Crucial:** when the scope ends, changes to `context` revert automatically. A temporary swap affects only that block and the calls it makes; it never permanently mutates global state. (Under the hood, modifying `context` copies it to a new stack variable and passes pointers to that copy for the rest of the scope.)

## Prefer explicit allocator params

Despite the injection trick, the idiomatic choice is an explicit allocator parameter on procedures that allocate:

```odin
make_lots_of_ints :: proc(allocator := context.allocator) -> []int {
    ints := make([]int, 4096, allocator)
    // ...
    return ints
}
my_ints := make_lots_of_ints(context.temp_allocator)   // override at the call site
```

It defaults to `context.allocator` (callers who don't care get the default) and it **documents** that the proc allocates and returns owned memory. Only override `context.allocator` directly when (1) a proc gives you no allocator parameter to inject into, or (2) you genuinely want *all* code in a scope on a different allocator — classically, swapping it in the first lines of `main` to run the whole program under a leak-tracking allocator.

## Other context fields (brief)

- `context.logger = log.create_console_logger()` at the top of `main` routes all `log.info`/`log.error`/etc. through it (the logger is **not** set by default). File logger: `log.create_file_logger(handle)`. Severities: `debug < info < warn < error < fatal < panic` (`panic` also crashes). `...f` variants take format strings.
- `context.random_generator` / `rand.reset(seed)` control randomness reproducibly.
- `context.assertion_failure_proc` customizes what `assert(cond, "msg")` does on failure. `assert` is stripped by `-disable-assert`; use `ensure(cond, "msg")` for a check that always runs.
- `context.user_ptr` / `user_index` smuggle your own data into callbacks (e.g. a sort comparator).

Opt a proc out of receiving context with a calling convention: `proc "contextless" () {}` (minor speedup for hot paths) or `proc "c" () {}` (for C interop).
