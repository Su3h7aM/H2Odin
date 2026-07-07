# Configuration

H2Odin is configured with a Lua file. The goal is that a well-behaved library needs only a few lines of plain data, while a difficult library can drop into Lua functions for the awkward cases — both written against the same small API.

This document describes the *intent* of the configuration layer. The exact set of options and the exact fields passed to callbacks will settle as the code is written; treat the shapes here as illustrative.

## Why Lua

Lua lets configuration be a *program*, not just a data file. A static data format forces a separate option for every situation someone might hit. With Lua, one callback can express a whole policy, and common helpers can be shared, reused, and composed. That is the power we want.

But power is bounded by a firm rule:

> Configuration *selects and parameterizes*; it never *authors output*.

Lua can say "rename this," "drop that," "treat this pointer as an array," "spell this known type this way." Lua does not return Odin code for the generator to paste in. The generator owns every byte of emitted Odin; the configuration only steers which of the generator's known behaviors fire. This is what keeps the output trustworthy and reviewable no matter what a user's configuration does.

## Data for the common case, functions for the hard case

Most configuration should be plain data — inputs, output settings, prefix stripping, direct type substitutions. These cover the ordinary library with no functions at all.

When a library needs real logic, callbacks take over. A callback receives a single table describing the thing being decided, and returns a decision — a name, a boolean, or a type spelling chosen from the generator's fixed set of behaviors. Returning `nil` means "use the default," so a configuration only ever spells out the cases it actually cares about and lets everything else stay automatic.

```lua
return {
  -- inputs
  headers      = { "raylib.h" },
  include_dirs = { "/usr/include" },
  defines      = { "PLATFORM_DESKTOP" },

  -- output
  package     = "raylib",
  output      = "raylib/",
  foreign_lib = "raylib",

  -- mode
  type_mode = "idiomatic",   -- "abi" | "idiomatic"
  comments  = true,

  -- declarative common case
  strip_prefixes = { func = "gl", type = "GL", const = "GL_" },
  type_map       = { Vector2 = "[2]f32" },

  -- callbacks for the hard case (all optional)
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

A callback is only as capable as the information it receives. Rather than passing bare positional arguments, callbacks receive a single table with named fields — the original name, the generator's default choice, the kind of thing being renamed, its source file, and so on. A single table is easy to extend later without breaking existing configurations, which is why it is preferred over a fixed argument list.

The kind of a symbol matters: functions, types, constants, variables, enum members, and struct fields are often renamed by different rules, so the kind travels with every symbol.

## How configuration relates to the pipeline

Configuration is consulted only during Transformation, and only through the policy layer. The generator loads and executes the configuration once at startup, turning it into policy that Transformation can query. The rest of the pipeline — extraction, analysis, emission — never touches it.

Because the configuration is code, it can in principle do arbitrary work. The generator's determinism depends on configurations being well-behaved and side-effect-free. That is an expectation we document and encourage rather than a constraint the generator enforces.

## What we deliberately keep out for now

To protect the "simple codebase" goal, some tempting features are intentionally left out of the early configuration surface — things like per-field layout overrides, defaulted parameters, or multi-return rewrites. Each is real work for narrow benefit, and each can be added later behind a callback without disturbing what already exists. A good instinct: if a need can be met by giving an existing callback richer context, prefer that over adding a new option.
