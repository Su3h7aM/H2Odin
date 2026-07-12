# Idiomatic conversion trade-offs — 2026-07-12

**Status:** evaluation only; implementation deferred  
**Scope:** possible future idiomatic-mode conversions beyond the closed set in
[spec 0011](../specs/0011-vendor-parity-and-idiomatic-wrappers.md) (out-param
results + pointer/count input slices, already shipped).

## Frame of reference

H2Odin already separates three layers:

| Layer | What it may do | Example |
|-------|----------------|---------|
| **ABI spelling** | Same representation, different Odin name | `c.int` ↔ `i32` when measured equal |
| **Foreign-surface curation** | Still `---` / field shape; ABI-identical | `cstring`, `[^]T`, `#by_ptr` |
| **Ergonomic wrapper** | Changes arity or ownership story; keeps faithful foreign underneath | out-param → multi-result |

Vendor packages (Odin `dev-2026-07a`) mostly sit on layers 1–2 for strings and
chars. They do **not** systematically wrap C APIs as Odin `string` / `rune`.

Litmus (project principle): prefer generation-time decisions; never invent
runtime-only safety that headers cannot justify; stay close to hand-written
`vendor:` code.

---

## 1. `cstring` vs Odin `string`

### Facts

- Odin `cstring` ≈ C `char *` / `const char *` (null-terminated, pointer-sized).
- Odin `string` is **two words**: `data: [^]u8` + `len: int` (not null-terminated by representation).
- `string` ↔ `cstring` is **not** a free respelling:
  - **Input** `string` → `cstring` typically needs a temporary NUL-terminated
    buffer (allocate or stack buffer) unless the string is known to already
    be NUL-terminated in place (unsafe / non-general).
  - **Output** `cstring` → `string` needs a length (`len(cstring)` / scan) and
    a lifetime story: who owns the bytes? library static? caller-freed?
    valid until next call?

### Vendor evidence

Raylib, curl, cgltf foreign surfaces overwhelmingly use **`cstring`** for text
parameters and many results (`InitWindow(..., title: cstring)`,
`GetMonitorName -> cstring`, glTF `name: cstring` fields). Hand helpers that
want Odin `string` sit *beside* the binding (e.g. formatters), not as the FFI
default.

### Cost / trade-off

| Direction | Cost | Risk if automatic |
|-----------|------|-------------------|
| Input wrapper `string` → foreign `cstring` | Temp alloc or stack buffer per call; allocator policy | Hidden alloc; failure mode; thread-local buffer races |
| Output wrapper `cstring` → `string` | Length scan; may copy | Use-after-free if library reuses buffer; double-free if caller frees wrong view |
| Field type `cstring` → `string` in records | Changes record layout (2 words vs 1) | **ABI break** — never a silent field rewrite |

### Recommendation

- **Do not** auto-map foreign params/results/fields to `string`.
- **Optional later:** explicit `procs.wrappers` conversion with a **named
  contract**, e.g. `string_in = "temp_cstring"` (generator documents allocator)
  or `string_out = "borrowed_until_next_call"` — only when policy states it.
- Keep faithful foreign as `cstring` (current default for `const char *`).
- Closest to vendor: leave `cstring` as the idiomatic FFI type; Odin users
  already pass string literals to `cstring` parameters in many cases.

**Effort:** high (spec + allocator/lifetime vocabulary + negative tests).  
**Vendor closeness gain:** low–medium (vendor itself stays on `cstring`).  
**Priority:** low until a concrete allocator/lifetime design exists.

---

## 2. `char` / `char[]` vs `rune`

### Facts

- C `char` is 8-bit (signedness target-dependent); often a **byte**, not a Unicode scalar.
- Odin `rune` is a **32-bit** Unicode code point (`i32`-sized).
- Odin `u8` / `byte` match C byte/char for buffers and UTF-8 payloads.
- C APIs almost never mean “Unicode scalar” when they say `char` / `char *`;
  they mean bytes or NUL-terminated UTF-8 *bytes*.

### Vendor evidence

Text APIs use `cstring` or `[^]u8` / `[^]byte` (e.g. raylib `LoadFileText -> [^]byte`,
unload takes `[^]byte`). `rune` appears in Odin *application* code (iteration
over strings), not as the default C interop type for `char`.

### Cost / trade-off

| Mapping | When safe | When wrong |
|---------|-----------|------------|
| `char` → `u8` / `byte` | Byte buffers, UTF-8 payloads | Rare “character as integer” APIs that assume signed `char` |
| `char` → `i8` / `c.char` | Match core:c / signedness | Less “pretty” |
| `char` → `rune` | Almost never for C FFI | **Size and meaning change** (1 byte → 4); arrays of char become wrong |

`char[N]` as `[N]rune` is an **ABI and layout break**.  
`char *` as `[^]rune` is wrong for UTF-8 C strings.

### Recommendation

- Prefer **byte-oriented** idiomatic spellings (`u8`, `byte`, `cstring`, `[^]u8`).
- Do **not** introduce automatic `rune` for C `char` types.
- Optional: documentation note that Odin string iteration yields `rune`s from
  UTF-8 `string`/`cstring` content after a deliberate conversion to `string`.

**Effort:** low if we only document; high if we invent rune wrappers.  
**Vendor closeness:** automatic `rune` would **diverge** from vendor.  
**Priority:** do not pursue as a default conversion.

---

## 3. Arrays → slices / dynamic arrays

### Already landed (procedure params)

- Fixed C array params / configured multipointers → `[^]T` (ABI-identical).
- Pointer + count → **wrapper** `[]T` with `raw_data` + `len` (M6).

### Fixed-size fields `T[N]`

- Faithful: `[N]T` (already).
- Slice field `[]T` is **two words** vs `N * size_of(T)` — layout break unless
  the C layout is proven identical to an Odin slice header (it almost never is
  for embedded arrays).

### Pointer + count **struct fields** (vendor:cgltf)

Vendor rewrites many `T *ptr; size_t count;` pairs into `[]T` **inside
records**. That is only sound if:

- field order, sizes, alignment match Odin slice header (ptr then len), and
- count width equals `int` / pointer-sized length as used by the Odin target, and
- the pair is not interleaved with other fields in a way that breaks offsets.

Spec 0011 defers this behind a **whole-record layout proof** (like bit-fields).

### Dynamic arrays `[dynamic]T`

- Three-word header (ptr, len, cap) — **never** a C ABI shape.
- Implies allocation ownership. Unsuitable as a foreign declaration type.
- Only makes sense as a **hand-written** helper that fills a dynamic array from
  C callbacks / repeated queries — out of generator scope (library-specific).

### Recommendation

| Conversion | Status | Notes |
|------------|--------|-------|
| Param multipointer `[^]T` | Done | Curation / decay |
| Param wrapper `[]T` | Done | Explicit policy |
| Field fixed `[N]T` stay | Keep | Do not slice |
| Field ptr+count → `[]T` | Deferred | Needs layout proof + explicit policy |
| Anything → `[dynamic]T` | Out of scope | Ownership / allocator |

**Priority for field folding:** medium (high vendor payoff on cgltf-like APIs)
only after a proof engine exists; not a free “make it feel Odin” switch.

---

## 4. Other conversions that feel “more Odin”

### 4a. Out-parameter → multi-result (done)

High vendor alignment (cgltf). Low runtime cost. Keep expanding via config.

### 4b. Borrowed output slices (`T *` + count out → `[]T` result)

- Needs lifetime: “valid until free X / next call / forever.”
- Without that, returning `[]T` over library memory is a footgun.
- Spec 0011: deferred until policy has lifetime vocabulary.

### 4c. Enum → `bit_set` (M9-ish, not a wrapper)

Already partially supported (`enums.bit_sets`). Improves Odin feel for flag
enums without FFI arity change when values are powers of two.

### 4d. Bool / `_Bool`

Idiomatic `bool` when width proven — already leaf-substitution territory.

### 4e. Opaque handles

Idiomatic `distinct rawptr` collapse (spec 0007) — already a major “hand-written
Odin” win without wrappers.

### 4f. `#by_ptr` for call-borrowed structs (done as curation)

Not a wrapper; matches box3d/cgltf. Expand via config, not inference from `const`.

### 4g. Optional / nullable results

C `T *` that may be null as `Maybe(^T)` or optional — **changes type algebra**
and nil checks; not ABI-identical spelling. Vendor rarely does this at FFI
boundary. Defer; explicit policy only if ever.

### 4h. Error unions

Mapping `int`/`enum` status codes to `union { T, Error }` invents control-flow
semantics. High ergonomic gain, high false-friend risk. Hand-written layer or
very explicit policy — not a default.

### 4i. Callbacks / procedure types

Keep C calling convention and pointer shape; idiomatic renames only. Converting
to Odin-default `proc` without `"c"` breaks ABI.

### 4j. Math / vector sugar

Vendor raylib/box3d use array/matrix overrides (`[2]f32`, `matrix`) via
**types.overrides** — spelling when layout matches. Already supported; not a
new conversion class.

---

## Cost summary matrix

| Conversion | Layer | Runtime cost | Spec/design needed | Vendor-like? | Suggested priority |
|------------|-------|--------------|--------------------|--------------|--------------------|
| Leaf ints/floats | Spelling | None | Done | Yes | — |
| Opaque handles | Spelling | None | Done | Yes | — |
| `cstring` for `char *` | Foreign surface | None | Done | **Yes** | Keep |
| `[^]T` / `#by_ptr` | Foreign surface | None | Done | Yes | Expand curation |
| Out-param wrappers | Wrapper | None | Done | Yes | Expand config |
| Input `[]T` wrappers | Wrapper | Cast only | Done | Yes | Expand config |
| Field ptr+count → `[]T` | Record rewrite | None if proven | Layout proof | Yes (cgltf) | **Next design** |
| Borrowed output `[]T` | Wrapper | None | Lifetime vocab | Sometimes | After lifetime |
| `string` in/out | Wrapper | Alloc / scan | Allocator + lifetime | **No** (vendor uses cstring) | Low |
| `rune` for `char` | Spelling/wrapper | Wrong size | — | **No** | Avoid |
| `[dynamic]T` | Helper | Alloc | Ownership | No as FFI | Out of scope |
| Status → error union | Wrapper | None | Domain rules | Rare | Hand layer |
| Nullable → Maybe | Wrapper | None | Null contract | Rare | Low |

---

## Guiding recommendation for “as close as practical to hand-written Odin”

1. **Match vendor first:** `cstring`, multipointers, `#by_ptr`, out-param multi-results, opaque handles, leaf widths — continue curating these.
2. **Do not chase `string`/`rune` as default FFI types** — they fight C’s byte/NUL model and diverge from official vendor packages.
3. **Next high-value deferred feature:** struct field pointer+count folding under a **layout proof** (cgltf-shaped APIs).
4. **Any conversion that allocates or invents lifetime** needs an explicit policy contract and generation-time refusal when the contract is missing — never silent runtime helpers as the product of “idiomatic mode.”
5. **Hand-written footers / same-package Odin** remain the right place for string sugar, error unions, and library-specific helpers.

## Out of scope for implementation now

This note does not change generator behavior. Implementation of any deferred row
requires a dedicated spec (or an extension to 0011) before code.
