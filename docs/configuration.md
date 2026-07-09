# Configuration

H2Odin is configured with a Lua file. The goal is that a well-behaved library needs only a few lines of plain data, while a difficult library can drop into Lua functions for the awkward cases — both written against the same small API.

This document describes **what the generator accepts today.** The shape it is growing toward — a namespaced `h2o` API, sectioned config, macro grouping, enum transforms — is specified in [`config-spec.md`](config-spec.md). Where the two differ, the spec is the destination and this file is the map of the ground already covered.

## Why Lua

Lua lets configuration be a *program*, not just a data file. A static data format forces a separate option for every situation someone might hit. With Lua, one callback can express a whole policy, and common helpers can be shared, reused, and composed. That is the power we want.

But power is bounded by a firm rule:

> Configuration *selects and parameterizes*; it never *authors output*.

Lua can say "rename this," "drop that," "spell this known type this way." Lua does not return Odin code for the generator to paste in. The generator owns every byte of emitted Odin; the configuration only steers which of the generator's known behaviors fire. This is what keeps the output trustworthy and reviewable no matter what a user's configuration does.

This rule is permanent, and it is narrower than it sounds: it constrains *who writes the Odin*, not whether the generator may ever emit a procedure body. Wrapper generation is deferred work (ROADMAP Milestone 6); if it lands, the generator authors the wrapper and config merely selects the conversion.

## Supported surface

The config file must **return a table**. Top-level keys are validated at load:

| Key | Type | Role |
|-----|------|------|
| `package` | string | Odin package name (default: header stem) |
| `foreign_lib` | string | `foreign import` system library name (default: header stem) |
| `type_mode` | `"abi"` \| `"idiomatic"` | leaf type spelling family |
| `strip_prefixes` | `{ func?, type?, const? }` | drop a C prefix by symbol kind |
| `type_map` | string → string | force an Odin spelling for a named C type |
| `rename` | `function(sym) → string\|nil` | rename a symbol |
| `keep` | `function(sym) → bool\|nil` | filter top-level declarations |

Unknown keys fail the run. Keys that appear in the spec but are **not yet supported** also fail explicitly, so they never silently no-op:

`headers`, `include_dirs`, `defines`, `output`, `comments`, `wrappers`

The header path is a CLI argument today; write stdout where you want the file.

```lua
return {
  package     = "raylib",
  foreign_lib = "raylib",
  type_mode   = "idiomatic",

  strip_prefixes = { func = "gl", type = "GL", const = "GL_" },
  type_map       = { Vector2 = "[2]f32" },

  rename = function(sym)
    return sym.default
  end,

  keep = function(sym)
    if sym.name:match("^_") then return false end
    return true
  end,
}
```

## Passing rich context to callbacks

A callback is only as capable as the information it receives. Rather than passing bare positional arguments, callbacks receive a single table with named fields — the original name, the generator's default choice, the kind of thing being renamed, and (for members/fields) the parent name. A single table is easy to extend later without breaking existing configurations.

The kind of a symbol matters: functions, types, constants, variables, enum members, and struct fields are often renamed by different rules, so the kind travels with every symbol (`"function"`, `"type"`, `"variable"`, `"constant"`, `"enum_member"`, `"field"`).

## Sandbox

The Lua state is sandboxed: pure libraries (`table`, `string`, `math`, `utf8`, `coroutine`, and base) are available; `io`, `os`, `package`, and `debug` are not, and `dofile` / `loadfile` / `load` are nil.

The spec loosens this in one specific way, to support `require "h2odin"` and multi-file configs: `require` will resolve the preloaded prelude and `.lua` files beneath the config's own directory, and nothing else. `io`, `os`, `debug`, and the raw loaders stay withheld. The determinism claim narrows accordingly — from "the config cannot touch the filesystem" to "the same headers plus the same config tree produce byte-identical output."

## How configuration relates to the pipeline

Configuration is consulted only during Transformation, and only through the policy layer. The generator loads and executes the configuration once at startup, turning it into policy that Transformation can query. The rest of the pipeline — extraction, analysis, emission — never touches it.

The config *registers* policy at load time; Transformation *executes* it later, once the data a rule needs exists. That is why the Lua state stays alive for the whole run rather than being consulted once and discarded.

## Migrating to the spec

The spec renames most of the surface above. These are the moves, and one of them is a trap.

| Today | Spec |
|---|---|
| `package` | `config.package` (unchanged) |
| `type_mode` | `config.type_mode` (unchanged) |
| `foreign_lib` | `config.foreign.import_lib` |
| `headers` | `config.inputs` |
| `include_dirs` / `defines` | `config.preprocess.include_paths` / `.defines` |
| `output` | `config.output_folder`, plus the `config.output` block |
| `strip_prefixes` | `config.naming.strip_prefixes` |
| `type_map` | `config.types.map` |
| `rename` | `config.naming.override` |
| `keep` | `config.symbols.remove.where` |

Three of those do not survive a mechanical rewrite.

**`keep` and `remove.where` have opposite polarity.** `keep` returns `true` to *retain* a symbol; `remove.where` returns `true` to *delete* it. A config translated key-for-key emits exactly the wrong set of symbols, silently. Validation must reject `keep` by name once `symbols.remove` exists, rather than quietly accepting both.

**Symbol kinds are respelled** toward Odin's vocabulary: `function` → `proc`, `variable` → `var`, `constant` → `const`, `enum_member` → `enum_value`. `type` and `field` are unchanged. The same words key `strip_prefixes`, where `func` becomes `proc`.

**`type_map` splits in two.** The spec separates `types.map` (rewrites every *reference* to a C type) from `types.overrides` (replaces the emitted *declaration*). Today's canonical example, `type_map = { Vector2 = "[2]f32" }`, is the second of those — it is an override, not a mapping.

## What we deliberately keep out for now

To protect the "simple codebase" goal, some features in the spec are intentionally absent from the early surface — struct field tags and alignment, defaulted parameters, macro grouping, enum-to-`bit_set` transforms, and generated wrapper procs (Milestone 6). Each is real work for narrow benefit, and each can be added later without disturbing what already exists. A good instinct: if a need can be met by giving an existing callback richer context, prefer that over adding a new option.
