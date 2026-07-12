# Spec 0011 — Vendor parity: faithful ABI core, explicit idiomatic layer

**Status:** accepted; implementation pending  
**Date:** 2026-07-11

## Context

The validation corpus now produces checked Odin for raylib, Box3D, cgltf,
curl, and miniaudio, but "passes `odin check`" is a lower bar than the
maintained bindings in Odin's `vendor:` collection. The official packages add
three different kinds of value:

1. ABI facts and platform linkage that must be correct for any binding;
2. ABI-identical foreign-declaration curation (`[^]T`, `cstring`, `#by_ptr`,
   calling conventions, `require_results`);
3. Odin procedure bodies and library-specific conveniences.

Those categories must not be treated as one feature. In particular, matching
a hand binding does not justify changing ABI mode's call shape, and the
presence of a helper in a vendor package does not make it a generally
derivable binding-generator feature.

The authoritative Odin documentation establishes the relevant language
facts:

- foreign procedures default to the C calling convention; non-C conventions
  must be stated, and procedure types are compatible only when their calling
  conventions and parameter types match;
- `@(default_calling_convention)`, `@(link_prefix)`, and
  `@(require_results)` are supported foreign-block attributes;
- `cstring` is the C zero-terminated-string interop type;
- `[^]T` is the foreign multi-pointer: it has pointer representation, supports
  indexing and slicing, and exists specifically to document C array pointers;
- `[]T` is a two-field slice (pointer plus length), so it is not a direct
  spelling of a C `T *` parameter;
- `#type` on a procedure type is documentary only.

Primary documentation:

- <https://odin-lang.org/docs/overview/#foreign-system>
- <https://odin-lang.org/docs/overview/#multi-pointers>
- <https://odin-lang.org/docs/overview/#cstring-type>
- <https://odin-lang.org/docs/overview/#type>
- <https://odin-lang.org/news/binding-to-c/>

The pinned Odin `dev-2026-07a` vendor tree supplies concrete usage evidence:

- `vendor:curl` and `vendor:raylib` select libraries and system dependencies
  by OS/architecture;
- `vendor:curl` uses build-tagged aliases for `posix.sockaddr` versus
  `win32.sockaddr`;
- `vendor:cgltf` uses local faithful foreign declarations behind wrappers that
  turn out-parameters into named results;
- `vendor:cgltf`, `vendor:raylib`, `vendor:box3d`, and `vendor:miniaudio` use
  `[^]T` for array pointers;
- `vendor:box3d` uses `#by_ptr` for selected pointer-to-struct inputs;
- all five packages use `link_prefix`, `default_calling_convention`, or
  `require_results` where the maintainer has domain knowledge;
- Box3D ID utilities and math, raylib formatting/allocator adapters, and most
  helper bodies are hand-written library code, not mechanical FFI declarations.

## Decision

### 1. Parity has three levels

H2Odin uses these canonical terms:

| Level | Meaning | Required for close parity? |
|---|---|---|
| **ABI correctness** | Correct symbol, calling convention, representation, layout, foreign type, and platform library for the generation target | Yes, in both modes |
| **Foreign-surface curation** | ABI-identical Odin spellings and attributes that document C intent without adding a procedure body | Yes where proven or explicitly configured |
| **Ergonomic wrapper** | A generator-authored Odin procedure that changes call shape while calling a faithful foreign declaration | Idiomatic mode only, closed set |

Library-specific helpers are outside these levels. They remain ordinary Odin
written beside or on top of generated output.

### 2. ABI mode is the faithful reference surface

ABI mode emits no generated procedure bodies. It preserves C arity and pointer
levels and uses C-compatible type spellings. It may still emit facts required
for correctness:

- the captured calling convention on every foreign procedure and procedure
  type;
- target-appropriate imports, foreign libraries, and system dependencies;
- platform type aliases or qualified types whose layout is owned by Odin;
- `@(link_name)`, `@(deprecated)`, and other direct declaration metadata;
- measured layout constructs such as explicit-width `bit_set` and proven
  `bit_field` regions.

ABI mode does not automatically select `#by_ptr`, merge pointer/count pairs,
turn out-parameters into results, or substitute slices. Its unknown-pointer
default remains `^T` plus a diagnostic.

`[^]T` is ABI-identical to a pointer and may be used in ABI mode when the
header proves array semantics (an array parameter decayed by C) or configuration
states the contract. A neighbouring name such as `count` is a candidate fact,
not proof by itself.

### 3. Idiomatic mode is faithful ABI plus an optional ergonomic layer

Idiomatic mode keeps the current proven native leaf spellings and opaque-handle
rules. It may additionally emit generated wrapper procedures, but every wrapper
retains a faithful foreign declaration as its call target.

The initial closed wrapper conversion set is:

1. **Out-parameter to result.** A selected `^T`/`^^T` output parameter becomes
   a named wrapper result. The C return value remains a result unless config
   explicitly marks it as non-semantic.
2. **Pointer plus count to input slice.** A selected `T *` plus integer count
   becomes one `[]T` wrapper parameter. The wrapper passes `raw_data(slice)`
   and the checked length conversion to the faithful declaration.

Borrowed output slices are a later extension: a returned/output pointer plus
count can become a slice only after policy has an explicit borrowed-lifetime
contract and the count is available at wrapper return.

`#by_ptr` is foreign-surface curation rather than a wrapper conversion. A
selected non-null, call-borrowed pointer-to-value parameter may be exposed as
`#by_ptr value: T` in idiomatic mode. C `const` describes mutation through the
pointer but does not prove non-nullness or that the callee does not retain it.

Conversions are selected per procedure/parameter through policy. Analysis may
provide candidates, but it never enables a wrapper on naming evidence alone.
The wrapper plan is explicit data in the transformed IR; Emission serializes
it and does not rediscover conversions.

### 4. String conversion is not in the initial wrapper set

The official vendor bindings predominantly expose `cstring` at the FFI
surface. Converting Odin `string` to `cstring` can allocate, and converting a
returned `cstring` to `string` does not answer ownership or lifetime. Generic
`string` wrappers therefore remain outside the first parity milestone.

Literal and already-`cstring` callers retain the direct binding. A later string
conversion requires an explicit allocation/lifetime contract and a separate
specification.

### 5. Struct pointer/count folding is later than procedure wrappers

Official `vendor:cgltf` folds many adjacent C struct fields into Odin slices.
That can preserve bytes only when pointer size, count width, field order,
alignment, and total record layout all match the Odin slice header. It also
changes the record's public field model.

H2Odin does not include this in the initial wrapper implementation. If added,
it is idiomatic-only, explicit-policy, and guarded by a whole-record layout
proof analogous to bit-field emission. Failure leaves the faithful fields
unchanged.

### 6. Platform linkage and calling conventions precede wrappers

The generator already captures calling-convention facts but emits every proc
as `"c"`. This is an ABI gap. Emission must map supported captured conventions
for both function declarations and function-pointer types, and must fail with
an error diagnostic when a non-default convention cannot be represented.

The single `foreign.import_lib` string is insufficient for the official
packages' Windows/Linux/Darwin/wasm layouts and system-library dependencies.
The future configuration surface is structured data interpreted by the
generator, not raw Odin:

```lua
config.foreign.targets = {
  windows_amd64 = { libraries = { "lib/foo.lib" }, system = { "user32.lib" } },
  linux_amd64   = { libraries = { "lib/libfoo.a" }, system = { "m", "pthread" } },
  fallback      = { libraries = { "system:foo" } },
}
```

Exact target keys and validation belong to the implementation ticket; the
contract is fixed here: config selects library values and target predicates
from a closed schema, while the generator authors the `when` and
`foreign import` source.

### 7. Metadata curation is separate from wrappers

The following are useful but do not justify wrapper machinery:

- `require_results`: policy-controlled metadata, applicable to a foreign
  block or selected procedures;
- `default_calling_convention`: an emission compression when all declarations
  in a block share a convention; correctness comes from each IR fact;
- `#type` on callback aliases: optional documentary output with no compiler
  semantics;
- field tags and raw-union tags: existing explicit policy, not inferred
  domain meaning.

### 8. Library-specific helper bodies remain hand-written

The generator will not translate C function-like macros or static-inline C
bodies, synthesize math libraries, create allocator adapters, recreate
formatting systems, or invent ID serialization helpers as part of vendor
parity. These behaviors are domain code and are not derivable from declarations
alone.

`output.footer_per_header` and ordinary same-package Odin files are the
supported seam for those helpers. Generated wrappers differ because they come
from a small closed conversion algebra over a faithful foreign declaration.

### 9. The wrapper module must be deep

Transformation owns one wrapper-planning interface that accepts a faithful
procedure plus policy decisions and produces either no wrapper or one complete
wrapper declaration. The implementation hides name allocation, hidden ABI
declarations, argument/result mapping, import requirements, and diagnostics.

Emission consumes wrapper declarations like any other planned declaration.
Policy does not expose body fragments, statement templates, temporary names,
or allocator operations. Tests cross the same wrapper-plan interface used by
the pipeline.

## Required implementation order

1. Emit captured calling conventions and reject unrepresentable conventions.
2. Add structured target linkage and platform foreign-type aliases; validate
   on at least Unix and Windows targets.
3. Make output publication transactional, because two-layer generation
   increases the cost of mixed/stale files.
4. Curate raw foreign surfaces with explicit/proven `[^]T`, `require_results`,
   and selected `#by_ptr`; keep ABI-mode defaults unchanged.
5. Add wrapper IR and out-parameter-to-result conversion.
6. Add pointer-plus-count input-slice conversion.
7. Re-evaluate borrowed output slices after lifetime vocabulary exists in
   policy.
8. Re-evaluate struct pointer/count folding under a whole-record proof.

## Acceptance

- The same header/config in ABI mode emits no procedure body.
- Enabling an idiomatic wrapper does not remove the faithful foreign
  declaration it calls.
- Every wrapper conversion has a negative test for nullability, ownership,
  lifetime, width, or arity conditions it does not claim to solve.
- A non-C calling-convention fixture checks both direct procs and callbacks.
- Platform-link tests render and `odin check` target-specific files without
  requiring arbitrary source in Lua.
- `vendor:cgltf`-style out-parameter wrappers and slice inputs are reproducible
  from policy using the closed conversion set.
- ABI output for all existing examples remains wrapper-free and byte-stable
  except where correcting a demonstrated ABI fact.
- Library-specific helpers continue to live outside generated core output.

## Consequences

- Milestone 6 is no longer a general "make it idiomatic" bucket. It is the
  bounded wrapper work defined here.
- Platform linkage and calling-convention emission are prerequisites, not
  wrapper features.
- `cstring -> string` is removed from the initial wrapper milestone.
- Official bindings remain evidence for recurring patterns, not templates to
  copy wholesale.
- ABI and idiomatic packages may expose different public call shapes, but both
  retain the same faithful C ABI beneath them.

## See also

- [`../type-modes.md`](../type-modes.md)
- [`../vendor-example-audit-2026-07-11.md`](../vendor-example-audit-2026-07-11.md)
- [`0010-posix-libc-type-mapping.md`](0010-posix-libc-type-mapping.md)
- [`0003-multi-file-odin-emission.md`](0003-multi-file-odin-emission.md)
- [`../../ROADMAP.md`](../../ROADMAP.md)
