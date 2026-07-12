# Spec 0010 — Foreign types: POSIX / libc mapping, one spelling, the defining package

**Status:** accepted and implemented (`src/transform_foreign.odin`);
Windows win32.* compounds for corpus-required socket types are implemented;
further allowlist growth remains open
**Date:** 2026-07-11

## Context

Real headers reference names their own project does not define: curl's
`struct curl_sockaddr` embeds `struct sockaddr` by value; countless APIs take
`off_t`, `pid_t`, `time_t`. The foreign-provenance work stops H2Odin from
copying system-header layouts into generated packages, which forces the
question this spec answers: **how are these names spelled in the output, and
do ABI and idiomatic modes get different answers?**

### Two different kinds of "POSIX type"

These must not share one rule.

**A. Compound / layout types** — `sockaddr`, `sockaddr_in`, `addrinfo`,
`iovec`, `msghdr`, `pollfd`, `timeval`, `timespec`. Field offsets and size
must match the platform, and Odin already owns those layouts. By-value
embedding (curl's `struct curl_sockaddr`) is exactly why an incomplete
`struct {}` stub is insufficient: wrong size.

**B. Named integer / scalar typedefs** — `off_t`, `pid_t`, `dev_t`, `gid_t`,
`clock_t`, `mode_t`, `socklen_t`, …. In Odin these are almost always
`distinct` wrappers whose width varies by OS, and some are not integers at
all.

### Evidence

Verified against Odin `dev-2026-07a`:

| Source | What it establishes |
|---|---|
| `core:sys/posix/fcntl.odin` | POSIX scalars are `distinct` **and** OS-width-specific: `pid_t` is `distinct c.int32_t` on Darwin/FreeBSD/NetBSD, `distinct c.int` on OpenBSD/Linux. The platform table already lives in Odin's core library. |
| `core:sys/posix/sys_stat.odin` | `mode_t :: bit_set[Mode_Bits; _mode_t]` — not an integer. An integer respelling breaks `posix` helper interop (`S_ISREG`, …). |
| `core:sys/posix/sys_socket.odin` | Compound layouts differ per OS (`posix.sockaddr` has `sa_len` on the BSDs, not on Linux), and the whole socket surface sits inside a Unix-target `when` block — **undefined on Windows**. |
| `core:sys/posix/time.odin`, `core:c/libc/time.odin` | `core:sys/posix` **does not export `time_t`**. Time types are defined in `core:c/libc` (`time_t :: distinct i64`, deliberately 64-bit for Y2038); `posix` re-exports `clock_t`, `tm`, `timespec` as aliases of libc's. `core:c/libc` works on Windows; the posix socket types do not. |
| `core:c/libc/types.odin` | `size_t` / `ssize_t` are ISO C, not POSIX-only — already covered by H2Odin's `std_mappings`. |
| `vendor:curl` (`curl_posix.odin` / `curl_windows.odin`) | Official bindings import, never re-emit: the embedded field is `platform_sockaddr`, aliased per-OS to `posix.sockaddr` / `win32.sockaddr`. |
| `core:sys/posix` export inventory | Not every plausible name exists: `sockaddr_dl` and `ip_mreq` are **not** exported. A map entry for them emits spellings that fail `odin check`. Membership cannot be assumed, only verified. |

### Alternatives considered

| Option | ABI spelling | Idiomatic spelling | Verdict |
|---|---|---|---|
| **S1 — single spelling** | `posix.pid_t` / `libc.time_t` | same | **Chosen.** Preserves `distinct` identity and interop with `core:sys/posix` and hand bindings. |
| S2 — dual, like `size_t` | `c.int` / measured width | `i32` / `i64` | Loses `distinct`; wrong for `mode_t`; fights the OS-width tables posix already encodes. |
| S3 — dual, keep distinct | `posix.pid_t` | `distinct i32` (redeclared) | Duplicates Odin's platform table; drifts on Odin updates. |

## Decision

0. **Foreign means "declared in a system header" — not "absent from
   `config.inputs`".** This is the ownership rule the rest of the spec rests
   on, and libclang answers it directly
   (`clang_Location_isInSystemHeader`, captured in Extraction as
   `is_foreign`). The two questions are genuinely different:

   | Question | Answered by | Used for |
   |---|---|---|
   | Which configured input places this declaration in the output? | `home` | per-header output layout |
   | Is this someone else's declaration? | `is_foreign` | may we claim its layout? |

   A library's own headers reached only transitively still belong to it: Box3D
   lists just the umbrella `box3d.h` and pulls in `types.h`, `id.h`, and the
   rest through it. Treating those as foreign would stub out `b3BodyType` and
   friends — real declarations the binding must emit. Conversely `<sys/socket.h>`
   is foreign no matter how it was reached.

   Consequences, applied to every foreign record, enum, and typedef:
   - Extraction captures it **pool-only** (name, and for typedefs the
     underlying type) and never fills a system layout into the IR.
   - Transformation resolves *every* reference to one, so no name we did not
     bind can reach Emission: the built-in map (below), a config spelling, an
     incomplete stub for pointer-only use, or — for an unmapped typedef — a
     peel to the underlying type (`__off_t` → `c.long`).
   - By-value use of an unmapped foreign record is a diagnostic, not a silent
     zero-sized stub: `struct {}` would have the wrong size.

1. **Named POSIX/libc types get a single spelling in both ABI and idiomatic
   modes.** `off_t` → `posix.off_t`, `sockaddr` → `posix.sockaddr`,
   `time_t` → `libc.time_t` — identically under `type_mode = "abi"` and
   `"idiomatic"`. The dual ABI/idiomatic ladder exists for ISO C scalars
   where both spellings are the same machine type and idiomatic is a
   readability upgrade; here the qualified name **is** both the ABI-faithful
   and the idiomatic spelling. Peeling `posix.pid_t` to `i32` would drop
   `distinct` identity (breaking assignment compatibility with every package
   that uses `core:sys/posix` correctly), re-derive a platform width table
   Odin already maintains, and has no compound-type analogue at all.

2. **Package home = the defining package.** `time_t`, `clock_t`, `timespec`,
   `tm` → `libc.*` (`core:c/libc`); names POSIX owns (`off_t`, `pid_t`,
   `dev_t`, `mode_t`, `sockaddr`, …) → `posix.*` (`core:sys/posix`). The
   posix re-exports are ABI-identical aliases, so the rule is pure
   consistency — and `libc.*` has the practical edge of being defined on
   Windows. `time_t` was never a choice: only `libc` exports it.

3. **The ISO C dual ladder is untouched.** `size_t`, `ssize_t`, `ptrdiff_t`,
   and the `stdint.h` names stay in `std_mappings` with their existing
   ABI (`c.size_t`) / idiomatic (`uint`) columns. Nothing ISO C defines
   moves to `posix.*`.

4. **Membership is a curated, verified allowlist.** Every entry must name a
   symbol that exists in the supported Odin version (the `sockaddr_dl` /
   `ip_mreq` finding is the cautionary proof). Grow the list from validation
   corpus needs (curl, miniaudio, …), not by inventorying every `*_t` the
   posix package exports.

5. **Precedence, outermost wins:** `types.overrides` > `types.map` >
   built-in POSIX/libc map > foreign-type fallback (incomplete stub for
   pointer-only use; `unresolved_type` diagnostic for by-value use of an
   unmapped foreign type). A user who wants `pid_t = "i32"` writes it in
   `types.map`; mode defaults stay interop-safe. The implementation needs an
   explicit fixture proving config wins over the built-in map — the current
   pass ordering (foreign stubs before `apply_type_rewrites`) makes this
   easy to get wrong silently.

6. **Scalar map entries are width-guarded.** Extraction already measures
   every type's width on the generation target; a built-in scalar mapping
   applies only when that measured width equals the Odin-side type's width.
   On mismatch: skip the mapping and diagnose — never silently substitute
   (correctness over convenience). The concrete case: `libc.time_t` is
   unconditionally 64-bit, but a 32-bit C target without `_TIME_BITS=64`
   has a 32-bit `time_t`.

   The Odin-side width comes from `size_of` on the real Odin type, never from
   a restated table: `core:sys/posix` already encodes the per-OS widths, and
   duplicating them is the mistake option S3 was rejected for. Because
   `core:sys/posix` does not exist on Windows and Odin imports cannot be
   conditional, the width source is split by build tag
   (`transform_foreign_unix.odin` / `transform_foreign_windows.odin`), which
   is also what makes decision 8 enforceable rather than aspirational.

   **Compounds are not width-guarded.** Their layouts are deliberately never
   captured (decision 0), so there is nothing to compare against; the verified
   allowlist plus Odin's own per-OS layout is what keeps them honest. Host ==
   generation target is the standing assumption until cross-target generation
   exists.

7. **Imports follow spellings.** `posix.*` anywhere in the output pulls
   `import "core:sys/posix"`; `libc.*` pulls `import "core:c/libc"`;
   `win32.*` pulls `import win32 "core:sys/windows"`. Config-supplied
   spellings with these prefixes flip the same flags.

8. **Windows uses the defining package, same as Unix.** Host == generation
   target: Unix maps compounds/scalars to `posix.*` / `libc.*`; Windows maps
   compounds that `core:sys/windows` exports to `win32.*` (sockaddr, fd_set,
   timeval, …) and keeps portable `libc.*` rows. Pure-POSIX names without a
   win32 counterpart stay unmapped and need `types.map` or the incomplete-stub
   path. Config still wins over the built-in map.

## The built-in map (candidate membership)

Single spelling in both modes. Every right-hand side below was verified to
exist as an exported name in Odin `dev-2026-07a`.

**Scalars**

```text
dev_t, blkcnt_t, blksize_t, fsblkcnt_t, off_t, gid_t, pid_t, clockid_t,
socklen_t                                                   → posix.*
                                                            (Windows: socklen_t → win32.socklen_t)
time_t, clock_t                                             → libc.*
```

**Compounds**

```text
sockaddr, sockaddr_storage, sockaddr_in, sockaddr_in6, sockaddr_un,
in_addr, in6_addr, addrinfo, fd_set, timeval, iovec, msghdr, cmsghdr,
pollfd, linger, ipv6_mreq                                   → posix.*
  Windows rewrites when exported by core:sys/windows:
    sockaddr, sockaddr_in, sockaddr_in6, in_addr, in6_addr,
    fd_set, timeval                                         → win32.*
timespec, tm                                                → libc.*
```

**Verified absent — must not be mapped:** `sockaddr_dl`, `ip_mreq` (not
exported by `core:sys/posix`; mapping them emits code that fails
`odin check`).

**Candidate extensions**, exported and common but held back until a
validation library needs them: `uid_t`, `ino_t`, `nlink_t`, `mode_t`,
`socklen_t`, `fsfilcnt_t`, `id_t`, `key_t`, `rlim_t`, `nfds_t`,
`suseconds_t`.

**Explicitly not in this map:** `size_t`, `ssize_t`, `ptrdiff_t`, and the
`stdint.h` names — they stay on the ISO C `std_mappings` ladder.

## Edge cases

1. **`mode_t` is a `bit_set`**, not an integer. If added, it must be
   `posix.mode_t` only.
2. **The peel is the fallback, never the default.** An unmapped foreign
   typedef peels to its underlying type (`__off_t` → `c.long`) — the ABI is
   right, the name is simply not ours to bind. What must not happen is a
   *mapped* name peeling first: that is why the peel moved out of Extraction
   (which ran before any map could see the name) into Transformation.
3. **By-value foreign compounds** (curl's `struct sockaddr` inside
   `curl_sockaddr`): an incomplete `struct {}` stub has the wrong size. A
   map entry or a diagnostic is required — never a silent stub.
4. **Config override always wins** over the built-in map, matching how
   `types.map` already beats table preferences.

## Consequences

- Generated bindings interoperate directly with `core:sys/posix` /
  `core:c/libc` call sites — no casts at the boundary, same as hand-written
  vendor bindings.
- `type_mode` stops being a lever for these names; users who want raw
  integers opt in per-name via `types.map`, accepting the interop cost
  explicitly.
- The generator gains its first built-in name→spelling table that is
  Odin-version-coupled. The verification step (decision 6) plus the
  allowlist policy (decision 4) is what keeps that coupling honest.
- Extraction stops peeling foreign typedefs at capture. It used to discard
  the C name on the spot (`off_t` → `c.long`), which both violated
  "Extraction decides nothing" and made the map impossible — the name it
  needs was already gone. The peel still happens for unmapped names, but as
  a Transformation decision.
- `import "core:c/libc"` joins `core:c` and `core:sys/posix` as an import the
  prelude emits only when a body actually uses it.

## Acceptance criteria (met by the implementation)

Fixtures live in `tests/fixtures/configs/` and use **real system headers** —
a fake header inside the fixture directory is a *user* header and, correctly,
not foreign at all (decision 0).

- `posix_sockaddr`: embeds `struct sockaddr` (from `<sys/socket.h>`) by value
  → `addr: posix.sockaddr` + `import "core:sys/posix"`; no local sockaddr
  layout, no `sa_family` field leak.
- `posix_scalars_abi` / `posix_scalars_idiomatic`: `off_t`, `pid_t`, `time_t`
  → `posix.off_t`, `posix.pid_t`, `libc.time_t` in **both** modes, while ISO C
  `size_t` still follows the mode (`c.size_t` vs `uint`).
- `posix_scalars_override`: `types.map = { pid_t = "i32" }` beats the built-in
  map; unmapped names still take the built-in spelling.
- `foreign_ref`: `FILE` (unmapped system type, pointer-only) → incomplete
  stub, no system fields copied.
- Dogfood: the curl example emits `sockaddr :: struct { …; addr: posix.sockaddr }`
  — the same shape as the hand-written `vendor:curl` — and `time_t` →
  `libc.time_t`. Box3D stays green, proving decision 0's umbrella-header case.

## Open items

1. **Windows emission** (decision 8): revisit when a Windows validation
   target exists; until then posix rows are Unix-only by construction.
2. **Allowlist growth cadence**: add names as validation libraries demand
   them; each addition re-verified against the pinned Odin version.
3. **Cross-target generation**: decision 6 assumes host == target; a real
   cross-compilation story must revisit where Odin-side widths come from.

## See also

- Vendor evidence: [`docs/vendor-example-audit-2026-07-11.md`](../vendor-example-audit-2026-07-11.md)
- Type spelling tables: `src/types.odin`
- Spec 0007 (incomplete tag records) — the mode-dependent counterpart for
  *input-owned* incomplete types; this spec covers *foreign-owned* names.
