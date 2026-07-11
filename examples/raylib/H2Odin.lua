-- Validation benchmark: generate raylib bindings and compare against
-- Odin's hand-written vendor:raylib (raylib v6.0).
--
-- Target style (vendor/raylib/raylib.odin):
--   - package raylib
--   - Keep C PascalCase names (InitWindow, Vector2, …) — no snake_case
--   - Idiomatic leaf types (f32, i32, …) where proven
--   - Vector2/3/4 as arrays; Color as distinct [4]u8; Quaternion as
--     quaternion128; Matrix as #row_major matrix[4,4]f32
--
-- Known gaps vs the hand binding (documented in README.md): multi-lib
-- foreign import, pre-filled Color palette constants, #by_ptr / default
-- calling convention, and some pointer lowerings that need manual overrides.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "raylib"
config.type_mode = "idiomatic"
config.inputs = { "raylib.h" }
config.output_folder = "."
config.foreign.import_lib = "raylib"

-- Raylib C already uses Odin-friendly PascalCase for procs and types.
-- Do not recase; only keyword-escape via the generator default.

-- Match vendor:raylib's idiomatic shape overrides (ABI-compatible on
-- little-endian: same size/layout as the C structs of floats/bytes).
config.types.overrides = {
	Vector2 = "[2]f32",
	Vector3 = "[3]f32",
	Vector4 = "[4]f32",
	Quaternion = "quaternion128",
	Matrix = "#row_major matrix[4, 4]f32",
	Color = "distinct [4]u8",
}

-- Many raylib out-params are write destinations; default ^T is correct.
-- const char* is already proven to cstring by Analysis. Further multipointer
-- polish belongs in config.procs / config.structs as the benchmark matures.

return config
