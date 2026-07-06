# Type Modes

H2Odin can generate bindings in two modes. They differ in philosophy, and the difference lives almost entirely in how C types become Odin types.

## ABI mode — conservative

ABI mode preserves the C API and ABI as faithfully as it can, using Odin's C-compatible types from `core:c` (`c.int`, `c.size_t`, and so on). It aims for maximum compatibility and minimal surprises. If you want the binding to match the C library as closely as possible, this is the mode to choose.

## Idiomatic mode — aggressive

Idiomatic mode tries to make the bindings feel as though the library had been written in Odin. It prefers native Odin types (`i32`, `f64`, `string`), Odin naming, and small conversions where they are safe. The ideal experience is that someone using the bindings would not realize they are calling into C at all.

Idiomatic mode is best understood as a layer *on top of* ABI mode. The real `foreign` declarations are always the faithful ABI ones; idiomatic wrappers are added only where a conversion does genuine, predictable work. Where no conversion applies, the idiomatic output is just the ABI output with nicer type names — no wrapper is generated. Wrappers should never appear as empty boilerplate; they exist only where they earn their place.

## Guidelines for choosing idiomatic types

A few principles guide what idiomatic mode may and may not do:

- **Only substitute a native type when it is provably the same on the target.** For example, whether a C `long` matches `i64` or `i32` depends on the platform. Idiomatic mode may only use a native type when it is known to have the same width and layout as the C type on the target being generated. "More idiomatic" never justifies a substitution that changes the ABI.
- **A wrapper converts shape, it does not invent meaning.** Turning an Odin `string` into a C `cstring` is a shape conversion — safe and deterministic. Deciding that a `float *` and a nearby `count` form an array is *meaning*, and meaning is not something the generator infers on its own. Shape conversions can be automatic; meaning comes from configuration.
- **Wrappers are optional.** Even in idiomatic mode, if wrappers are turned off, any declaration that would need one falls back to its ABI form. Idiomatic naming still applies, since renaming needs no wrapper.

## Pointers

C pointers are ambiguous, and how H2Odin resolves them is one of the clearer expressions of the "honesty about uncertainty" principle.

Every C pointer is lowered into one concrete Odin interop type: `^T`, `[^]T`, `cstring`, or `rawptr`. H2Odin deliberately does *not* emit a permissive, catch-all pointer type to paper over ambiguity — that would push the uncertainty onto whoever uses the bindings.

When the correct lowering can be proven from the header, the decision is treated as certain. When it cannot, H2Odin applies a documented default, marks the decision as a guess, emits a diagnostic, and allows the configuration to override it.

The default depends on the kind of pointer. As a sketch of the intent:

- `void *` becomes `rawptr`.
- `const char *` becomes `cstring`.
- A fixed C array `T[N]` becomes `[N]T`.
- A bare `T *` of unknown count defaults to a single `^T`, *not* a multi-pointer.

Array semantics — `[^]T`, or a full slice — are chosen only when there is evidence for them, such as a neighbouring `count` / `len` / `size` parameter, or when the configuration asks for them. Defaulting a lone `int *out` to a single pointer keeps the common case honest; upgrading to an array is done on evidence, not on a hunch.

Note that pointer lowering (which produces `cstring`, `rawptr`, and so on) happens first, as the faithful interop step. Idiomatic niceties — for instance turning a `cstring` into an Odin `string` with a wrapper — are a later layer on top of that.
