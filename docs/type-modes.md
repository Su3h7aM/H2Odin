# Type Modes

H2Odin can generate bindings in two modes. They differ in philosophy: which
Odin spelling family to use for the **same** C declarations when more than one
spelling is proven ABI-safe.

## ABI mode — conservative

ABI mode preserves the C API and ABI as faithfully as it can, using Odin's C-compatible types from `core:c` (`c.int`, `c.size_t`, and so on). It aims for maximum compatibility and minimal surprises. If you want the binding to match the C library as closely as possible, this is the mode to choose.

Incomplete tag records (`typedef struct T T;` used as `T *`) stay as
`T :: struct {}` with explicit pointer levels (`^T`, `^^T`) — call sites
parallel the C shape.

## Idiomatic mode — faithful core plus ergonomics

Idiomatic mode tries to make the bindings feel as though the library had been written in Odin. It prefers native Odin type spellings (`i32`, `f64`, `cstring`) and Odin naming where they are safe.

Today, idiomatic mode is a different spelling policy for the same C declarations. Spec 0011 extends that contract with an optional generator-authored ergonomic layer: a wrapper may change the Odin call shape, but it always calls a faithful foreign declaration retained underneath. ABI mode never emits those bodies.

Incomplete tag records collapse to the handle idiom: `T :: distinct rawptr`
with one pointer level removed at every reference (`T*` → `T`, `T**` →
`^T`). That is byte-identical to `^struct {}` and matches hand bindings.
Override per name with `types.opaque` (see [spec 0007](specs/0007-opaque-tag-records.md)).

## What mode may and may not change

**Mode may** choose among proven ABI-identical *spellings* of the same C
entity (leaf widths confirmed by measurement; incomplete-tag handle vs
empty-struct-plus-pointer). Client code shapes can therefore differ between
modes (`^Stmt` vs `Stmt`) — modes are not drop-in interchangeable.

**ABI mode may never** change arity, invent conversion wrappers, or rewrite
meaning. **Idiomatic mode may** change call shape only through the closed,
policy-selected wrapper conversions in [spec 0011](specs/0011-vendor-parity-and-idiomatic-wrappers.md).
Naming evidence such as a neighbouring `count` remains a candidate fact, not
permission to infer semantics by itself.

### Named POSIX / libc types (one spelling, both modes)

ISO C scalars dual-map (`size_t` → `c.size_t` / `uint`). **Named POSIX and
libc typedefs** (`off_t`, `pid_t`, `time_t`, `sockaddr`, …) are a separate
class and do **not**: Odin’s `core:sys/posix` / `core:c/libc` spellings are
`distinct`, OS-width-specific, and sometimes not integers at all (`mode_t`
is a `bit_set`), so peeling them to bare `i32`/`i64` by mode would break
interop with every package that uses them correctly. Spec 0010 fixes a
**single** spelling in both modes, named through the **defining package**:
`posix.off_t`, `posix.sockaddr`, `libc.time_t`, `libc.timespec`. Users who
want a raw integer opt in per-name via `types.map`; mode is not the lever.
See [spec 0010](specs/0010-posix-libc-type-mapping.md).

## Guidelines for choosing idiomatic types

A few principles guide what idiomatic mode may and may not do:

- **Only substitute a native type when it is provably the same on the target.** For example, whether a C `long` matches `i64` or `i32` depends on the platform. Idiomatic mode may only use a native type when it is known to have the same width and layout as the C type on the target being generated. "More idiomatic" never justifies a substitution that changes the ABI.
- **A spelling change converts representation, it does not invent meaning.** Turning a C `int` into Odin `i32` is safe when the measured size proves it. Deciding that a `float *` and a nearby `count` form an array is *meaning*, and meaning is not something the generator infers on its own. Meaning comes from configuration.

## Pointers

C pointers are ambiguous, and how H2Odin resolves them is one of the clearer expressions of the "honesty about uncertainty" principle.

Every C pointer in the faithful foreign declaration is lowered into one concrete Odin interop type: `^T`, `[^]T`, `cstring`, or `rawptr`. H2Odin deliberately does *not* emit a permissive, catch-all pointer type to paper over ambiguity — that would push the uncertainty onto whoever uses the bindings.

When the correct lowering can be proven from the header, the decision is treated as certain. When it cannot, H2Odin applies a documented default, marks the decision as a guess, emits a diagnostic, and allows the configuration to override it.

The default depends on the kind of pointer. As a sketch of the intent:

- `void *` becomes `rawptr`.
- `const char *` becomes `cstring`.
- A fixed C array `T[N]` becomes `[N]T`.
- A bare `T *` of unknown count defaults to a single `^T`, *not* a multi-pointer.

`[^]T` is Odin's ABI-identical foreign multi-pointer and may replace `^T` in
the faithful declaration when array semantics are proven by the C declaration
or explicitly configured. A neighbouring `count` / `len` / `size` name is not
proof by itself. Defaulting an otherwise unknown pointer to `^T` remains the
conservative behavior.

A full slice `[]T` is pointer plus length, so it is never a direct respelling
of one C pointer parameter. Pointer-plus-count becomes a slice only in an
idiomatic wrapper that keeps the original pointer and count in its hidden
foreign declaration.

Note that pointer lowering (which produces `cstring`, `rawptr`, and so on) happens first, as the faithful interop step. It is still type spelling: `const char *` can become `cstring` without any generated conversion code.

## What parity includes

Both modes require correct symbols, calling conventions, target libraries,
foreign platform types, and record layout. Those are ABI facts, not ergonomic
options. Idiomatic mode may additionally use selected `#by_ptr` inputs,
out-parameter results, and pointer-plus-count slice wrappers under spec 0011.

Hand-written vendor helpers such as math procedures, allocator adapters,
formatters, ID serialization, and translations of static-inline C bodies are
not mode behavior. They belong in ordinary Odin files layered on the generated
binding.
