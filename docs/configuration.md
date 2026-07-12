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

### Supported surface (current)

| Path | Type | Role |
|------|------|------|
| `package` | string | Odin package name (default: first header stem) |
| `type_mode` | `"abi"` \| `"idiomatic"` | leaf type spelling family |
| `inputs` | list of strings | multi-header inputs (paths relative to the config dir) |
| `output_folder` | string | directory for generated `.odin` files (relative to the config dir; required unless `-destination:stdout`) |
| `preprocess.include_paths` | list of strings | `-I` paths (relative to the config dir) |
| `preprocess.defines` | string → string | `-DNAME=value` (empty value → `-DNAME`) |
| `preprocess.resource_dir` | string | explicit clang builtin-header resource directory (`-resource-dir=`); relative to the config dir. Empty: query the clang driver (see `preprocess.clang`) |
| `preprocess.clang` | string | clang driver used only for `-print-resource-dir` when `resource_dir` is empty (default: `"clang"` on PATH) |
| `foreign.import_lib` | string | single-library shorthand → `foreign import lib "system:…"` (default: first header stem). Mutually exclusive with `foreign.targets` |
| `foreign.targets` | target key → `{ libraries?, system? }` | structured per-OS/ARCH linkage (spec 0011). Closed keys: `windows[_amd64\|_i386\|_arm64]`, `linux[_amd64\|_arm64]`, `darwin[_amd64\|_arm64]`, `wasm32`, `wasm64p32`, `fallback`. `libraries` are local/path strings; `system` entries become `system:…`. Emitted as a deterministic `when` chain |
| `foreign.link_prefix` | string | `@(link_prefix=…)` on the foreign block (C symbol prefix) |
| `naming.strip_prefixes` | `{ proc?, type?, const?, enum_value? }` | string or list of strings |
| `naming.strip_suffixes` | same shape | string or list of strings |
| `naming.known_tokens` | string → string | tokenizer vocabulary (surface → lower form) |
| `naming.overrides` | string → string | absolute C name → Odin name |
| `naming.override` | `function(sym) → string\|nil` | rename a symbol |
| `types.map` | string → string | rewrite every *reference* to a C type |
| `types.overrides` | string → string | rewrite references **and** suppress the declaration |
| `types.distinct` | list of strings | opt a `void*` typedef into `distinct rawptr` (incomplete-record handles are distinct automatically — [spec 0005](specs/0005-opaque-handle-typedefs.md)) |
| `types.opaque` | name → bool | per-name override for incomplete tag handle style ([spec 0007](specs/0007-opaque-tag-records.md)): mode default is ABI faithful / idiomatic collapse; `true` forces handle, `false` forces faithful; forcing a complete record fails closed under `opaque_record_complete` |
| `symbols.remove.names` | list of strings | drop exact C names |
| `symbols.remove.patterns` | list of shell patterns | drop names matching `*` / `?` patterns |
| `symbols.remove.where` | `function(sym) → bool\|nil` | **true drops** the symbol |
| `macros.groups` | list of `h2o.macro_group.enum{...}` | synthesize enums from macros |
| `enums.anonymous` | list of `h2o.enum.anonymous{...}` | name anonymous enums by first member |
| `enums.member` | `function(member) → nil\|{remove=true}` | drop enum members |
| `enums.bit_sets` | list of `h2o.enum.bit_set{...}` | flag enum → `bit_set` (`mode = "log2"`) |
| `structs.fields` | `"Struct.field"` → `{ type?, tag? }` | field type spelling and/or tag |
| `structs.field` | `function(field) → nil\|{type?,tag?}` | same, as a callback |
| `structs.align` | string → positive int | `#align(N)` on a named struct |
| `procs.params` | `"Proc.param"` → `{ type?, default?, pointer?, by_ptr? }` | raw foreign param type spelling and/or default; `pointer = "multi"` → `[^]T`; `by_ptr = true` → `#by_ptr` (idiomatic only). Does not create a wrapper |
| `procs.param` | `function(param) → nil\|{type?,default?,pointer?,by_ptr?}` | same, as a callback |
| `procs.results` | `"Proc"` → `{ type? }` | return type spelling |
| `procs.result` | `function(result) → nil\|{type?}` | same, as a callback |
| `procs.require_results` | list of C proc names | `@(require_results)` on those foreign procs; block-level attribute when every proc in the foreign block is listed |
| `procs.wrappers` | C proc → `h2o.proc.wrapper { out_params?, slices?, keep_return? }` | idiomatic-only: generate a minimal public wrapper over a retained faithful foreign decl (`_name`); plan-time validation only |
| `output.layout` | `"merged"` \| `"per_header"` | default `merged`: one Odin file; `per_header`: one file per `config.inputs` header (requires `output_folder`) |
| `output.procedures_at_end` | bool | default `true`: types then foreign block; `false`: source order |
| `output.footer_per_header` | bool | append `{stem}_footer.odin` when found next to the config or output (each unit in `per_header`) |
| `comments` | bool | default `true`: emit C doc comments; `false` suppresses them |
| `diagnostics` | category → `"warn"` \| `"error"` | per-category severity; default posture is `warn` |

Built-in foreign (system-header) types: Unix uses `posix.*` / `libc.*`; Windows rewrites socket compounds exported by `core:sys/windows` to `win32.*` (`sockaddr`, `fd_set`, `timeval`, …) and keeps portable `libc.*`. Config `types.map` / `types.overrides` still win over the built-in map.

`h2o.naming.odin { ... }`, `h2o.macro_group.enum { ... }`, `h2o.enum.anonymous { ... }`, and `h2o.enum.bit_set { ... }` are constructor sugar: they type-check the table and return it. Field validation still runs on the Odin side at load.

Unknown keys fail the run. Pre-M8 flat keys are rejected by name with a migration message:

`foreign_lib`, `strip_prefixes`, `type_map`, `rename`, `keep`

Removed nested keys are also rejected by name: `output.imports_file` (spec 0006 — Odin import/foreign names are file-local).

Also rejected explicitly (roadmap-only top-level names): `headers`, `include_dirs`, `defines`, `wrappers`.

**Inputs / output.** `config.inputs` is required (list at least one header). Relative `inputs`, `preprocess.include_paths`, and `output_folder` resolve against the config file's directory. By default the CLI writes under `config.output_folder`; if that field is unset the run fails (use `-destination:stdout` for a single merged unit on stdout). `output.layout = "per_header"` writes one `.odin` file per input under `output_folder` (same package); each file repeats the imports and `foreign import` it needs because those names are file-local. See [spec 0003](specs/0003-multi-file-odin-emission.md).

**Publication.** Writes to `output_folder` are staged under `.h2odin-stage`, then renamed into place; a `.h2odin-generated` manifest lists basenames from the last successful run so stale per-header files are removed without touching hand-written siblings. A failed stage leaves the prior generation intact. Note that successful publication still happens *before* error-severity diagnostics are reported: a non-zero exit can leave a complete new generation on disk — gate builds on the exit code, not merely on file existence.

**CLI.** Common case: `h2odin <project-dir>` loads `H2Odin.lua` from that directory. `-config:file.lua` selects an explicit config path when the default name is unavailable. Process knobs: `-destination:config|stdout` / `-d:` (default `config`), `-quiet` / `-q` (suppress diagnostics on stderr), `-verbose` / `-v` (libclang/resource-dir provenance plus detailed cause + config fix guidance), `-resource-dir:path` (override builtin-header resource directory; beats `preprocess.resource_dir`), `-help` / `-h`. Type mode, package name, headers, and all other policy are config fields — not flags.

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

Keyword safety is a generator invariant, not a naming preference: whichever
path produced the final name — the generator default, `naming.overrides`, or
the `naming.override` callback — a name that lands on an Odin keyword gets a
trailing underscore (`context` → `context_`). Config cannot opt out, because
the output would not be valid Odin.

## Callback views

| Field | Meaning |
|-------|---------|
| `name` | original C name |
| `default` | generator's default (after affix strip + keyword safety) |
| `kind` | `"proc"` \| `"type"` \| `"var"` \| `"const"` \| `"enum_value"` \| `"field"` \| `"param"` |
| `parent` | owning declaration for members/fields/params when relevant |

Parameter names go through the same naming pipeline as everything else:
`naming.override` sees them with `kind = "param"` and `parent` set to the
owning proc's (already renamed) name — empty for parameters of function-pointer
types, which have no owning proc. There is no separate `param` key under
`naming.strip_prefixes`; parameters share the `proc` strip lists, so a library
prefix stripped from procs is stripped from parameter names too.

Macro `include` callbacks receive a macro view: `m.name`, `m.value` (number or nil), `m:is_integer()`, `m:has_prefix(p)`. Raw `m.expr` is not exposed.

Enum `member` callbacks receive: `member.enum_name`, `member.name`, `member.value`.

Struct `field` callbacks receive: `field.struct_name`, `field.name`, `field.type` (best-effort name).

Proc `param` callbacks receive: `param.proc_name`, `param.name`, `param.type`.

Proc `result` callbacks receive: `result.proc_name`, `result.type`.

### Predicate vs action

- **`symbols.remove.where`** is a *predicate*: `true` acts (drops), `nil`/`false` keep.
- **`naming.override`** is an *action*: return a string to rename, or `nil` for "use the default."
- **`enums.member`** is an *action*: return `{ remove = true }` or `nil`.
- **`structs.field` / `procs.param` / `procs.result`** are *actions*: return `{ type?, tag?, default? }` or `nil`.

### Removal order

`symbols.remove` applies **names → patterns → where**. Declarative tiers gate before the Lua predicate.

### Plural is data; singular is a callback

`naming.overrides` / `types.overrides` / `structs.fields` / `procs.params` / `procs.results` are tables; the singular forms are functions. Validation rejects a table where a function belongs and vice versa for wired keys.

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

`mode = "log2"` rewrites flag masks to bit positions. Non-power-of-two members emit a `bit_set_non_power_of_two` diagnostic and skip the transform. The emitted form always carries an explicit backing width from the C enum's measured integer type — `Config_Flags :: bit_set[Config_Flag; u32]` — never a bare `bit_set[E]` (spec 0004). A flag bit that does not fit that width, or an unmeasurable backing, skips the rewrite under `bit_set_backing_mismatch`.

Constructors that emit diagnostics may carry a local severity table; when present it **beats** `config.diagnostics` for that rule only:

```lua
h2o.enum.bit_set {
  enum = "Config_Flag",
  name = "Config_Flags",
  mode = "log2",
  diagnostics = { bit_set_non_power_of_two = "warn" },
}
```

## Diagnostics

```lua
config.diagnostics = {
  pointer_lowering_guess    = "warn",
  unresolved_idiomatic_leaf = "warn",
  opaque_layout_fallback    = "warn",
  bit_field_layout_fallback = "warn",
  naming_ambiguity          = "warn",
  macro_group_conflict      = "warn",
  macro_group_empty         = "warn",
  bit_set_non_power_of_two  = "error",
  bit_set_target_missing    = "warn",
  bit_set_backing_mismatch  = "warn",
  incomplete_extern_array   = "warn",
  opaque_record_complete    = "error", -- default: types.opaque on a complete record
  symbol_collision          = "error", -- default: post-rename name clashes / type shadowing (spec 0008)
  unsupported_calling_conv  = "error", -- default: C convention has no Odin spelling (spec 0011 / M16 P0)
  -- reserved (no emitter yet): duplicate_enum_value, unsupported_macro
  -- unresolved_type is emitted for foreign by-value layouts and similar (spec 0010)
}
```

Every non-certain decision is recorded under a **named category**. Unmentioned categories default to `warn`. Severity `error` still emits usable Odin, then exits non-zero. The end-of-run report on stderr looks like:

```text
h2odin: 2 non-certain decisions:
  - warning[pointer_lowering_guess]: guessed pointer lowering in …
```

or, when any item is an error:

```text
h2odin: 2 diagnostics (1 warning, 1 error):
  - error[pointer_lowering_guess]: …
```

## Structs and procedures

```lua
config.structs.fields = {
  ["BoneInfo.name"] = { tag = 'fmt:"s,0"' },
  ["BoneInfo.parent"] = { type = "i32" },
}
config.structs.align = { Mesh = 16 }
config.structs.field = function(field)
  if field.struct_name == "Mesh" and field.name == "vertexCount" then
    return { type = "c.int" }
  end
  return nil
end

config.procs.params = {
  ["SetConfigFlags.flags"] = { type = "ConfigFlags" },
  ["DrawTexturePro.tint"] = { default = "WHITE" },
}
config.procs.results = { GetKeyPressed = { type = "c.int" } }
```

Keys use C names (`Struct.field`, `Proc.param`) and are applied **before** naming, so strip/rename does not break the maps. These adjust *spellings and defaults only* — no wrappers. In particular, setting a raw foreign parameter to `[]T` does not combine a C pointer and count; an Odin slice is two words and requires the future idiomatic wrapper layer in spec 0011.

## Foreign link prefix

```lua
config.foreign.link_prefix = "sqlite3_"
config.naming = h2o.naming.odin {
  strip_prefixes = { proc = "sqlite3_" },
}
```

Emits `@(link_prefix = "sqlite3_")` on the foreign block. When a rename leaves `C name == prefix + Odin name`, per-decl `@(link_name)` is omitted; otherwise the original C symbol is still attached via `link_name`.

## Inputs, preprocess, output

```lua
config.inputs = { "include/sqlite3.h" }
config.preprocess.include_paths = { "include" }
config.preprocess.defines = { SQLITE_ENABLE_FTS5 = "1" }
config.output_folder = "generated"
config.output.layout = "merged" -- or "per_header"
config.output.procedures_at_end = true
config.output.footer_per_header = true
config.comments = false
```

`footer_per_header` looks for `{stem}_footer.odin` next to the output folder, then next to the config file, then in the process CWD, and appends it unchanged — the sanctioned place for hand-written Odin on top of raw bindings. With `per_header`, each unit uses its own input stem.

`comments` (default `true`) controls doc-comment passthrough. Extraction still captures comments when they are present; `false` only skips writing them at emission.

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

Pass order inside Transformation is: pointer/leaf lowering → macro grouping →
enum policies → opaque/foreign type handling → type rewrites → struct/proc
adjustments → symbol removal → naming → final-name validation. Output planning
runs right after Transformation in `main`; bit-field fallback planning and
diagnostics reporting follow before and after emission respectively.

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

Structured per-target foreign linkage and idiomatic wrappers (spec 0011) are
implemented. Wrappers use `procs.wrappers` with `out_params` / `slices`; bodies
are minimal (`raw_data` + `len`, out-param multi-results). The first wrapper set is out-parameter results and pointer-plus-count input
slices in idiomatic mode. Generic string conversion and library-specific helper
bodies are not part of that first set.
