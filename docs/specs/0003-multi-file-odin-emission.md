# Spec 0003 — Multi-file Odin emission by input header

**Status:** accepted (implemented — Milestone 14)
**Date:** 2026-07-10

## Context

Milestone 13 made `config.inputs` a real multi-header input set. Extraction now
captures declarations from every configured header into one shared IR and
deduplicates declarations seen through includes or more than one translation
unit. Output is still always one merged Odin file: `main` derives its name from
`config.inputs[1]` and Emission walks the one global ordering list.

Both layouts are useful:

- a merged file is compact and remains the best default for single-header
  libraries and users who do not care about the C source layout;
- a per-header package makes a family such as `clang-c/*.h` easier to navigate
  and compare, with `Index.h` producing `Index.odin`, `CXString.h` producing
  `CXString.odin`, and so on.

All generated files remain in one Odin package. Splitting files is organization,
not dependency management: Odin resolves package-level declarations without
requiring C include order or declaration dependency order.

## Language

**Input header** — a header explicitly listed in `config.inputs`. Transitive
includes that are not listed remain external and never receive an output file.

**Home header** — the input header to which one live IR declaration belongs for
output placement. For a record or enum first captured as a placeholder, a later
definition becomes its home; an incomplete declaration keeps its original home.

**Output unit** — one self-contained generated Odin file: package clause,
file-local imports and foreign-library declaration when needed, followed by the
declarations assigned to it.

**Merged layout** — one output unit containing every live declaration.

**Per-header layout** — one output unit for every input header, including an
input that contributes no emitted declarations.

## Decision

### Configuration

Add one closed output-layout choice:

```lua
-- Backward-compatible default.
config.output.layout = "merged"

-- One configured input header becomes one Odin file.
config.output.layout = "per_header"
```

Unknown values fail config loading. This is an enum-like string rather than a
boolean so the meaning is explicit at the call site and a genuinely different
future layout would not require another competing flag.

`merged` preserves today's behavior and filename: the first input header's stem
plus `.odin`. `per_header` requires `config.output_folder`; multiple generated
files cannot be represented faithfully on stdout.

### File naming

The first version mirrors file cardinality and basename, not the input directory
tree. Each input uses `stem(base(input)) .. ".odin"` under `output_folder`:

```text
headers/Index.h    -> bindings/Index.odin
headers/CXString.h -> bindings/CXString.odin
```

If two inputs produce the same output filename (for example `a/foo.h` and
`b/foo.hpp`), planning fails before any file is written and reports both inputs.
There is no output-name override in this milestone: fail clearly, keep the public
surface small, and add path mirroring or an explicit map only after a real use
case requires it.

Output units are ordered exactly like `config.inputs`. Declarations within an
output unit keep their relative order from the final IR ordering list. The same
headers and config therefore remain byte-for-byte deterministic.

### Declaration placement

Extraction records the input-header identity reported by each declaration's
libclang source location. It copies only a small H2Odin handle into the IR; no
libclang file or location handle escapes Extraction.

Records and enums may be created from a forward declaration or type reference
and completed later. When a definition is captured from another input header,
the definition becomes the declaration's home header. If no definition is ever
captured, the first declaration remains home.

Transformation-created declarations inherit placement instead of making
Emission guess:

- a configured `bit_set` is placed with its backing enum;
- a macro-group enum is placed with the first matched macro in final input/order
  order, even when the group consumes macros from several headers;
- any future synthesized declaration must name an explicit placement rule before
  it can be emitted in `per_header` layout.

A live declaration with no home header is an internal planning error in
`per_header` layout. It must fail before emission rather than silently falling
back to the first file.

### Prelude and existing output options

Odin import aliases and foreign-library names are file-local. A separate
`imports.odin` therefore cannot make `c` or `lib` visible in sibling source
files. Each output unit must emit its own required `import "core:c"`,
`foreign import lib`, and foreign block.

Consequently, `output.imports_file` is incompatible with any multi-file
layout. Spec 0006 removes the option entirely (rejected by name with a
migration message); it is not silently ignored.

`output.footer_per_header` gains its literal meaning in per-header layout: each
unit looks for `{stem}_footer.odin` using the existing output-folder,
config-directory, then CWD search order and appends only that footer. In merged
layout it keeps today's first-input-stem behavior.

`output.procedures_at_end`, comments, package naming, foreign-library naming,
link prefixes, and diagnostics apply uniformly to every unit.

## Architecture

The split is planned before text is serialized:

```text
Extraction               Transformation                 Emission
source location     ->    output layout + placement ->  serialize output units
Input_Header_Handle       Output_Plan                    []Generated_File
```

- **Extraction** interns configured input headers and stores a small home-header
  handle as a config-independent fact on each captured declaration. The existing
  normalized-path input set becomes a path-to-handle map.
- **Analysis** is unchanged.
- **Transformation** is the only stage that reads `output.layout`. A final pure
  output-planning pass validates filenames and option compatibility, assigns the
  final ordering list to output units, and returns an `Output_Plan`.
- **Emission** accepts that plan and serializes each unit. It does not inspect
  source paths or policy and does not decide placement.
- **Main/output writing** writes the returned relative filenames and appends any
  planned footer. It does not derive stems or repartition declarations.

The intended deep seam is one planning interface and one serialization
interface, conceptually:

```odin
plan_outputs :: proc(ir: ^IR, policy: ^Policy) -> (Output_Plan, bool)
emit         :: proc(ir: ^IR, plan: Output_Plan) -> []Generated_File
```

The exact type names may follow surrounding code, but the ownership is fixed:
source provenance is an IR fact, layout is a Transformation decision, and bytes
are Emission's responsibility.

## Implementation plan

Land the feature as focused, independently checkable changes:

1. **Capture declaration provenance.** Add input-header handles and home-header
   facts, update placeholder completion, and unit-test sibling-header ownership
   without changing merged output.
2. **Load and plan the layout.** Add `output.layout`, validation, synthesized
   declaration inheritance, collision checks, and pure output-plan tests.
3. **Serialize output units.** Refactor the existing emitter to consume an
   explicit declaration slice per unit and return named generated files; prove
   merged output is byte-identical with golden/regression tests.
4. **Write per-header packages.** Require `output_folder`, emit file-local
   preludes, apply per-unit footers, and add e2e fixtures
   that `odin check` the whole generated directory.
5. **Dogfood and document.** Set the libclang self-host config to `per_header`,
   regenerate the checked-in package, update the configuration docs/examples,
   and verify every generated libclang header file belongs to one Odin package.

## Acceptance criteria

1. Omitting `output.layout` or choosing `"merged"` produces byte-identical output
   to the current generator for existing examples.
2. Two configured sibling headers produce two `.odin` files, each containing
   only declarations whose home is that header, with shared declarations emitted
   exactly once.
3. A declaration first referenced through `Index.h` but defined in `CXString.h`
   is emitted in `CXString.odin`.
4. A macro-group enum and a configured bit set follow their documented inherited
   placement rules.
5. Empty/macro-only input headers still receive valid Odin files.
6. Duplicate output stems, missing `output_folder`, unknown layouts, and
   unplaced live declarations all fail before writes.
7. Per-header footer lookup appends the matching footer only.
8. The generated multi-file fixture and libclang package pass `odin check`; the
   full `make format && make check && make test && make build` gate passes.

## Out of scope

- One Odin package per header. All files belong to the configured package.
- Mirroring nested input directories or configuring output names.
- Splitting declarations by category (types/procedures/macros) rather than source
  header.
- Emitting files for unlisted transitive includes.
- Reconstructing C `#include` directives as Odin imports.
- Atomic replacement or stale-file cleanup in `output_folder`; those are separate
  output-writer concerns.

## Consequences

- The libclang binding package can mirror the pinned `clang-c` header family
  without changing its public Odin package or symbol names.
- Source provenance becomes a first-class IR fact with uses beyond this feature
  (diagnostics may later report a home header), while libclang remains confined
  to Extraction.
- Transformation gains the single explicit output-planning seam; Emission becomes
  simpler to test because it serializes already-partitioned declaration lists.
- Repeating a small prelude per Odin file is necessary correctness, not cosmetic
  duplication, because those names are file-local.
