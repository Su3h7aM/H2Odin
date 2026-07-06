# H2Odin

A C-header-to-Odin bindings generator, written in Odin.

H2Odin reads C headers with libclang and produces clean, idiomatic Odin bindings — configured through a small but powerful Lua policy layer.

> Status: early development.

---

## Features

- **Two type modes.** *ABI mode* preserves the C API faithfully using Odin's C-compatible types (`c.int`, `c.size_t`, …). *Idiomatic mode* generates native Odin types (`i32`, `f64`, `string`) and small wrappers, so the bindings feel written in Odin.
- **Correctness first.** A type is never swapped for a nicer-looking one if it would break behavior or the ABI. When the header is ambiguous, H2Odin picks a safe default, flags it, and lets you override it — it never silently guesses wrong.
- **Deterministic.** Same headers plus same configuration always produce identical output.
- **Configurable in Lua.** Simple libraries need a few lines of data; tricky ones drop into Lua functions for the hard cases — same small API either way.

---

## Configuration

Configuration is a Lua file. Common cases are plain data; hard cases are callbacks that return a decision, or `nil` to accept the default.

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
  wrappers  = true,
  comments  = true,

  -- declarative common case
  strip_prefixes = { func = "gl", type = "GL", const = "GL_" },
  type_map       = { Vector2 = "[2]f32", Color = "distinct [4]u8" },

  -- callbacks for the hard cases (all optional)
  rename = function(sym)
    return sym.default
  end,

  keep = function(sym)
    if sym.name:match("^_") then return false end
    return true
  end,
}
```

---

## Building

> Requires the Odin compiler and a libclang shared library.

Build and usage instructions will land with the first release.

---

## Documentation

Design and architecture notes live in [`docs/`](docs/).

## License

To be decided.
