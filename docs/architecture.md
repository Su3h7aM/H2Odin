# Architecture

H2Odin is a pipeline. Data enters, passes through a few stages, and leaves as Odin source. Each stage takes the previous stage's output and hands its own output to the next.

```
Extraction  ->  Analysis  ->  Transformation  ->  Emission
 (libclang)     (facts)        (decisions)          (text)
```

This document describes what each stage is *for* and the boundaries we try to keep between them. These are guidelines — the seams may move as the code teaches us where they naturally belong.

## The stages

**Extraction** is the only stage that talks to libclang. It walks the parsed header and builds the IR — H2Odin's own description of the C API. Its job is to capture *what the header contains*, faithfully and completely, and to decide nothing. No renaming, no filtering, no policy. If extraction starts making judgment calls, later stages can no longer be tested without a C compiler in the loop, so we keep it opinion-free.

**Analysis** takes the IR and adds *facts* to it — things that are provably true about the C API regardless of any configuration. For example, noticing that a parameter looks length-like and sits next to a pointer. Analysis may surface candidates and hints; it does not commit to them. It reads and annotates; it decides nothing.

**Transformation** is where decisions are made. It reads the analyzed IR together with the configuration policy and records the choices: what to rename, what to drop, and which type spellings to use. It is the only stage that consults policy.

**Emission** turns the final IR into Odin text. By the time it runs, every decision has already been made, so emission should be close to boring — it serializes what earlier stages decided. If emission finds itself making a real decision, that decision probably belonged in an earlier stage.

A useful test for which stage a piece of logic belongs to: *would it still be true if the user changed their configuration?* If yes, it is a fact (Analysis). If it depends on configuration, it is a decision (Transformation).

## Foreign systems stay at the edges

Two outside systems touch this program: **libclang** and **Lua**. We keep each confined to one place and do not let it leak into the rest of the pipeline.

- libclang belongs to **Extraction** only. Once extraction is done, nothing downstream should be holding a libclang handle. The rest of the pipeline works with H2Odin's own data, so libclang could be shut down the moment extraction returns and everything would still run.
- Lua belongs to the **policy layer**, consulted only by **Transformation**.

A helpful way to think about Lua: Transformation does not "call Lua." Transformation consults *policy*. Lua happens to be how policy is implemented today, but the pure stages never see the Lua machinery — the VM, its stack, its references, its strings. If we ever wanted a different policy backend, Transformation should not have to notice.

The same care applies to strings. Any string owned by libclang or by Lua is **copied into H2Odin's own memory at the boundary**, so nothing downstream depends on a foreign system's lifetime. This one habit — copy foreign strings at the edge — keeps both boundaries clean.

## The IR is data, not objects

The IR holds declarations in dense pools, with a separate ordering list that remembers the source order. References between pieces of the IR are **handles** (indices), not raw pointers. This matters because a pointer into a growing array can be invalidated when the array grows, while a handle stays valid. It also makes dropping a declaration simple: leave it in its pool and remove it from the ordering list.

Odin does not require declarations to appear in dependency order at file scope, so the ordering list exists only to make the output read like the original header. We do not need to sort declarations to make the output compile.

## A note on "pure" stages

We describe Analysis, Transformation, and Emission as pure in the sense that each depends only on its declared input — Extraction on libclang, Transformation on policy, Emission on the final IR. That is an architectural kind of purity, and it is what keeps the stages testable and independent.

It is worth being honest that Transformation is not *mathematically* pure: a Lua policy can still do pure non-deterministic work (e.g. `math.random`). Host side effects, however, are blocked structurally — the config sandbox withholds `io`, `os`, `package`, `debug`, and the base loaders. Analysis, which consults no policy, is deterministic without any such caveat.
