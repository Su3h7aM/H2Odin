# Official Odin evidence for vendor-binding parity

Date: 2026-07-11

## Scope and source baseline

This note records primary-source evidence only. It does not prescribe an H2Odin architecture or an implementation plan.

The local Odin installation inspected was:

- compiler: `dev-2026-07-nightly:819fdc7`
- mise package: `dev-2026-07a`
- local Odin root used below: `/home/su3h7am/.local/share/mise/installs/odin/dev-2026-07a/bin`

The local evidence consists of the shipped `base`, `core`, and `vendor` source trees and the C headers/sources vendored alongside the bindings. The online evidence is restricted to official `odin-lang.org` documentation.

The five package bindings examined in detail are:

- `vendor/raylib`
- `vendor/box3d`
- `vendor/cgltf`
- `vendor/curl`
- `vendor/miniaudio`

## Language-level foreign-system facts

### Foreign imports, blocks, and linkage names

Odin's official Binding to C article states that a binding has two parts: `foreign import` selects a library to link, and a `foreign` block declares exported functions and variables. A foreign procedure declaration ends in `---` because its body exists elsewhere. By default, the Odin declaration name is also the linked symbol name; `@(link_name=...)` and `@(link_prefix=...)` can change that mapping. Sources: [Binding to C — example and foreign blocks](https://odin-lang.org/news/binding-to-c/#foreign-blocks), and [Overview — foreign system](https://odin-lang.org/docs/overview/#foreign-system).

`@(link_prefix="ltb_")` on a foreign block makes a declaration such as `testbar` refer to the external symbol `ltb_testbar`; the attribute changes linkage naming, not the Odin-side procedure signature. Source: [Overview — `@(link_prefix)`](https://odin-lang.org/docs/overview/#link-prefixstring).

The official docs distinguish local library paths from `system:` library names and note platform differences in shared-library and import-library naming. Source: [Binding to C — static vs shared libraries](https://odin-lang.org/news/binding-to-c/#static-vs-shared-libraries).

### Calling conventions

The default calling convention for an ordinary Odin procedure is `"odin"`; the default inside a `foreign` block is C/cdecl. Procedure types are compatible only when their calling convention and parameter types match. Sources: [Overview — procedure calling conventions](https://odin-lang.org/docs/overview/#calling-conventions), and [Binding to C — calling conventions](https://odin-lang.org/news/binding-to-c/#calling-conventions).

The `"odin"` convention has an implicit context pointer and may pass large values by reference. The official overview describes `"c"`/`"cdecl"` as C's default convention and `"system"` as the target system convention. These differences make the convention part of an ABI-facing procedure type. Source: [Overview — procedure calling conventions](https://odin-lang.org/docs/overview/#calling-conventions).

`@(default_calling_convention="c")` on a foreign block is therefore explicit documentation of a default that is already C/cdecl for foreign declarations. It becomes functionally relevant when set to another convention. Source: [Overview — `@(default_calling_convention)`](https://odin-lang.org/docs/overview/#default-calling-conventionstring).

### `#by_ptr`

The official overview defines `#by_ptr` as the foreign-procedure representation of a C const-reference parameter: `bar :: proc(#by_ptr p: T) ---` represents `void bar(const T*)`. The parameter is passed by pointer internally while retaining a value-shaped Odin parameter. Source: [Overview — `#by_ptr`](https://odin-lang.org/docs/overview/#by-ptr).

This is ABI-facing because it controls how the parameter is passed. It is also call-site ergonomic because the Odin declaration names the parameter as `T`, not `^T`. The documentation specifically describes the `const T *` case; it does not describe `#by_ptr` as a general replacement for mutable `T *` or pointer-plus-count parameters.

### `#type`

The official overview says `#type` has no functional purpose in the compiler. It tells a reader that an expression is a type, especially that a bodyless procedure signature is intentional. Source: [Overview — `#type`](https://odin-lang.org/docs/overview/#type).

Consequently, `Callback :: proc "c" (...)` and `Callback :: #type proc "c" (...)` can both denote procedure types; the `#type` marker itself is neither an ABI annotation nor a calling-convention annotation.

### `@(require_results)`

`@(require_results)` requires callers to acknowledge a procedure's return values, either by storing them or explicitly assigning them to `_`. It may be attached to a procedure or a foreign block. Sources: [Overview — `@(require_results)`](https://odin-lang.org/docs/overview/#require-results), and [Overview — foreign block attributes](https://odin-lang.org/docs/overview/#foreign-system).

This changes compile-time use-site checking. It does not change the external symbol, parameter layout, result layout, or calling convention.

### Pointer, multi-pointer, and slice facts

`^T` is a pointer to one `T`; it supports dereference and has no pointer arithmetic. Source: [Overview — pointers](https://odin-lang.org/docs/overview/#pointers).

`[^]T` is a multi-pointer intended for foreign C-like pointers that act as arrays. It supports unchecked indexing and slicing, permits conversions with `^T`, and cannot itself be dereferenced. The official docs describe its purpose as documenting foreign array-like pointers and easing conversion to slices. Source: [Overview — multi-pointers](https://odin-lang.org/docs/overview/#multi-pointers).

`[]T` is a two-field descriptor containing a data pointer and an integer length. It is not merely a C `T *`. Sources: [Overview — slices](https://odin-lang.org/docs/overview/#slices), and [Overview — parameter passing](https://odin-lang.org/docs/overview/#procedure-parameters).

The official vendor packages consistently show the resulting distinctions:

- single objects, opaque handles, linked-list links, and output pointers use `^T` or repeated pointers such as `^^T`;
- array/buffer pointers whose length is separate or externally known use `[^]T`;
- slices appear where the Odin value itself is intended to carry pointer and length, including ABI-compatible record overlays and Odin-side helper procedures.

Examples are listed package by package below.

### `string` and `cstring`

The official overview defines `cstring` as a zero-terminated C string equivalent to `char const *`. Converting `cstring` to `string` aliases the data, while converting a nonconstant `string` to `cstring` normally requires a copy; an explicitly named unsafe conversion aliases. Sources: [Overview — `cstring`](https://odin-lang.org/docs/overview/#cstring-type), and [Overview — string conversions](https://odin-lang.org/docs/overview/#string-type-conversions).

The vendor tree uses `cstring` predominantly for C textual parameters and fields. It uses `[^]byte` for mutable character buffers and for C byte pointers that are not semantically a zero-terminated immutable string. A plain Odin `string` appears in ABI records only where it overlays a C pointer-plus-length pair, as in `cgltf_data.json`.

### Callbacks

A procedure type is internally a procedure pointer and has `nil` as its zero value. Procedure-type compatibility includes the calling convention. Source: [Overview — procedure type](https://odin-lang.org/docs/overview/#procedure-type).

The examined C callbacks are therefore declared as `proc "c" (...)` in every package. Whether `#type` is present is stylistic/readability metadata; whether `"c"` is present is part of the callback type.

### `bit_set`

The official overview defines `bit_set` as a bit-vector set over an enum or range and permits an explicit backing integer type. It specifically notes use for flags and shows that `bit_set[E; u64]` has the size of `u64`. Source: [Overview — bit sets](https://odin-lang.org/docs/overview/#bit-sets).

The vendor bindings represent C masks by declaring enum members as bit positions and a `bit_set` with the C mask's backing width. For example, miniaudio's C `MA_DATA_FORMAT_FLAG_EXCLUSIVE_MODE` is `(1U << 1)` at `vendor/miniaudio/src/miniaudio.h:7079`; the Odin binding declares `EXCLUSIVE_MODE = 1` and `data_format_flags :: bit_set[data_format_flag; u32]` at `vendor/miniaudio/device_io_types.odin:354-358`. Curl's WebSocket flags similarly use enum positions `0` through `6` with `ws_flags :: distinct bit_set[ws_flag; c.uint]` at `vendor/curl/curl_websockets.odin:14-30`.

The explicit backing type is the layout-bearing part. The set notation and named bit-position enum provide Odin-side typed flag operations.

## Direct ABI obligations evidenced by the vendor tree

The following items directly affect whether Odin code can link to and call the C library or interpret C-owned memory correctly:

1. **Platform-appropriate foreign imports.** Each package chooses local archives/import libraries, shared libraries, system libraries, frameworks, or WebAssembly objects according to `ODIN_OS`, `ODIN_ARCH`, and package configuration.
2. **External symbol mapping.** Prefixes such as `b3`, `cgltf_`, `curl_`, `ma_`, and `rl` are represented with `@(link_prefix=...)`, or names are preserved directly.
3. **Calling conventions.** Foreign procedures and C callbacks use the C convention.
4. **Scalar widths and signedness.** Bindings use `c.int`, `c.uint`, `c.long`, `c.size_t`, exact-width integers, and explicitly based enums rather than substituting Odin `int` indiscriminately.
5. **Record layout.** Fixed arrays, explicit alignment, raw unions, pointer fields, count fields, and flag backing types track C layout.
6. **Pointer indirection and role.** `^T`, `^^T`, `^^^T`, `[^]T`, `rawptr`, `cstring`, and `#by_ptr T` are used for distinct C pointer shapes.
7. **Header-only C API surface.** C `static inline` functions and macro-like utilities have no external symbol to import; when present in the Odin package, they are Odin procedure bodies or constants.

`#type` and `@(require_results)` are excluded from this list by the official language documentation: the first is nonfunctional reader metadata, and the second is a compile-time result-use rule.

## Package evidence

### `vendor:raylib`

#### ABI-facing declarations

`vendor/raylib/raylib.odin:108-160` selects different import sets for Windows, Linux amd64/arm64, Darwin, WebAssembly, and an unsupported-platform `system:raylib` fallback. The local/static/shared choice is controlled by `RAYLIB_SHARED`; platform dependencies include Windows system libraries, Linux `dl`, `pthread`, and X11, and Darwin Cocoa/OpenGL/IOKit frameworks.

The inspected snapshot contains an exact path inconsistency in the Linux arm64 static branch: `vendor/raylib/raylib.odin:118` refers to `linux-arm/libraylib.a`, while the shipped directory is `vendor/raylib/linux-arm64/` and contains `libraylib.a`; no `vendor/raylib/linux-arm/` directory is present. The shared arm64 path on the same line uses `linux-arm64/libraylib.so.600`.

The main API is in a `@(default_calling_convention="c") foreign lib` block beginning at `vendor/raylib/raylib.odin:932-933`. The declarations preserve the upstream PascalCase names instead of applying a link prefix.

Array-like C pointers use multi-pointers. Examples include mesh vertex arrays at `vendor/raylib/raylib.odin:306-326`, `SetWindowIcons(images: [^]Image, count: c.int)` at line 964, file data at lines 1100-1105, codepoint arrays at lines 1507-1513, and model animation arrays at lines 1670-1673. A single mutable image is `^Image`, for example image drawing procedures around lines 1420-1447.

Textual inputs and returned static strings generally use `cstring`, including `InitWindow` at line 945, monitor/clipboard functions at lines 988-990, file paths at lines 1082-1141, and text APIs around lines 1520-1579. Mutable text buffers and allocated byte text use `[^]byte`, for example `LoadFileText` at line 1104 and `TextAppend` at line 1571.

Callback types are marked with both `#type` and `proc "c"` at `vendor/raylib/raylib.odin:923-929`. The callbacks use `cstring`, `rawptr`, `^c.va_list`, and `[^]u8` according to the C role of each argument.

Flag masks use explicitly backed sets: `ConfigFlags :: distinct bit_set[ConfigFlag; c.int]` at lines 507-525 and `Gestures :: distinct bit_set[Gesture; c.uint]` at lines 873-885. `IsWindowState`, `SetWindowState`, and `ClearWindowState` accept `ConfigFlags` directly at lines 954-956.

Record layout includes `Model :: struct #align(align_of(uintptr))` at line 373 and `VrStereoConfig :: struct #align(4)` at line 470. `Color` is a distinct four-byte array at line 207.

#### Odin-side wrappers and helpers

`IsGestureDetected` at `vendor/raylib/raylib.odin:1777-1782` is an adapter: the public procedure accepts one `Gesture`, while a nested private foreign declaration calls the C symbol with `Gestures`, constructing a one-element bit set. It changes the public call shape while retaining a direct C call internally.

`TextFormat` at lines 1786-1798 is an Odin implementation using `core:fmt`, four static buffers, and explicit zero termination. It does not call raylib's C varargs symbol. `TextFormatAlloc` at lines 1802-1804 formats through an Odin allocator backed by raylib allocation functions.

`MemFree` at lines 1808-1822 is an overload group for `rawptr` and `cstring`. `MemAllocator`/`MemAllocatorProc` at lines 1825 onward adapt raylib's `MemAlloc`/`MemFree` functions to Odin's `mem.Allocator` interface.

`vendor/raylib/raymath.odin` is an Odin port of the header-style raymath API, not a foreign block. Its value-returning procedures carry `@(require_results)`, and many operations are marked deprecated in favor of Odin operators or `core:math/linalg`; examples are `Vector2Add` at lines 68-71, `Vector3Multiply` at lines 329-332, and `MatrixMultiply` at lines 590-594. `@(require_results)` here is a use-site rule on Odin helper procedures, not an ABI mechanism.

`vendor/raylib/easings.odin` likewise contains Odin procedure bodies for easing functions. `vendor/raylib/raymath.odin` and `vendor/raylib/easings.odin` therefore demonstrate source-level/header-only API ports alongside the foreign ABI declarations.

### `vendor:box3d`

#### ABI-facing declarations

`vendor/box3d/box3d.odin:10-38` selects local Windows, Linux amd64, Linux arm64, and Darwin libraries, with `system:box3d` as the final fallback. The imports are marked `@(export)`.

In the inspected installation, `vendor/box3d/lib/` contains `darwin/libbox3d.a` and `linux-amd64/libbox3d.a`; the Windows and Linux arm64 paths referenced by the source are not present in this local installation.

Foreign blocks use `@(link_prefix="b3", default_calling_convention="c", require_results)`, for example at `vendor/box3d/box3d.odin:60` and `:95`, and the main world API block at line 206. This maps an Odin declaration such as `CreateWorld` to `b3CreateWorld`, gives the procedures the C convention, and requires callers to acknowledge all results in those blocks.

Box3D is the strongest example of `#by_ptr` in the examined set. The C header declares const object pointers, such as `b3CreateMesh(const b3MeshDef*, ...)` and `b3GetHeight(const b3MeshData*)`; the Odin declarations use `#by_ptr def: MeshDef` and `#by_ptr mesh: MeshData` at `vendor/box3d/box3d_collision.odin:201` and `:207`. Similar mappings occur throughout world, body, shape, joint, collision, and recording declarations.

Mutable pointers remain explicit pointers. For example, C constructors that receive mutable shape data are represented as `sphere: ^Sphere`, `capsule: ^Capsule`, and `hull: ^HullData` at `vendor/box3d/box3d.odin:908-924`; output arrays plus capacity use `[^]T` and `c.int`, such as body shapes, joints, and contacts at lines 862-875.

C callbacks are procedure types with the C convention. Examples include allocation/assert/log callbacks at `vendor/box3d/box3d.odin:45-55`, world query callbacks at `vendor/box3d/box3d_types.odin:65-107`, tree callbacks at lines 1728-1746, and mover/plane callbacks at lines 1802-1806. These declarations usually omit `#type`, confirming that `#type` is not required for a procedure type.

Box3D C `_Bool`/`stdbool.h` values are represented as Odin `bool`; the C source includes `<stdbool.h>` at `vendor/box3d/src/include/box3d/box3d.h:12`, and corresponding Odin functions return `bool`, for example `World_IsValid` at `vendor/box3d/box3d.odin:223`.

#### Header-inline ports and helpers

The upstream Box3D headers contain many `B3_INLINE` functions. `B3_INLINE` is `inline` or `static inline` depending on build mode at `vendor/box3d/src/include/box3d/base.h:40-54`. The math header lists inline scalar, vector, quaternion, transform, matrix, and AABB procedures from `vendor/box3d/src/include/box3d/math_functions.h:141` through `:1050`.

The Odin package ports these as procedure bodies in `vendor/box3d/box3d_math.odin`. Examples include `Normalize` at line 193, quaternion operations at lines 283-420, transform operations at lines 420-563, and AABB operations at lines 648-741. These are not foreign symbol declarations.

`MakeAABB` at `vendor/box3d/box3d_math.odin:648` changes the C inline signature `(const b3Vec3 *points, int count, float radius)` from `vendor/box3d/src/include/box3d/math_functions.h:953` into `(points: []Vec3, radius: f32)`. The Odin helper derives the count from the slice. This is a source-level ergonomic call-shape change, not a foreign ABI declaration.

The collision header's offset accessors are also `B3_INLINE`, including `b3DynamicTree_GetUserData`, `b3GetHullVertices`, `b3GetMeshMaterialIndices`, and height-field accessors at `vendor/box3d/src/include/box3d/collision.h:115-366`. Their Odin bodies are at `vendor/box3d/box3d_collision.odin:475-615`; they perform field access or pointer arithmetic locally and return `Maybe(^T)` or multi-pointers where offsets may be zero.

`ASSERT` and `VALIDATE` at `vendor/box3d/box3d.odin:127-141` are Odin helpers around `InternalAssert`. They use `#caller_expression`, `#caller_location`, compile-time disabling, and a cold nested procedure. Those facilities do not correspond to a C ABI signature.

### `vendor:cgltf`

#### ABI-facing declarations and record overlays

`vendor/cgltf/cgltf.odin:4-26` selects local Windows, Linux, Darwin, and WebAssembly objects, with `system:cgltf` as fallback.

In the inspected installation, `vendor/cgltf/lib/` contains only `cgltf_wasm.o`; the source tree also includes build inputs under `vendor/cgltf/src/`. The local Windows, Linux, and Darwin archive paths named by `LIB` are not present in this installation.

The foreign block at lines 683-768 uses `@(default_calling_convention="c")` and `@(link_prefix="cgltf_")`. Individual result-bearing declarations carry `@(require_results)`.

The C header defines `cgltf_size` as `size_t`, `cgltf_float` as `float`, and `cgltf_bool` as `int` at `vendor/cgltf/src/cgltf.h:104-109`. The Odin binding uses `uint`, `f32`, and `b32`, respectively. C enums use Odin enums with `c.int` backing beginning at `vendor/cgltf/cgltf.odin:31`.

Callback fields in `memory_options` and `file_options` use `proc "c"` at `vendor/cgltf/cgltf.odin:50-60`; const object pointers remain `^T` in callback fields, with comments retaining the source constness.

The binding overlays many adjacent C pointer/count field pairs with Odin slices. For example, C `cgltf_primitive` has `attributes` followed by `attributes_count`, `targets` followed by `targets_count`, and `mappings` followed by `mappings_count` at `vendor/cgltf/src/cgltf.h:576-590`; Odin uses `[]attribute`, `[]morph_target`, and `[]material_mapping` at `vendor/cgltf/cgltf.odin:457-469`. C `cgltf_data` has repeated pointer/count pairs at `vendor/cgltf/src/cgltf.h:740-812`; Odin uses slices for meshes through scenes, animations, variants, extension-name arrays, `json`, and `bin` at `vendor/cgltf/cgltf.odin:605-646`.

Pairs not converted to slices remain separate fields, notably `extensions_count: uint` followed by `extensions: [^]extension`, throughout the binding. Those pointers carry `fmt` tags naming the associated count, for example `vendor/cgltf/cgltf.odin:177-178` and `:435-436`.

The record overlay is layout-sensitive: the official docs define an Odin slice as pointer plus integer length, while the C header uses pointer followed by `cgltf_size`; here `cgltf_size` is `size_t` and the Odin binding maps it to `uint`.

Const pointer parameters on foreign calls use `#by_ptr options: options`, for example `load_buffers` at `vendor/cgltf/cgltf.odin:687-690` and `write_file` at lines 765-768. Mutable buffers use `[^]byte`.

#### Output-parameter wrappers

`parse`, `parse_file`, and `load_buffer_base64` at `vendor/cgltf/cgltf.odin:649-680` are Odin procedure bodies with the C calling convention. Each declares the original C symbol privately in a nested foreign block, supplies the address of an Odin named result to the C output parameter, and returns `(output, result)` in Odin.

The corresponding C signatures return `cgltf_result` and take `cgltf_data **out_data` or `void **out_data` at `vendor/cgltf/src/cgltf.h:815-831`. The wrappers therefore change the public result shape while preserving the underlying C call.

### `vendor:curl`

#### ABI-facing declarations

`vendor/curl/curl.odin:5-32` selects a Windows import library plus Windows system dependencies, Darwin's system curl/z/SystemConfiguration framework, or system curl plus mbedTLS and zlib on other targets.

Curl declarations are organized across multiple files and foreign blocks with `@(default_calling_convention="c", link_prefix="curl_")`; examples begin at `vendor/curl/curl_easy.odin:21`, `vendor/curl/curl_multi.odin:65`, `vendor/curl/curl_urlapi.odin:100`, and `vendor/curl/curl.odin:2198`.

Opaque C types are empty structs used behind pointers, such as `CURL`, `CURLSH`, `mime`, and `mimepart` at `vendor/curl/curl.odin:90-91` and `:2190-2191`. Pointer depth is preserved for output and array-of-pointer APIs, including `^^slist` in `trailer_callback` at line 401, `^^^ssl_backend` in `global_sslset` at line 2493, and `[^]^CURL` from `multi_get_handles` at `vendor/curl/curl_multi.odin:413`.

Array/buffer callback arguments use multi-pointers plus C sizes, such as `write_callback` at `vendor/curl/curl.odin:249-252`, `read_callback` at lines 396-399, and `formget_callback` at line 2328. Null-terminated text uses `cstring`, while `slist.data` is `[^]byte` at line 85, reflecting a mutable C `char *` field.

Callback types consistently use `#type proc "c"`, including progress callbacks at lines 199-215, write/read callbacks at lines 249 and 396, allocator callbacks at lines 461-465, and multi callbacks at `vendor/curl/curl_multi.odin:241-262`.

Curl flag masks use explicitly backed `distinct bit_set` types, including `httppost_flags` at `vendor/curl/curl.odin:131`, `blob_flags` at `vendor/curl/curl_easy.odin:9`, `ws_flags` at `vendor/curl/curl_websockets.odin:14`, and URL flags at `vendor/curl/curl_urlapi.odin:57`.

Variadic C APIs remain direct foreign declarations with `#c_vararg`, including `easy_setopt` and `easy_getinfo` at `vendor/curl/curl_easy.odin:24-43`.

#### Wrapper/helper observation

No Odin procedure bodies were found in `vendor/curl/*.odin`. The examined curl package exposes direct foreign declarations, constants, types, and callback types; it does not reshape output parameters, provide allocator adapters, or replace the C variadic APIs with Odin formatting helpers.

### `vendor:miniaudio`

#### ABI-facing declarations

`vendor/miniaudio/common.odin:5-19` rejects shared linking, selects `lib/miniaudio.lib` on Windows and `lib/miniaudio.a` elsewhere, verifies that the archive exists, and imports it as `lib`. Each binding file imports the same library and declares one or more foreign blocks.

The inspected installation has no `vendor/miniaudio/lib/` directory. The source's missing-library branch emits a compile-time panic directing the user to build the library from `vendor/miniaudio/src`.

Foreign blocks use `@(default_calling_convention="c", link_prefix="ma_")` throughout, for example `vendor/miniaudio/common.odin:323`, `vendor/miniaudio/device_io_procs.odin:7`, and `vendor/miniaudio/engine.odin:86`.

The package is layout-heavy. C unions are represented by `struct #raw_union`, including notification payloads and device identifiers at `vendor/miniaudio/device_io_types.odin:93-105` and `:327-350`, decoder state at `vendor/miniaudio/decoding.odin:76`, and resource-manager variants at `vendor/miniaudio/resource_manager.odin:96-177`.

Array and buffer pointers use `[^]T`, including channel maps at `vendor/miniaudio/device_io_types.odin:397-406`, device-info arrays at line 639, context backend arrays and device outputs at `vendor/miniaudio/device_io_procs.odin:251` and `:421`, and engine frame buffers at `vendor/miniaudio/engine.odin:318`.

Null-terminated paths and names use `cstring`, including engine file paths at `vendor/miniaudio/engine.odin:103` and `:165`, backend names at `vendor/miniaudio/device_io_procs.odin:1589-1594`, and result/version strings at `vendor/miniaudio/common.odin:326-397`. Wide C strings use `[^]c.wchar_t`, for example `vendor/miniaudio/engine.odin:104` and `:166`.

C callbacks use `proc "c"`. Most callback declarations omit `#type`, for example VFS callbacks at `vendor/miniaudio/vfs.odin:52-54`, device callbacks at `vendor/miniaudio/device_io_types.odin:149-212`, and logging at `vendor/miniaudio/logging.odin:34`. Two engine callbacks include the optional marker at `vendor/miniaudio/engine.odin:100` and `:318`.

Flags use bit-position enums plus `bit_set` with `u32` backing. Examples include `open_mode_flags` at `vendor/miniaudio/vfs.odin:19-24`, `data_format_flags` at `vendor/miniaudio/device_io_types.odin:354-358`, and `sound_flags` at `vendor/miniaudio/engine.odin:14-29`. The corresponding C definitions include `MA_OPEN_MODE_READ = 0x1`, `MA_OPEN_MODE_WRITE = 0x2` at `vendor/miniaudio/src/miniaudio.h:9880-9881` and sound/data-format masks in the same header.

#### Helper observation

The package initializer `version_check` at `vendor/miniaudio/common.odin:27-48`
calls `ma_version`, compares it with the binding's `0.11.24` constants,
constructs a diagnostic without an Odin context, and calls
`panic_contextless` on mismatch.

Three small Odin helper bodies were also found:
`get_bytes_per_frame` at `vendor/miniaudio/common.odin:400` and the two typed
pointer-offset adapters at `vendor/miniaudio/utilities.odin:112-118`. They
perform arithmetic or forward to an existing foreign declaration. No
output-parameter reshaping or slice-taking public wrapper procedures were
observed.

## Cross-package wrapper/helper patterns

The official vendor tree exhibits several distinct patterns rather than one uniform wrapper policy:

| Pattern | Observed packages | ABI status evidenced by source |
|---|---|---|
| Direct foreign declaration with C-shaped arguments/results | all five | Calls an external symbol; ABI-facing |
| `link_prefix` instead of repeating C symbol prefixes | box3d, cgltf, curl, miniaudio; rlgl subpackage | Link-name mapping; ABI/linkage-facing |
| `#by_ptr T` for C `const T *` | box3d, cgltf | Controls foreign parameter passing; ABI-facing with a value-shaped Odin call site |
| `proc "c"` callback types | all five | Calling convention is part of procedure-type compatibility |
| Optional `#type` on callback aliases | raylib, curl, two miniaudio callbacks | Reader metadata only; no compiler function |
| `@(require_results)` | box3d foreign blocks, cgltf result procedures, raymath helpers | Compile-time result-use enforcement; no ABI change |
| `[^]T` plus separate count/capacity | all five | C array/buffer pointer representation |
| `[]T` replacing adjacent pointer/count record fields | cgltf | Layout-sensitive record overlay and Odin indexing/length ergonomics |
| `[]T` replacing pointer/count in an Odin helper signature | box3d `MakeAABB` | Odin-side call-shape helper; not a foreign declaration |
| Out-parameter converted to multiple Odin results | cgltf | Odin wrapper around a private C-shaped declaration |
| Header `static inline` functions ported to Odin bodies | box3d, raylib raymath/easings | No external C symbol exists; source-level API port |
| Variadic C API replaced by Odin variadics/formatting | raylib `TextFormat` | Odin helper implementation; does not call the C varargs symbol |
| Variadic C API retained with `#c_vararg` | curl | Direct foreign ABI declaration |
| C allocator adapted to `mem.Allocator` | raylib | Odin interface helper over C allocation symbols |
| Package/library version check at initialization | miniaudio | Odin runtime guard; not part of a C declaration |
| Assertion helpers using caller expression/location | box3d | Odin diagnostic helper over a C assertion hook |

## Factual limits of the evidence

- The official vendor packages are hand-maintained package-specific bindings. Their differing use of `#type`, `@(require_results)`, wrappers, naming, and slices demonstrates that these are not uniformly applied across the vendor tree.
- The official language documentation assigns ABI meaning to foreign declarations, link names, calling conventions, and `#by_ptr`; it explicitly assigns no compiler function to `#type` and describes `@(require_results)` as result-use checking.
- The official docs define `[]T` as pointer plus length and `[^]T` as the foreign array-like pointer. The examined direct foreign procedure declarations use `[^]T` plus an explicit C count for C pointer-plus-count parameters. The observed uses of `[]T` are record overlays or Odin procedure bodies.
- The vendor sources distinguish immutable zero-terminated text (`cstring`), mutable/byte-oriented C pointers (`[^]byte` or `rawptr`), and pointer-plus-length text (`string` only in a layout overlay such as cgltf).
- Header-only ports, output-parameter wrappers, allocator adapters, formatting helpers, and runtime version checks are all present in official packages, but not in every package. Their presence is package-specific evidence, not an official language requirement that every binding contain wrappers.
