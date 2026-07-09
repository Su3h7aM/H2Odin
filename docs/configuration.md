# Configuration

H2Odin is configured with a Lua file. The goal is that a well-behaved library needs only a few lines of plain data, while a difficult library can drop into Lua functions for the awkward cases — both written against the same small API.

This document describes **what the generator accepts today.** The full target shape — naming constructors, macro groups, enum transforms, diagnostics severity — is specified in [`config-spec.md`](config-spec.md). Where the two differ, the spec is the destination and this file is the map of the ground already covered.

## Why Lua

Lua lets configuration be a *program*, not just a data file. A static data format forces a separate option for every situation someone might hit. With Lua, one callback can express a whole policy, and common helpers can be shared, reused, and composed.

But power is bounded by a firm rule:

> Configuration *selects and parameterizes*; it never *authors output*.

Lua can say "rename this," "drop that," "spell this known type this way." Lua does not return Odin code for the generator to paste in. The generator owns every byte of emitted Odin; the configuration only steers which of the generator's known behaviors fire.

## Shape: `require "h2odin"` and `h2o.config()`

```lua
local h2o = require "h2odin"

local config = h2o.config()

config.package = "raylib"
config.foreign.import_lib = "raylib"
config.type_mode = "idiomatic"

config.naming = h2o.naming.odin {
  strip_prefixes = { proc = "gl", type = "GL", const = "GL_" },
  override = function(sym)
    return sym.default
  end,
}

config.types.overrides = { Vector2 = "[2]f32", Color = "distinct [4]u8" }

config.symbols.remove.where = function(sym)
  return h2o.str.has_prefix(sym.name, "_")
end

return config
```

The config file must **return** the config table. Prefer building it with `h2o.config()` so every section exists up front.

### Supported surface (Milestone 8)

| Path | Type | Role |
|------|------|------|
| `package` | string | Odin package name (default: header stem) |
| `type_mode` | `"abi"` \| `"idiomatic"` | leaf type spelling family |
| `foreign.import_lib` | string | `foreign import` system library name (default: header stem) |
| `naming.strip_prefixes` | `{ proc?, type?, const? }` | each value a string or list of strings |
| `naming.override` | `function(sym) → string\|nil` | rename a symbol |
| `types.map` | string → string | rewrite every *reference* to a C type |
| `types.overrides` | string → string | rewrite references **and** suppress the declaration |
| `symbols.remove.where` | `function(sym) → bool\|nil` | **true drops** the symbol |

`h2o.naming.odin { ... }` is constructor sugar: it type-checks the table and returns it. Field validation still runs on the Odin side at load.

Empty sections created by `h2o.config()` (`macros`, `enums`, `structs`, `procs`, `preprocess`, `output`, `diagnostics`, …) may appear; giving them real content fails with "not yet supported."

Unknown keys fail the run. Pre-M8 flat keys are rejected by name with a migration message:

`foreign_lib`, `strip_prefixes`, `type_map`, `rename`, `keep`

Also rejected explicitly (roadmap-only top-level names): `headers`, `include_dirs`, `defines`, `comments`, `wrappers`.

The header path is a CLI argument today; write stdout where you want the file.

## Callback views

Callbacks receive a single table:

| Field | Meaning |
|-------|---------|
| `name` | original C name |
| `default` | generator's default (after prefix strip + keyword safety) |
| `kind` | `"proc"` \| `"type"` \| `"var"` \| `"const"` \| `"enum_value"` \| `"field"` |
| `parent` | owning declaration for members/fields when relevant |

### Predicate vs action

- **`symbols.remove.where`** is a *predicate*: `true` acts (drops), `nil`/`false` keep. Polarity is the inverse of the old `keep` callback.
- **`naming.override`** is an *action*: return a string to rename, or `nil` for "use the default."

### Plural is data; singular is a callback

`types.overrides` is a table; `types.override` would be a function (not wired yet). Validation rejects a table where a function belongs and vice versa for the keys that exist today.

## Helpers: `h2o.str`

Registered from pure Odin (testable without a Lua VM):

| Helper | Role |
|--------|------|
| `h2o.str.has_prefix(s, prefix)` | boolean |
| `h2o.str.has_suffix(s, suffix)` | boolean |
| `h2o.str.strip_prefix(s, prefix)` | string (unchanged if no match; never empties the whole name) |

## Sandbox

The Lua state is sandboxed:

- Pure libraries: `table`, `string`, `math`, `utf8`, `coroutine`, and base.
- **Withheld:** `io`, `os`, `debug`; `dofile` / `loadfile` / `load`; `package.loadlib`.
- **`require` is allowed** but resolves only:
  1. the preloaded `h2odin` prelude, and
  2. `.lua` files beneath the config file's directory (no `..`, no absolute paths).

Determinism claim: *the same headers plus the same config tree produce byte-identical output.*

## How configuration relates to the pipeline

Configuration is consulted only during Transformation, and only through the policy layer. The generator loads and executes the configuration once at startup. Extraction, analysis, and emission never touch Lua.

The config *registers* policy at load time; Transformation *executes* it later, once the data a rule needs exists. That is why the Lua state stays alive for the whole run.

## Migration from the flat surface

| Was | Now |
|-----|-----|
| `package` | `config.package` |
| `type_mode` | `config.type_mode` |
| `foreign_lib` | `config.foreign.import_lib` |
| `strip_prefixes.func` | `config.naming.strip_prefixes.proc` |
| `type_map` (drop decl) | `config.types.overrides` |
| `type_map` (refs only) | `config.types.map` |
| `rename` | `config.naming.override` |
| `keep` (true = retain) | `config.symbols.remove.where` (**true = drop**) |
| kind `"function"` | `"proc"` |
| kind `"variable"` | `"var"` |
| kind `"constant"` | `"const"` |
| kind `"enum_member"` | `"enum_value"` |

**`keep` polarity inverts.** Translating key-for-key silently emits the wrong set of symbols. Validation rejects `keep` by name rather than accepting both.

## What we deliberately keep out for now

Struct field tags and alignment, defaulted parameters, macro grouping, enum-to-`bit_set` transforms, generated wrapper procs (Milestone 6), `naming.overrides` / `known_tokens` / case helpers (Milestone 9), multi-header inputs and preprocess knobs (Milestone 10), and diagnostics severity (Milestone 11). Each can land without disturbing the sectioned shape.
