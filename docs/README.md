# H2Odin Documentation

These documents describe how H2Odin is meant to fit together. At this stage of the project they are **guidelines, not hard rules** — they capture intent and direction so that contributors share a mental model, not a rigid specification. Details will shift as the code is written, and that is expected. Where a document and the code disagree, treat it as a question to resolve, not a law that was broken.

Start here:

- [Overview](overview.md) — what H2Odin is and the principles behind it.
- [Architecture](architecture.md) — the pipeline, the stages, and how foreign systems are kept at the edges.
- [Type Modes](type-modes.md) — ABI vs Idiomatic, and how the two relate.
- [Configuration](configuration.md) — the Lua policy layer as it exists today, and how it steers the generator.
- [Config Spec](config-spec.md) — the north-star configuration model everything grows toward.
- [Memory](memory.md) — how the generator owns its memory.
