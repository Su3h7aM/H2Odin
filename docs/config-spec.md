# H2Odin Configuration Specification

This document defines the target configuration model for H2Odin — what the config should be when the project is mature. It is a **north-star specification, not current implementation status.** Features described here may not exist yet; the point is to fix the shape everything grows toward, so each piece built lands as a step toward this model rather than drifting from it.

For what the generator accepts **today**, see [`configuration.md`](configuration.md), which also carries the migration table from the current keys to the ones below.

Every section states not just *what* the config looks like but *why* it is shaped that way, because the reasoning is what keeps future additions consistent.

---

## The core idea: Lua as a program, not JSON

The single decision this whole spec rests on: **the configuration is a real Lua program that imports an API and builds a config object**, not a data file that happens to use Lua syntax.

```lua
local h2o = require "h2odin"

local config = h2o.config()

-- user configures here, using normal Lua

return config
```

**Why.** A static data format (JSON, sjson) forces every possible transformation to become its own pre-baked option, because data can't express logic. That's why comparable tools accumulate dozens of flat knobs — `remove_type_prefix`, `remove_macro_prefix`, `force_ada_case_types`, `enumify_macros`, and so on — each a special case of a more general idea. Lua lets the user write the *rule* instead of the generator pre-baking every rule. The difference:

```text
Data config:   "This exact symbol becomes this exact symbol."
Policy config:  "Every symbol matching this rule gets this transformation."
```

The second is dramatically more powerful and far smaller. Importing a namespaced `h2o` API (rather than exposing global commands) also makes the config discoverable, autocompletable, validatable at load time, and composable across multiple files with `require`. This is the model used by mature Lua-configured tools, and it is what makes the config feel like a program rather than a form.

### What `require` costs, and what the sandbox still guarantees

`require` is not free. H2Odin's Lua state is sandboxed, and an earlier posture withheld `package` and every loader outright, which made "the config performs no host I/O" a *structural* fact rather than a convention. Supporting `require "h2odin"` and multi-file configs gives that up in part, so the boundary is redrawn rather than removed:

- `require` resolves exactly two things: the preloaded `h2odin` prelude, and `.lua` files beneath the directory of the config being loaded. Anything else is an error.
- `io`, `os`, and `debug` remain withheld. `load`, `loadfile`, and `dofile` remain `nil`.

So a config can read Lua that sits alongside it, and nothing else. The determinism claim narrows accordingly, and honestly: *the same headers plus the same config tree produce byte-identical output.* Reaching outside that tree is not a thing a config can do.

---

## The fundamental rule: Lua decides, Odin mutates

> **Lua decides what should happen. Odin performs the mutation.**

Lua never touches H2Odin's internal IR directly. Callbacks receive small, stable, read-only *views* of a symbol, and return *decisions* — a boolean, a name, or an action table. The Odin generator applies those decisions in the correct pass.

```lua
config.procs.param = function(param)
    if param.proc_name == "SetConfigFlags" and param.name == "flags" then
        return { type = "Config_Flags" }
    end
    return nil
end
```

The callback does not edit a procedure node. It returns an action; Odin applies it.

**Why.** Three payoffs. It keeps the generator **deterministic** — Lua can't reach in and create inconsistent state. It keeps the generator **testable** — passes can be tested with plain-Odin stub policies, no Lua VM required. And it lets the internal IR be **refactored freely** — as long as the small public views stay stable, no user config breaks. Handing Lua a raw IR pointer would forfeit all three.

---

## Values, not generated code

Config may supply *values* that appear in generated Odin — type spellings, field tags, default-argument expressions, foreign library names, symbol names:

```lua
config.types.map = { sqlite3_int64 = "i64" }

config.structs.fields = {
    ["BoneInfo.name"] = { tag = 'fmt:"s,0"' },
}
```

Config may **not** author generated code — no procedure bodies, no declaration text, no wrappers, no raw Odin source blocks.

```lua
-- Allowed: selecting a value
return { type = "i64" }

-- NOT allowed: authoring code
return { emit = [[ my_proc :: proc() { ... } ]] }
```

**Why.** The moment a config can return arbitrary Odin source, three guarantees collapse: **determinism** (output now depends on unbounded user code), **reviewability** (a config PR becomes unreadable), and the **closed, auditable set** of things the generator can emit. Selecting a value from a bounded set is safe; authoring code is not.

This rule is about **who writes the Odin**, and it is permanent. It is *not* a claim that the generator will never emit a procedure body. Those are two different questions, and conflating them has caused confusion:

```text
Config authors Odin source.          -> never. This is the rule.
The generator emits wrapper procs.   -> not today. See ROADMAP Milestone 6.
```

If wrappers ever land, they are authored by the generator from a closed conversion set, and the config's role stays what it is here: *choosing* which conversion fires, never supplying its text. A user who wants something outside that closed set writes a hand-written Odin layer on top of the raw bindings.

---

## Two kinds of callback

Callbacks fall into exactly two categories, and the category is predictable from the callback's **name** — so a user learns the rule once and applies it everywhere.

**Predicate callbacks** — `where`, `include`, `match`, `filter` — answer a yes/no question. They return `true` or `false`. Returning `nil` is treated as `false`.

```lua
config.symbols.remove.where = function(sym)
    return sym.kind == "const" and h2o.str.has_prefix(sym.name, "SQLITE_PRIVATE_")
end
```

**Action callbacks** — `override`, `field`, `param`, `result`, `member`, and similar — request a change. They return `nil` for "no change, use the default," or a value describing the change: a **string** where the callback's whole job is one name or spelling, or an **action table** where several attributes may be set.

```lua
config.structs.field = function(field)
    if field.struct_name == "BoneInfo" and field.name == "name" then
        return { tag = 'fmt:"s,0"' }
    end
    return nil
end
```

**Why.** An earlier draft forced every callback to return an action table, which made simple predicates ugly (`return { remove = true }` instead of `return true`). Splitting by category keeps predicates concise and actions expressive, and tying the category to the callback's name means the contract is self-documenting. Note the two categories even differ in what `nil` means: for a predicate `nil` collapses to `false` (don't act); for an action `nil` means "no opinion, use the default." That difference is intentional and removes ambiguity.

---

## Declarative first, callback as escape hatch

Every subsystem offers up to three tiers, and they compose in a fixed precedence:

1. **Exact map** — `{ "OldName" = "NewName" }`. The simple 90% case, pure data.
2. **Structured rule** — declarative fields like `prefix`, `exclude_prefixes`, `patterns`. Data the generator evaluates in Odin.
3. **Callback** — a predicate or action for the cases data can't express.

The declarative tiers are evaluated **first, in Odin**; the callback only ever *refines* an already-selected set — it is never the primary selector that scans everything.

**Why.** This is what keeps the powerful path from swallowing the simple one. The deterministic, testable bulk stays in Odin (exact maps and structured filters); Lua callbacks handle only the genuine exceptions. It also means a well-behaved library needs no callbacks at all, while a messy one can drop into Lua exactly where it must — without the generator running user Lua across thousands of symbols it could have filtered declaratively.

A note on **constructors vs. bare tables**: rich, multi-field rules that benefit from validation use constructors (`h2o.macro_group.enum{...}`); simple key→value maps use bare tables (`types.map = {...}`). The dividing line is richness — a macro group is a rule with many fields and a callback; a type mapping is just a pair.

### Plural is data; singular is a callback

The tiers are distinguished by **grammatical number**, everywhere, without exception:

```lua
config.structs.fields = { ["BoneInfo.name"] = { tag = "…" } }   -- plural: a table
config.structs.field  = function(field) … end                    -- singular: a callback
```

The same holds for `types.overrides`/`types.override`, `procs.params`/`procs.param`, `procs.results`/`procs.result`, and `naming.overrides`/`naming.override`. Because a mistyped number is otherwise a silent no-op, config validation must reject a table where a function belongs and vice versa, naming both the key and the expected kind.

One collision to be aware of: `naming.overrides` maps a C name to an Odin *name*, while `types.overrides` maps a C name to an Odin *declaration*. Same word, different objects — the section is what disambiguates, which is exactly why sections exist.

---

## The `h2o` API and its implementation split

The public API is namespaced under `h2o`, implemented in two layers:

**A Lua prelude** provides the builders and constructors — `h2o.config()`, `h2o.naming.odin{...}`, `h2o.macro_group.enum{...}`, `h2o.enum.bit_set{...}`. These shape and validate tables, and lower friendly syntax into the canonical internal rule form. A constructor is *sugar that returns the full rule table a power user could write by hand* — so there is one internal model with a friendly front door, not two code paths.

**Odin-registered functions** own the deterministic algorithms — `h2o.naming.snake_case`, `h2o.naming.ada_case`, `h2o.str.has_prefix`, `h2o.str.strip_prefix`. These live in Odin, are tested in Odin, and are reused by both the generator's automatic behavior and the user's Lua.

**Why.** The hard, must-be-deterministic algorithms (tokenizing an identifier, converting case) must not be reimplemented in Lua where they'd be untested and could drift. The same `snake_case` runs whether the user calls it explicitly or the generator applies it automatically — one canonical implementation, two front doors. The Lua prelude, by contrast, is just table-shaping, which is naturally and safely Lua.

"Two front doors" has a structural requirement: those algorithms live in a **pure Odin module** that knows nothing about Lua (identifier tokenizing, case conversion, prefix handling), and `policy.odin` merely *registers* them into the VM. Implementing them inside the policy layer would make them untestable without a live VM and would put generator logic behind the Lua boundary — the opposite of the invariant that keeps Lua confined.

---

## Configuration sections

The config is organized around the real decision points in a C-to-Odin pipeline. These are not arbitrary options — each is a place where a C header needs human judgment before it becomes good Odin.

```lua
config.package   = "..."
config.inputs    = { ... }
config.type_mode = "abi" | "idiomatic"
config.output_folder = "..."

config.preprocess   -- how headers are prepared before analysis
config.naming       -- Odin names
config.types        -- type translation and replacement
config.symbols      -- what is included or removed
config.macros       -- how C macros become Odin constructs
config.enums        -- how enums are cleaned or transformed
config.structs      -- struct/union field and layout adjustments
config.procs        -- procedure signature adjustments
config.foreign      -- external linking behavior
config.output       -- emitted file layout
config.diagnostics  -- strictness
```

**Why this decomposition.** Each section owns one pass-level concern, so a contributor fixing enum handling opens one section and a user configuring names touches one section. The alternative — dozens of flat options — scatters one concern across many knobs (naming alone would be five separate options). Grouping by decision point is what keeps both the config and the code that reads it legible.

`type_mode` stays top-level rather than moving under `types`, because it selects the *leaf spelling family for the whole run* (`c.int` vs `i32`) rather than describing one type. `config.types` is a collection of per-type rules; a run-wide mode is not one of them. See [`type-modes.md`](type-modes.md).

Two sections are intentionally *asymmetric* from the rest, and that's deliberate:

- **`naming` is a cohesive policy built by a constructor** (`config.naming = h2o.naming.odin{...}`), not a collection of independent field assignments, because naming is one coordinated policy rather than a set of unrelated overrides.
- Sections like `types`/`structs`/`procs` are **collections of independent rules** assigned to fields, because their entries genuinely are independent (one type mapping has nothing to do with another).

---

## Preprocessing, inputs, outputs

```lua
config.package = "sqlite"

config.inputs = {
    "include/sqlite3.h",
    "include/sqlite3ext.h",
}

config.output_folder = "generated"

config.preprocess.include_paths = { "include" }
config.preprocess.defines = {
    SQLITE_ENABLE_FTS5 = "1",
    SQLITE_THREADSAFE  = "1",
}
```

**Why "preprocess," not "clang."** The public concept is *preprocessing a C header* — include paths and defines are what the user reasons about. That H2Odin uses libclang internally is an implementation detail the user should not need to know, and naming the section after the tool would leak that detail and lock the public API to a specific backend.

---

## Naming

`config.naming` is responsible only for names — types, procedures, constants, macros-emitted-as-constants, enums, enum members, struct fields, parameters.

```lua
config.naming = h2o.naming.odin {
    strip_prefixes = {
        type       = { "sqlite3_", "sqlite_" },
        proc       = { "sqlite3_" },
        const      = { "SQLITE_" },
        enum_value = { "SQLITE_" },
    },

    strip_suffixes = { type = { "_t" } },

    known_tokens = {
        SQLite3 = "sqlite3",
        UTF8    = "utf8",
        UTF16   = "utf16",
        NOMEM   = "no_mem",
    },

    overrides = {
        sqlite3      = "DB",
        sqlite3_stmt = "Stmt",
    },

    override = function(sym)
        if sym.kind == "proc" and h2o.str.has_prefix(sym.name, "sqlite3_blob_") then
            return h2o.naming.snake_case(h2o.str.strip_prefix(sym.name, "sqlite3_"))
        end
        return nil
    end,
}
```

The conceptual boundary:

```text
Naming changes names. Naming does not change meaning.

sqlite3_stmt  -> Stmt   is naming.
sqlite3_int64 -> i64    is NOT naming — that is type mapping.
```

**Why `known_tokens`.** Converting a C identifier to Odin case requires splitting it into words, and that split is not deterministic in general — `sqlite3` could be one token or `sqlite` + `3`; `HTTPSConnection` could split several ways. The generator applies a fixed heuristic and marks uncertain splits, but the reliable fix is letting the user declare their domain's vocabulary once. `known_tokens` upgrades those splits from *guessed* to *certain*: the user teaches the tokenizer that `SQLite3` is one atom with a known lowercasing, and every identifier containing it is handled correctly. Where even the dictionary can't disambiguate (two known tokens overlap-match), the generator emits a diagnostic and the user resolves that one symbol via `override`. Three rungs — heuristic, dictionary, per-symbol override — each climbed only when the previous is insufficient.

---

## Types

`config.types` handles type translation and replacement — distinct from naming, because it changes *meaning*, not spelling.

```lua
-- Type mapping: wherever this C type is referenced, emit this Odin type.
config.types.map = {
    sqlite3_int64  = "i64",
    sqlite3_uint64 = "u64",
    -- Portable POSIX/libc names get built-in defaults (spec 0010):
    -- off_t → posix.off_t, time_t → libc.time_t, sockaddr → posix.sockaddr —
    -- one spelling in both type modes, imports emitted automatically.
    -- types.map always overrides the built-in map (e.g. pid_t = "i32").
}

-- Declaration override: replace the emitted representation of a type.
config.types.overrides = {
    Vector2 = "[2]f32",           -- typedef/record → Vector2 :: [2]f32 (uses keep the name)
}

-- Programmatic: a stable type view in, an action out.
config.types.override = function(t)
    if t.name == "Some_C_Type" then
        return { type = "rawptr" }
    end
    return nil
end

-- Handle safety beyond what C states: opt a void* typedef into a
-- distinct handle type (typedefs of pointers to *incomplete* records are
-- already distinct automatically — C itself distinguishes those).
config.types.distinct = { "CXIndex", "CXClientData" }

-- Incomplete tag records (typedef struct T T; used as T*): mode default is
-- ABI faithful (struct {} + ^T) / idiomatic handle (distinct rawptr + collapse).
-- Per-name override in either direction:
config.types.opaque = {
    sqlite3_stmt = true,   -- force handle even in ABI mode
    -- Some_Complete = false, -- force faithful even in idiomatic mode
}
```

**Why separate `map` and `overrides`.** `map` changes *references* to a type (every `sqlite3_int64` in a signature becomes `i64`) without changing the declaration. `overrides` rewrites the declaration: a typedef becomes `Name :: <spelling>` with use sites still naming `Name`; a named record/enum is dropped and the spelling is inlined at use sites.

**Opaque handles** (see [spec 0005](specs/0005-opaque-handle-typedefs.md) and [spec 0007](specs/0007-opaque-tag-records.md)): C has three opaque idioms and each gets the treatment its own type discipline earns. A typedef of a pointer to an incomplete record (`typedef struct Impl *H`) emits `H :: distinct rawptr` automatically — C already makes those handles mutually incompatible. `void*` typedefs stay plain `rawptr` aliases; `types.distinct` hardens them. Incomplete tag typedefs (`typedef struct T T;` used as `T *`) follow **mode**: ABI keeps `struct {}` + `^T`; idiomatic collapses to handle style. `types.opaque[name] = true/false` overrides per name; forcing a complete record fails closed under `opaque_record_complete`.

---

## Symbols: selection and removal

```lua
config.symbols.remove.names = { "SOME_INTERNAL_DECL" }

config.symbols.remove.patterns = { "*_COUNT", "*_Count" }

config.symbols.remove.where = function(sym)
    return sym.kind == "const" and h2o.str.has_prefix(sym.name, "SQLITE_PRIVATE_")
end

config.symbols.remove.deprecated = true   -- drop C-deprecated declarations
```

**Why three tiers here.** Real headers carry internal declarations, compatibility aliases, private macros, and platform-specific symbols that shouldn't be emitted. Listing them by name (tier 1) is fine for a handful; patterns (tier 2) handle families like `*_Count`; the `where` predicate (tier 3) handles "everything that is a const and starts with `SQLITE_PRIVATE_`" without enumerating them. The predicate returns a boolean and never mutates the IR — removal is Odin's job.

**Deprecated declarations** ([spec 0009](specs/0009-deprecated-declarations.md)) are the fourth, declarative tier. By default a C-deprecated API becomes a deprecated Odin declaration — `@(deprecated = "msg")` on procs and types, a `Deprecated:` doc line on constants and variables — because the header's own position is "works, but stop using it", and dropping would silently break existing callers. `remove.deprecated = true` opts into dropping them entirely; partial policies use `sym.deprecated` in a `where` predicate.

---

## Macros

A C macro can become several different Odin things — a constant, an enum member, a bit flag, an alias, or nothing. This is where Lua-as-policy pays off most, because grouping macros correctly needs *filtering* that data can't express.

```lua
local sqlite_non_result_prefixes = {
    "SQLITE_OPEN_", "SQLITE_CONFIG_", "SQLITE_DBCONFIG_",
    "SQLITE_LIMIT_", "SQLITE_STATUS_", "SQLITE_DBSTATUS_",
    "SQLITE_STMTSTATUS_",
}

config.macros.groups = {
    h2o.macro_group.enum {
        id        = "result_code",
        name      = "Result_Code",
        base_type = "c.int",

        prefix           = "SQLITE_",
        exclude_prefixes = sqlite_non_result_prefixes,

        include = function(m)
            return m:is_integer()
                and (m.value <= 100 or m.name == "SQLITE_ROW" or m.name == "SQLITE_DONE")
        end,

        member_strip_prefix  = "SQLITE_",
        emit_original_consts = false,
    },
}
```

**Why this shape.** The SQLite result codes are the canonical hard case: you want *most* `SQLITE_`-prefixed integer macros, but must exclude `SQLITE_OPEN_`, `SQLITE_CONFIG_`, etc., and cap by value. A data-only config (`enumify_macros = { "SQLITE_" = "Result_Code" }`) takes *all* of them with no way to filter — wrong result. Here, `prefix` + `exclude_prefixes` do the broad declarative selection in Odin, and `include` refines by value in Lua. The per-macro check order is fixed: `prefix` → `exclude_prefixes` → value-kind → `include` last, so the declarative filters gate before any Lua runs.

Grouping **synthesizes an ordinary explicit-valued enum in the IR** (`Result_Code :: enum c.int { OK = 0, ROW = 100, DONE = 101 }`) — explicit-valued because the whole point is preserving the C constants' values, which are non-contiguous. The synthesized enum is then indistinguishable from an extracted one: it flows through the normal rename and emit passes, so there is no parallel emit path. `emit_original_consts = false` drops the consumed macros from standalone constant output (otherwise every code appears twice). `member_strip_prefix` shortens member names before the normal naming pass recases them.

The macro **view** exposes `m.name`, `m.value`, and methods like `m:is_integer()` / `m:has_prefix(...)`. Methods are preferred because they keep representation details behind the API. The raw `m.expr` (macro body text) is deliberately *not* exposed — parsing macro bodies in Lua would be exactly the fragile, generator's-job work this design avoids.

---

## Enums

```lua
config.enums.anonymous = {
    h2o.enum.anonymous { name = "Keyboard_Key", first_member = "KEY_NULL" },
}

config.enums.member = function(member)
    -- member.enum_name, member.name, member.value
    if h2o.str.has_suffix(member.name, "_COUNT") then
        return { remove = true }
    end
    return nil
end

config.enums.bit_sets = {
    h2o.enum.bit_set { enum = "Config_Flag", name = "Config_Flags", mode = "log2" },
}
```

**Why `mode = "log2"` is explicit.** A C flag enum stores masks (`1, 2, 4, 8`); an Odin `bit_set`'s backing enum stores bit *positions* (`0, 1, 2, 3`). The conversion is therefore `value -> log2(value)`, and it only works when every member is a power of two. Naming the mode makes the transform explicit rather than magic, and it flags the failure case: a "flag" enum containing a non-power-of-two member (an all-bits mask like `_ALL = 0xFF`, or `_NONE = 0`) can't be a single bit position and must produce a diagnostic. The transform creates two named types — the `bit_set` takes the collective name (`Config_Flags`), the backing enum takes the singular (`Config_Flag`). The set is always emitted with an **explicit backing width** taken from the C enum's measured integer type (`bit_set[Config_Flag; u32]`), never bare `bit_set[E]` — Odin would otherwise size the set from the highest flag bit, which is not the C ABI size (spec 0004). A flag that does not fit that width fails closed under `bit_set_backing_mismatch`.

Enum transforms **create or modify normal IR enum declarations** — never a parallel emit path, same principle as macro grouping.

---

## Structs and unions

```lua
config.structs.fields = {
    ["BoneInfo.name"]       = { tag = 'fmt:"s,0"' },
    ["Some_Type.some_field"] = { type = "My_Type" },
}

config.structs.align = { Mesh = 4 }

config.structs.field = function(field)
    -- field.struct_name, field.name, field.type
    if field.struct_name == "BoneInfo" and field.name == "name" then
        return { tag = 'fmt:"s,0"' }
    end
    return nil
end
```

The `field` action callback returns `nil` or an action table (`{ type = ..., tag = ... }`). It receives a stable view, never the IR node.

---

## Procedures

```lua
config.procs.params = {
    ["SetConfigFlags.flags"] = { type = "Config_Flags" },
    ["DrawTexturePro.tint"]  = { default = "WHITE" },
    -- Foreign-surface curation: no procedure body, same C ABI.
    ["Decode.data"]          = { pointer = "multi" },
    ["Create.options"]       = { by_ptr = true },
}

config.procs.results = {
    GetKeyPressed = { type = "Keyboard_Key" },
}

config.procs.require_results = {
    "parse",
    "validate",
}

config.procs.param = function(param)
    -- param.proc_name, param.name, param.type
    if param.proc_name == "SetConfigFlags" and param.name == "flags" then
        return { type = "Config_Flags" }
    end
    return nil
end
```

`pointer = "multi"` selects Odin's `[^]T` foreign-pointer spelling. It does not
change ABI. `by_ptr = true` changes the Odin call shape without a procedure
body and is idiomatic-only; it requires an explicit non-null, call-borrowed
contract. C `const` is not enough to infer it. `require_results` emits the Odin
attribute on the named foreign procedures.

**What this section does, and what it does not.** Everything above adjusts a
faithful foreign declaration. None of it is a wrapper. Out-parameter results
and pointer-plus-count slices change arity or layout, so each needs a generated
procedure sitting in front of the faithful declaration.

Wrapper configuration is declarative and procedure-local:

```lua
config.procs.wrappers = {
    cgltf_parse = h2o.proc.wrapper {
        out_params = { "out_data" },
    },
    consume = h2o.proc.wrapper {
        slices = {
            { pointer = "data", count = "count", name = "data" },
        },
    },
}
```

The first closed set is out-parameter-to-result and pointer-plus-count input
slice. Borrowed output slices require an explicit lifetime contract and arrive
later. Generic `string`/`cstring` conversion is not in the initial set because
allocation, ownership, and returned-string lifetime are not header facts.

Wrapper generation is Milestone 6 and is specified by
[spec 0011](specs/0011-vendor-parity-and-idiomatic-wrappers.md). The following
remain invariant:

- The **generator** authors the wrapper, from a closed, auditable conversion set. Config selects a conversion by name; it never supplies procedure text (see *Values, not generated code*).
- A user who wants an ergonomic layer beyond that closed set writes it as ordinary hand-written Odin on top of the raw bindings. That is what `output.footer_per_header` exists to make pleasant.
- `procs.wrappers` is rejected unless `type_mode = "idiomatic"`; ABI mode never emits a procedure body.

Until Milestone 6 lands, the current `config.procs` implementation adjusts
signatures and defaults only; the future keys above are not accepted yet.

---

## Foreign linking and output

```lua
config.foreign.import_lib  = "sqlite3.lib"
config.foreign.link_prefix = "sqlite3_"

config.foreign.targets = {
    windows_amd64 = { libraries = { "lib/sqlite3.lib" } },
    linux_amd64   = { libraries = { "lib/libsqlite3.a" }, system = { "pthread" } },
    fallback      = { libraries = { "system:sqlite3" } },
}

config.output.layout            = "merged" -- or "per_header"
config.output.procedures_at_end = true
config.output.footer_per_header = true
```

**Why `link_prefix` is under `foreign`, not `naming`.** `link_prefix` is the *external C symbol* name — what the linker resolves — not the Odin-facing procedure name. Putting it under `foreign` keeps the "Odin name vs. C symbol" distinction clear; it is the counterpart to renaming, not a form of it.

`foreign.targets` is the planned structured replacement for hand-authored OS
link stanzas. The generator validates target keys and library values and owns
the emitted `when` / `foreign import` source. `foreign.import_lib` remains the
portable single-system-library shorthand. Captured function calling
conventions are ABI facts and do not require policy; config does not silently
coerce an unsupported convention to `"c"`.

`output.layout = "per_header"` emits one Odin file per `config.inputs` header into `output_folder` (required). Placement follows each declaration's home input header; synthesized macro-group enums and bit sets inherit documented placement rules. Each file carries its own prelude because Odin `import` / `foreign import` names are file-local. (`output.imports_file` was removed for that reason — [spec 0006](specs/0006-remove-imports-file.md).) Full rules: [spec 0003](specs/0003-multi-file-odin-emission.md).

`footer_per_header` supports the hand-written-layer philosophy: a `raylib.h` binding can have a `raylib_footer.odin` appended, giving users a clean place for their own Odin on top of the raw output — the sanctioned alternative to generator-authored wrappers.

---

## Diagnostics and strictness

Many binding decisions involve incomplete information or heuristics — ambiguous naming splits, macro-group conflicts, duplicate enum values, unresolved types. The generator always produces usable output, but it must *report* where it guessed.

```lua
config.diagnostics = {
    -- categories the generator already reports today
    pointer_lowering_guess    = "warn",
    unresolved_idiomatic_leaf = "warn",
    opaque_layout_fallback    = "warn",

    -- categories that arrive with the sections above
    naming_ambiguity          = "warn",
    macro_group_conflict      = "warn",
    duplicate_enum_value      = "warn",
    unresolved_type           = "error",
    unsupported_macro         = "warn",
    symbol_collision          = "error",
    bit_set_non_power_of_two  = "error",
    bit_set_backing_mismatch  = "warn",
}
```

The first three exist now and are printed unconditionally; what this section adds to them is a *severity*. Every future heuristic must register a category here rather than inventing an ad-hoc print.

**Why centralize.** Every heuristic in the generator has a "warn vs error" choice. Scattering those knobs across each feature's constructor would make strictness impossible to reason about globally. One `diagnostics` block defines the project's strictness policy in one place. Feature constructors may still carry *local* overrides for a specific case, but the global block sets the default — and when both are present, the **local override wins** (it's more specific). The default posture is `warn`, not `error`: the generator should degrade gracefully and still emit usable output, flagging what it guessed rather than halting — the same "honest about uncertainty, but never silently wrong" principle that governs pointer lowering and naming.

---

## Callback views are the stable contract

Callbacks receive small public views, never internal generator objects:

```text
sym.name, sym.kind, sym.deprecated
m.name, m.value, m.value_kind, m:is_integer()
member.enum_name, member.name, member.value
field.struct_name, field.name, field.type
param.proc_name, param.name, param.type
```

Every view is a **single table**, never positional arguments, so a field can be added later without breaking a config that already reads the old ones. Views that describe a child carry their parent's name (`field.struct_name`, `param.proc_name`, `member.enum_name`) rather than nesting the parent view.

`sym.kind` is drawn from one closed vocabulary, spelled the way *Odin* names things rather than the way C does:

```text
"proc"  "type"  "var"  "const"  "enum_value"  "field"  "param"
```

`"param"` is a procedure parameter name (parent = the owning proc; empty for
parameters of function-pointer types). Parameters have no strip lists of their
own — they share the `proc` lists. The other words key `naming.strip_prefixes`
directly. This is a deliberate rename from the strings the generator uses today (`function`, `variable`, `constant`, `enum_member`) — see the migration table in [`configuration.md`](configuration.md).

**Why.** These views are the API contract between the config and the generator. As long as they stay stable, the internal IR — pools, handles, type representation — can be refactored freely without breaking a single user config. Exposing raw IR structs would weld every config to the generator's current internals and make refactoring a breaking change. The views are deliberately minimal: just enough to make decisions, nothing that leaks representation.

---

## Execution model

The config is loaded first, but its rules run *later*, during the passes that have the data.

```text
1.  Load Lua config           (constructors and callbacks register policy)
2.  Parse and preprocess headers
3.  Build initial IR
4.  Record config-independent facts
5.  Evaluate macros
6.  Apply symbol filters
7.  Apply macro grouping       (synthesize enums)
8.  Apply enum policies
9.  Apply type mappings and overrides
10. Apply struct and procedure adjustments
11. Apply naming
12. Apply keyword safety
13. Apply collision handling
14. Emit Odin
```

This is a refinement of the four-stage pipeline, not a rival to it. Steps 2–3 are **Extraction**, step 4 is **Analysis**, steps 5–13 are **Transformation**, and step 14 is **Emission**. Every step that consults the config falls inside Transformation, which is what makes "only Transformation sees policy" hold even as this list grows. Note that macro grouping and the enum transforms *create* IR declarations during Transformation; they do not open a second emit path, so Emission stays as boring as [`architecture.md`](architecture.md) requires.

The exact internal order may evolve, but the principle is fixed:

> The config **registers** policy at load time. Odin **executes** that policy during the correct pass, once the relevant data exists.

**Why deferred execution matters.** At config-load time the generator hasn't parsed the headers yet — there are no macros, types, or symbols to act on. So the config can't *do* things at load; it can only *register* what should happen. A macro-group's `include` callback is stored at load and invoked later, once per macro, during the grouping pass. This is the mechanism that turns Lua from a static file into a policy layer that participates in the generator's passes — and it's why the same VM stays alive for the whole run rather than being consulted once at startup.

---

## Complete example: SQLite

```lua
local h2o = require "h2odin"

local config = h2o.config()

config.package       = "sqlite"
config.inputs        = { "include/sqlite3.h" }
config.type_mode     = "idiomatic"
config.output_folder = "generated"

config.preprocess.include_paths = { "include" }
config.preprocess.defines       = { SQLITE_ENABLE_FTS5 = "1" }

config.naming = h2o.naming.odin {
    strip_prefixes = {
        type       = { "sqlite3_", "sqlite_" },
        proc       = { "sqlite3_" },
        const      = { "SQLITE_" },
        enum_value = { "SQLITE_" },
    },
    strip_suffixes = { type = { "_t" } },
    known_tokens = {
        SQLite3 = "sqlite3", UTF8 = "utf8", UTF16 = "utf16", NOMEM = "no_mem",
    },
    overrides = { sqlite3 = "DB", sqlite3_stmt = "Stmt" },
}

config.types.map = {
    sqlite_int64  = "i64", sqlite3_int64  = "i64",
    sqlite_uint64 = "u64", sqlite3_uint64 = "u64",
}

local sqlite_non_result_prefixes = {
    "SQLITE_OPEN_", "SQLITE_CONFIG_", "SQLITE_DBCONFIG_", "SQLITE_LIMIT_",
    "SQLITE_STATUS_", "SQLITE_DBSTATUS_", "SQLITE_STMTSTATUS_",
    "SQLITE_IOCAP_", "SQLITE_LOCK_", "SQLITE_SYNC_", "SQLITE_TRACE_",
}

config.macros.groups = {
    h2o.macro_group.enum {
        id = "result_code", name = "Result_Code", base_type = "c.int",
        prefix = "SQLITE_", exclude_prefixes = sqlite_non_result_prefixes,
        include = function(m)
            return m:is_integer()
                and (m.value <= 100 or m.name == "SQLITE_ROW" or m.name == "SQLITE_DONE")
        end,
        member_strip_prefix = "SQLITE_", emit_original_consts = false,
    },
}

config.symbols.remove.where = function(sym)
    return sym.kind == "const" and h2o.str.has_prefix(sym.name, "SQLITE_PRIVATE_")
end

config.diagnostics = {
    naming_ambiguity     = "warn",
    macro_group_conflict = "warn",
    duplicate_enum_value  = "warn",
    unresolved_type      = "error",
    symbol_collision     = "error",
}

return config
```

---

## Final position

```text
Lua as a real program, not JSON with syntax.
Namespaced API via require "h2odin", a config object from h2o.config().
Lua decides; Odin mutates.
Small stable callback views — never raw IR.
Values, not generated code.
Predicate callbacks return boolean; action callbacks return nil or a value/table.
Declarative first; callbacks refine, never scan.
Constructors for rich rules; bare tables for simple maps.
Plural is data; singular is a callback.
Config never authors Odin source — even if the generator one day emits wrappers.
Config registers policy; Odin executes it in the correct pass.
```

This gives H2Odin the full power of Lua without becoming either JSON-with-comments or an uncontrolled scripting layer over the internal IR. The power lives in the callbacks; the safety lives in the boundary that Lua only ever *decides*, and Odin always *does*.
