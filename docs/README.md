# H2Odin Documentation

These documents describe how H2Odin is meant to fit together. At this stage of the project they are **guidelines, not hard rules** — they capture intent and direction so that contributors share a mental model, not a rigid specification. Details will shift as the code is written, and that is expected. Where a document and the code disagree, treat it as a question to resolve, not a law that was broken.

Start here:

- [Overview](overview.md) — what H2Odin is and the principles behind it.
- [Architecture](architecture.md) — the pipeline, the stages, and how foreign systems are kept at the edges.
- [Type Modes](type-modes.md) — ABI vs Idiomatic, and how the two relate.
- [Configuration](configuration.md) — the Lua policy layer as it exists today, and how it steers the generator.
- [Config Spec](config-spec.md) — the north-star configuration model everything grows toward.
- [Memory](memory.md) — how the generator owns its memory.
- [Source Layout](source-layout.md) — what each `src/` file is for, and the planned splits.
- [Vendor example audit (2026-07-11)](vendor-example-audit-2026-07-11.md) — evidence from raylib, Box3D, cgltf, curl, and miniaudio; current failures and the closure plan.
- [`specs/`](specs/) — numbered design specs for major decisions (bit-field emission, self-hosted libclang, multi-file emission, bit_set backing width, opaque handles, imports_file removal, opaque tag records, symbol-collision validation, deprecated declarations, POSIX/libc type mapping).
