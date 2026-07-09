# Configuration

H2Odin is configured with a Lua file. The goal is that a well-behaved library needs only a few lines of plain data, while a difficult library can drop into Lua functions for the awkward cases — both written against the same small API.

## Why Lua

Lua lets configuration be a *program*, not just a data file. A static data format forces a separate option for every situation someone might hit. With Lua, one callback can express a whole policy, and common helpers can be shared, reused, and composed. That is the power we want.

But power is bounded by a firm rule:

> Configuration *selects and parameterizes*; it never *authors output*.

Lua can say "rename this," "drop that," "spell this known type this way." Lua does not return Odin code for the generator to paste in. The generator owns every byte of emitted Odin; the configuration only steers which of the generator's known behaviors fire. This is what keeps the output trustworthy and reviewable no matter what a user's configuration does.

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

Unknown keys fail the run. Keys that appear in older design notes but are **not yet supported** also fail explicitly (so they never silently no-op):

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

The Lua state is sandboxed: pure libraries (`table`, `string`, `math`, `utf8`, `coroutine`, and base) are available; `io`, `os`, `package`, and `debug` are not, and `dofile` / `loadfile` / `load` are nil. That makes "config has no host side effects" structural rather than a convention alone.

## How configuration relates to the pipeline

Configuration is consulted only during Transformation, and only through the policy layer. The generator loads and executes the configuration once at startup, turning it into policy that Transformation can query. The rest of the pipeline — extraction, analysis, emission — never touches it.

## What we deliberately keep out for now

To protect the "simple codebase" goal, some tempting features are intentionally left out of the early configuration surface — things like per-field layout overrides, defaulted parameters, multi-return rewrites, or generated wrapper procs (Milestone 6). Each is real work for narrow benefit, and each can be added later behind a callback without disturbing what already exists. A good instinct: if a need can be met by giving an existing callback richer context, prefer that over adding a new option.
