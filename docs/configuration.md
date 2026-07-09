# Configuration

H2Odin is configured with a Lua file. The goal is that a well-behaved library needs only a few lines of plain data, while a difficult library can drop into Lua functions for the awkward cases — both written against the same small API.

This document describes **what the generator accepts today.** The full target shape is specified in [`config-spec.md`](config-spec.md). Where the two differ, the spec is the destination and this file is the map of the ground already covered.

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

### Supported surface (through Milestone 9)

| Path | Type | Role |
|------|------|------|
| `package` | string | Odin package name (default: header stem) |
| `type_mode` | `"abi"` \| `"idiomatic"` | leaf type spelling family |
| `foreign.import_lib` | string | `foreign import` system library name (default: header stem) |
| `naming.strip_prefixes` | `{ proc?, type?, const?, enum_value? }` | string or list of strings |
| `naming.strip_suffixes` | same shape | string or list of strings |
| `naming.known_tokens` | string → string | tokenizer vocabulary (surface → lower form) |
| `naming.overrides` | string → string | absolute C name → Odin name |
| `naming.override` | `function(sym) → string\|nil` | rename a symbol |
| `types.map` | string → string | rewrite every *reference* to a C type |
| `types.overrides` | string → string | rewrite references **and** suppress the declaration |
| `symbols.remove.names` | list of strings | drop exact C names |
| `symbols.remove.patterns` | list of shell patterns | drop names matching `*` / `?` patterns |
| `symbols.remove.where` | `function(sym) → bool\|nil` | **true drops** the symbol |
| `macros.groups` | list of `h2o.macro_group.enum{...}` | synthesize enums from macros |
| `enums.anonymous` | list of `h2o.enum.anonymous{...}` | name anonymous enums by first member |
| `enums.member` | `function(member) → nil\|{remove=true}` | drop enum members |
| `enums.bit_sets` | list of `h2o.enum.bit_set{...}` | flag enum → `bit_set` (`mode = "log2"`) |

`h2o.naming.odin { ... }`, `h2o.macro_group.enum { ... }`, `h2o.enum.anonymous { ... }`, and `h2o.enum.bit_set { ... }` are constructor sugar: they type-check the table and return it. Field validation still runs on the Odin side at load.

Empty sections that are not yet wired (`structs`, `procs`, `preprocess`, `output`, `diagnostics`, `inputs`, `output_folder`) may appear; giving them real content fails with "not yet supported."

Unknown keys fail the run. Pre-M8 flat keys are rejected by name with a migration message:

`foreign_lib`, `strip_prefixes`, `type_map`, `rename`, `keep`

Also rejected explicitly (roadmap-only top-level names): `headers`, `include_dirs`, `defines`, `comments`, `wrappers`.

The header path is a CLI argument today; write stdout where you want the file.

## Naming convention (foreign porting)

Automatic naming **keeps C case** after prefix/suffix strip and keyword safety. That matches Odin's foreign/vendor guidance: keep the original authors' case so C and Odin call sites stay parallel ([foreign system](https://odin-lang.org/docs/overview/#foreign-system)).

To recase deliberately, use the pure helpers in a callback:

```lua
override = function(sym)
  if sym.kind == "proc" then
    return h2o.naming.snake_case(h2o.str.strip_prefix(sym.name, "sqlite3_"))
  end
  return nil
end
```

Or set absolute names with `naming.overrides`.

## Callback views

| Field | Meaning |
|-------|---------|
| `name` | original C name |
| `default` | generator's default (after affix strip + keyword safety) |
| `kind` | `"proc"` \| `"type"` \| `"var"` \| `"const"` \| `"enum_value"` \| `"field"` |
| `parent` | owning declaration for members/fields when relevant |

Macro `include` callbacks receive a macro view: `m.name`, `m.value` (number or nil), `m:is_integer()`, `m:has_prefix(p)`. Raw `m.expr` is not exposed.

Enum `member` callbacks receive: `member.enum_name`, `member.name`, `member.value`.

### Predicate vs action

- **`symbols.remove.where`** is a *predicate*: `true` acts (drops), `nil`/`false` keep.
- **`naming.override`** is an *action*: return a string to rename, or `nil` for "use the default."
- **`enums.member`** is an *action*: return `{ remove = true }` or `nil`.

### Removal order

`symbols.remove` applies **names → patterns → where**. Declarative tiers gate before the Lua predicate.

### Plural is data; singular is a callback

`naming.overrides` / `types.overrides` are tables; `naming.override` / `types.override` would be functions. Validation rejects a table where a function belongs and vice versa for wired keys.

## Helpers

Registered from pure Odin (testable without a Lua VM):

| Helper | Role |
|--------|------|
| `h2o.str.has_prefix` / `has_suffix` | boolean |
| `h2o.str.strip_prefix` / `strip_suffix` | string (never empties the whole name) |
| `h2o.naming.snake_case(s)` | lower snake_case via the tokenizer |
| `h2o.naming.ada_case(s)` | Ada_Case via the tokenizer |

## Macro groups

```lua
config.macros.groups = {
  h2o.macro_group.enum {
    id = "result_code",
    name = "Result_Code",
    prefix = "SQLITE_",
    exclude_prefixes = { "SQLITE_OPEN_" },
    member_strip_prefix = "SQLITE_",
    emit_original_consts = false,
    include = function(m)
      return m:is_integer() and m.value <= 100
    end,
  },
}
```

Per-macro order: `prefix` → `exclude_prefixes` → integer value-kind → `include`. Matching macros become an ordinary explicit-valued IR enum; with `emit_original_consts = false` they are dropped as standalone constants.

## Enum policies

```lua
config.enums.anonymous = {
  h2o.enum.anonymous { name = "Keyboard_Key", first_member = "KEY_NULL" },
}
config.enums.member = function(member)
  if h2o.str.has_suffix(member.name, "_COUNT") then
    return { remove = true }
  end
  return nil
end
config.enums.bit_sets = {
  h2o.enum.bit_set { enum = "Config_Flag", name = "Config_Flags", mode = "log2" },
}
```

`mode = "log2"` rewrites flag masks to bit positions. Non-power-of-two members emit a `bit_set_non_power_of_two` diagnostic and skip the transform.

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

Pass order inside Transformation (config-spec): macro grouping → enum policies → type rewrites → symbol removal → naming.

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

**`keep` polarity inverts.** Validation rejects `keep` by name rather than accepting both.

## What we deliberately keep out for now

Struct field tags and alignment, procedure signature spelling/defaults, multi-header inputs and preprocess knobs (Milestone 10), diagnostics severity (Milestone 11), and generated wrapper procs (Milestone 6). Each can land without disturbing the sectioned shape.
