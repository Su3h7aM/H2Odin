# H2Odin

A C-header-to-Odin bindings generator, written in Odin.

H2Odin reads C headers with libclang and produces clean, idiomatic Odin bindings — configured through a small but powerful Lua policy layer.

> Status: usable pipeline (Milestones 0–5 + 7–8). Idiomatic *wrappers* (Milestone 6) are deferred.

---

## Features

- **Two type modes.** *ABI mode* preserves the C API faithfully using Odin's C-compatible types (`c.int`, `c.size_t`, …). *Idiomatic mode* generates native Odin types (`i32`, `f64`, …) where the substitution is proven ABI-safe on the target. Generated wrapper procedures (e.g. `cstring → string` params, `pointer+length → []T` slices) are planned, not yet implemented.
- **Correctness first.** A type is never swapped for a nicer-looking one if it would break behavior or the ABI. When the header is ambiguous, H2Odin picks a safe default, flags it, and lets you override it — it never silently guesses wrong.
- **Deterministic.** Same headers plus the same config tree always produce identical output. The Lua config is sandboxed (no `io`/`os`/`debug`, no raw loaders); `require` only resolves the `h2odin` prelude and sibling `.lua` under the config directory.
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
./build/h2odin -config:file.lua [-quiet]
```

- A **Lua config is required.** Headers, type mode, naming, output path, and other policy live there (`config.inputs`, `config.type_mode`, `config.output_folder`, …).
- Generated Odin goes to **stdout**, or to files under `config.output_folder` when set (relative paths resolve against the config directory).
- Non-certain decisions go to **stderr** as a single diagnostics report; `-quiet` / `-q` suppresses that report (error severities still fail the run).
- `-help` / `-h` prints usage.

Example (writes `examples/sqlite3/sqlite3.odin` via `config.output_folder = "."`):

```sh
./build/h2odin -config:examples/sqlite3/config.lua
```

Check generated examples:

```sh
odin check examples/sqlite3 -no-entry-point -collection:vendored=$(pwd)/vendored
odin check examples/fff     -no-entry-point -collection:vendored=$(pwd)/vendored
```

---

## Configuration

Configuration is a Lua program that **`require "h2odin"`**, builds a sectioned object with **`h2o.config()`**, and **returns** it. Common cases are plain data; hard cases are callbacks that return a decision, or `nil` to accept the default.

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

| Path | Role |
|------|------|
| `package` / `type_mode` | package name; ABI vs idiomatic leaves |
| `inputs` / `preprocess.*` | multi-header inputs; `-I` / `-D` |
| `foreign.import_lib` / `link_prefix` | system library; C symbol prefix |
| `naming.strip_prefixes` | drop a C prefix by kind (`proc` / `type` / `const`) |
| `naming.override` | rename callback |
| `types.map` / `types.overrides` | type spellings (refs only vs also drop the decl) |
| `structs.*` / `procs.*` | field tags/align; param/result spellings and defaults |
| `output.*` / `output_folder` | layout, imports file, footers |
| `symbols.remove.where` | **true drops** a top-level declaration |

Unknown keys and not-yet-supported sections (`diagnostics`) fail the run with a clear error. Pre-M8 flat keys (`keep`, `rename`, `type_map`, …) are rejected with migration messages.

More detail: [`docs/configuration.md`](docs/configuration.md). Full north-star: [`docs/config-spec.md`](docs/config-spec.md).

---

## Documentation

Design and architecture notes live in [`docs/`](docs/). Start with [`CONTEXT.md`](CONTEXT.md) for orientation and [`ROADMAP.md`](ROADMAP.md) for status.

## License

To be decided.
