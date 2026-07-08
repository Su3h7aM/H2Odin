# AGENTS.md

Guidance for AI agents working in H2Odin — a C-header-to-Odin bindings generator written in Odin. Design intent lives in [`docs/`](docs/); this file is about how to act.

The pipeline has four stages: **Extraction → Analysis → Transformation → Emission**.

## Invariants — do not break these

- **libclang stays in Extraction.** No later stage holds a libclang handle; copy what you need into the IR.
- **Lua stays behind the policy layer.** Only Transformation consults policy. Other stages must not know Lua exists.
- **Copy foreign strings (libclang/Lua) into the generation arena at the boundary.** Never store foreign-owned strings in the IR.
- **IR references are handles, not pointers.** Pool growth invalidates pointers.
- **The generation arena owns long-lived memory.** `context.allocator` is a convenience, not the owner. Scratch uses `context.temp_allocator` and never enters the IR.
- **Configuration selects behavior; it never authors output.** The generator owns every byte of Odin emitted.
- **Correctness over convenience.** Never swap in a type that could change behavior or break the ABI. When ambiguous, pick a conservative default, flag it, and let config override — never silently guess.

If a task seems to require breaking one of these, stop and surface the conflict.

## Where does my change go?

Ask: *would it still be true if the user changed their config?*
Yes → a fact → **Analysis** (or captured raw in Extraction). No → a decision → **Transformation**. Turning decided IR into text → **Emission**. Extraction and Emission decide nothing.

## Version control

This project uses **Jujutsu (`jj`)** as its VCS — always use `jj`, not raw `git`, for any repository operation (status, diff, describe, rebase, bookmark, push, conflict resolution, history). Git is the backend only. Prefer the non-interactive `jj desc` + `jj new` workflow over `jj commit`: start work from an empty working-copy commit, set a `WIP:` description before editing, replace it with the final description after, then `jj new` to leave a fresh empty working copy.

## Style

Plain, data-oriented Odin — data is data, code that transforms it is separate. Prefer readable over clever, match surrounding conventions, keep procedures small. Pass state explicitly; Odin procedures do not capture. Keep the pure stages testable without a live libclang or Lua.

## Scope

Keep the early surface small. Before adding an option or abstraction: can richer callback context solve it? can it wait? If it must exist, keep it minimal. When in doubt, do the smaller thing and leave a note.

These are guidelines, not law. If docs and code disagree, or a task fights an invariant, raise it rather than bend it silently.

## Agent skills

### Issue tracker

Issues and PRDs live in the repo's GitHub Issues, managed via the `gh` CLI; external PRs are **not** a triage surface. See `docs/agents/issue-tracker.md`.

### Triage labels

The five canonical triage roles use their default label strings (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: one `CONTEXT.md` + `docs/adr/` at the repo root. See `docs/agents/domain.md`.
