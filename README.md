# H2Odin

A C-header-to-Odin bindings generator, written in Odin.

H2Odin reads C headers with libclang and produces clean, idiomatic Odin bindings — configured through a small but powerful Lua policy layer.

> Status: usable pipeline (Milestones 0–5 + 7). Idiomatic *wrappers* (Milestone 6) are deferred.

---

## Features

- **Two type modes.** *ABI mode* preserves the C API faithfully using Odin's C-compatible types (`c.int`, `c.size_t`, …). *Idiomatic mode* generates native Odin types (`i32`, `f64`, …) where the substitution is proven ABI-safe on the target. Generated wrapper procedures (e.g. `cstring → string` params, `pointer+length → []T` slices) are planned, not yet implemented.
- **Correctness first.** A type is never swapped for a nicer-looking one if it would break behavior or the ABI. When the header is ambiguous, H2Odin picks a safe default, flags it, and lets you override it — it never silently guesses wrong.
- **Deterministic.** Same headers plus same configuration always produce identical output. The Lua config is sandboxed (no `io`/`os`/`package`) so side effects cannot sneak in by accident.
- **Configurable in Lua.** Simple libraries need a few lines of data; tricky ones drop into Lua functions for the hard cases — same small API either way.
- **Diagnostics report.** Every non-certain decision in a run (guessed pointer lowerings, unresolved idiomatic leaves, opaque layout fallbacks, …) is listed on stderr after generation.

---

## Requirements

- [Odin](https://odin-lang.org/) compiler
- A libclang shared library (the Clang C API), findable by the linker
- `odinfmt` only if you use `make format`

---

## Building

```sh
make check   # type-check the package
make build   # produce build/h2odin
make test    # unit + e2e tests (builds the binary first)
make format  # odinfmt via odinfmt.json
```

---

## Usage

```sh
./build/h2odin [-mode:abi|idiomatic] [-config:file.lua] <header.h>
```

- Generated Odin goes to **stdout**.
- Non-certain decisions and other honesty notes go to **stderr** as a single report.
- `-mode:` on the CLI overrides `type_mode` in the config; default is ABI.
- The header path is always a CLI argument (config keys like `headers` / `include_dirs` are not wired yet).

Example:

```sh
./build/h2odin -mode:idiomatic -config:examples/sqlite3/config.lua examples/sqlite3/sqlite3.h \
  > examples/sqlite3/sqlite3.odin
```

Check generated examples:

```sh
odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/fff     -no-entry-point -collection:vendored=$(pwd)/vendored
```

---

## Configuration

Configuration is a Lua file that **returns a table**. Common cases are plain data; hard cases are callbacks that return a decision, or `nil` to accept the default.

Supported keys today:

| Key | Type | Role |
|-----|------|------|
| `package` | string | Odin package name (default: header stem) |
| `foreign_lib` | string | `foreign import` system library name (default: header stem) |
| `type_mode` | `"abi"` \| `"idiomatic"` | leaf type spelling family |
| `strip_prefixes` | table `{ func?, type?, const? }` | drop a C prefix by symbol kind |
| `type_map` | table string→string | force an Odin spelling for a named C type |
| `rename` | function(sym) → string\|nil | rename a symbol |
| `keep` | function(sym) → bool\|nil | drop top-level declarations |

Unknown keys and not-yet-supported keys (`headers`, `include_dirs`, `defines`, `output`, `comments`, `wrappers`) fail the run with a clear error.

```lua
return {
  package     = "raylib",
  foreign_lib = "raylib",
  type_mode   = "idiomatic",

  strip_prefixes = { func = "gl", type = "GL", const = "GL_" },
  type_map       = { Vector2 = "[2]f32", Color = "distinct [4]u8" },

  rename = function(sym)
    return sym.default
  end,

  keep = function(sym)
    if sym.name:match("^_") then return false end
    return true
  end,
}
```

More detail: [`docs/configuration.md`](docs/configuration.md).

---

## Documentation

Design and architecture notes live in [`docs/`](docs/). Start with [`CONTEXT.md`](CONTEXT.md) for orientation and [`ROADMAP.md`](ROADMAP.md) for status.

## License

To be decided.
