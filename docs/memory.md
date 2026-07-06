# Memory

H2Odin manages its own memory, in the plain, explicit way Odin encourages. This document describes the intended model. It is a guideline for how memory *should* flow, not a rigid contract.

## One arena owns a generation run

A single **named generation arena** owns the entire IR and all long-lived strings for one run of the generator. Everything that needs to live for the whole run goes into it, and it is freed once — when the run ends. This fits the IR perfectly: every part of the IR shares one lifetime, so grouping it under one arena means there is nothing to free piece by piece.

The important idea is that the IR *belongs to that arena* by name. Ownership is explicit. We choose an arena because we know the lifetime of the data, not because it happens to be convenient.

## Context is a convenience, not the design

Odin's `context.allocator` can be set to the generation arena within the generation scope, so that ordinary allocations and the IR construction helpers do not each need an allocator passed to them. That is a nice ergonomic shortcut and we use it as one.

But it is only a shortcut. The design truth is "the IR belongs to the generation arena," not "the IR uses whatever allocator happens to be in context." We lean on context to avoid threading an allocator through everything, while still being able to say clearly which named resource owns the memory. Both Odin's own guidance and common practice point this way: prefer knowing your lifetimes and owning your resources explicitly, and use context to save boilerplate rather than to define the architecture.

## Scratch memory

Short-lived work that cannot escape — temporary buffers, intermediate values built while walking the header — should use `context.temp_allocator`. This is throwaway memory that gets reset at a natural boundary. The one firm expectation: scratch memory must never become part of the IR. Anything that needs to survive belongs in the generation arena instead.

## Copy foreign strings at the boundary

Strings owned by libclang or by Lua are only valid for as long as those systems say. So whenever such a string needs to live in the IR, it is **copied into the generation arena at the boundary** — immediately, before the foreign system reclaims it. After that copy, the string is ours and outlives the foreign runtime entirely.

This single habit is what lets us say libclang can be shut down the moment extraction ends, and that Lua's machinery never leaks downstream. Copy at the edge, and the rest of the pipeline never has to think about foreign lifetimes.
