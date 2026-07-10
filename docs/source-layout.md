# Source Layout

What each file in `src/` is for, and the planned split of the files that have
outgrown a single scope. One package (`h2odin`), flat directory — the split is
about file scope, not about introducing packages or abstractions.

**Rule:** one file = one well-defined scope, named for what it holds. Split a
file when you touch it for other work (or as a dedicated `refactor:` commit
that moves code verbatim — no behavior changes mixed in). Unit tests follow
their subject (`x.odin` → `x_test.odin`).

## Files that stay as they are

| File | Scope |
|------|-------|
| `main.odin` | Stage order, CLI, generation arena, output writing. |
| `ir.odin` | The IR: pools, handles, ordering list, `add_*` helpers. |
| `analyze.odin` | Facts true regardless of config (length-like neighbours). |
| `diagnostics.odin` | Diagnostic categories, severity resolution, the report. |
| `types.odin` | The type-spelling tables (single source of truth). |
| `naming.odin` | Pure tokenizer + case conversion (registered into Lua). |
| `str.odin` | Pure string helpers (registered into Lua). |
| `macro_value.odin` | Macro literal parsing helpers. |

## Planned splits

### `policy.odin` — done

Split along the six concerns (verbatim move; behavior unchanged):

| File | Scope |
|------|-------|
| `policy.odin` | `Policy` struct, feature-rule structs, `policy_load` / `policy_destroy`, top-level orchestration. |
| `policy_sandbox.odin` | The sandboxed VM: allowed libs, `require` searcher/loader, `path_is_under`. |
| `policy_helpers.odin` | The `proc "c"` shims registering `h2o.str.*` / `h2o.naming.*` / macro-view methods into the VM. |
| `policy_lua.odin` | Generic Lua↔Odin marshalling: string/table/map/list readers, `push_*` helpers, key validation utilities. |
| `policy_sections.odin` | The per-section config readers (`policy_read_naming`, `_types`, `_symbols`, `_macros`, `_enums`, `_structs`, `_procs`, `_foreign`, `_output`, `_diagnostics`, `_preprocess`, …). May split again along section lines if it stays large. |
| `policy_callbacks.odin` | Runtime callback dispatch consulted by Transformation: `policy_rename`, `policy_remove_where`, `policy_macro_include`, `policy_enum_member_remove`, member-action callbacks, and the view pushers (`push_symbol_table`, `push_macro_view`). |

The invariant is untouched by the split: algorithms live in pure modules
(`naming.odin`, `str.odin`); the policy files only marshal and register.

### `transform.odin` — done

Each pass gets a file, aligned with the config section it serves:

| File | Scope |
|------|-------|
| `transform.odin` | `Type_Mode`, the `transform` pass order — nothing else. |
| `transform_types.odin` | Pointer lowering, idiomatic leaf substitution (the three-rung ladder), guess reporting. |
| `transform_naming.odin` | `apply_renames`, affix stripping, keyword safety, `link_name` logic. |
| `transform_symbols.odin` | `filter_declarations`, `apply_type_rewrites` (map/overrides). |
| `transform_macros.odin` | `apply_macro_groups`. |
| `transform_enums.odin` | Anonymous-enum naming, member policy, `bit_set` transform. |
| `transform_members.odin` | `structs.fields` / `structs.field` / `structs.align`, `procs.params` / `.results` adjustments. |

### `extract.odin` — done

| File | Scope |
|------|-------|
| `extract.odin` | TU orchestration: clang args, parse-diagnostics gate, resource-dir lookup, `clone_clang_string`, top-level visitor. |
| `extract_decls.odin` | Per-declaration extraction: funcs, vars, macros, and the record/enum/typedef get-or-create + fill visitors. |
| `extract_types.odin` | `capture_type` and friends: builtin mapping, measured size/signedness, param decay. |

### `emit.odin` — done

| File | Scope |
|------|-------|
| `emit.odin` | `Emit_Options`, output assembly, prelude, foreign-block plumbing. |
| `emit_decls.odin` | Per-declaration emitters (record, enum, typedef, var, func, macro, bit_set) and doc/indent helpers. |
| `emit_types.odin` | `write_type`, `write_params`, spelling dispatch. |
| `emit_bit_field.odin` | Bit-field run grouping and the layout proof — the one decision-adjacent computation in Emission, kept visibly separate. |
