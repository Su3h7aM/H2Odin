-- Validation benchmark: generate Box3D bindings and compare against
-- Odin's hand-written vendor:box3d.
--
-- Target style (vendor/box3d/*.odin):
--   - package box3d (hand binding uses vendor_box3d)
--   - foreign.link_prefix = "b3" + strip b3 from Odin names
--     (b3CreateWorld → CreateWorld, b3WorldId → WorldId)
--   - Vec2/Vec3 as [2]f32/[3]f32; keep ID structs as structs
--   - Idiomatic leaves (f32, u16, …)
--
-- Multi-header input with merged layout (one box3d.odin). Official binding
-- is split by topic (types / math / collision / …); we generate one file and
-- note the layout difference in README.md.

local h2o = require "h2odin"

local config = h2o.config()
config.package = "box3d"
config.type_mode = "idiomatic"

-- Umbrella header pulls base, types, id, math, collision.
config.inputs = { "include/box3d/box3d.h" }
config.preprocess.include_paths = { "include" }
config.output_folder = "."
config.output.layout = "merged"

config.foreign.import_lib = "box3d"
config.foreign.link_prefix = "b3"

config.naming = {
	strip_prefixes = {
		proc = "b3",
		type = "b3",
		const = "B3_",
		enum_value = "b3",
	},
	-- Official binding keeps PascalCase after the b3 strip (CreateWorld,
	-- WorldId, DynamicTree_Create). Do not snake_case.
}

-- Match vendor math aliases where ABI-identical.
config.types.overrides = {
	b3Vec2 = "[2]f32",
	b3Vec3 = "[3]f32",
	-- b3Quat is { Vec3 v; float s } in C (16 bytes). Official uses
	-- quaternion128 (also 16 bytes, different component order/layout —
	-- only override when we accept that as intentional). Leave as struct
	-- for ABI fidelity; document the hand binding's quaternion128 choice.
	b3Pos = "[3]f32", -- float precision path (no BOX3D_DOUBLE_PRECISION)
}

-- Math headers expose many static inlines (skipped: no external symbol).
-- Object-like B3_* macros remain as constants.

-- Faithful-surface curation matching vendor:box3d's #by_ptr call-borrowed
-- shape/world defs. Idiomatic-only for by_ptr. Keys are C names from the
-- configured input surface (box3d.h umbrella). collision.h helpers such as
-- b3CreateMesh are transitive only and are not "ours".
config.procs.params = {
	["b3CreateWorld.def"] = { by_ptr = true },
	["b3CreateSphereShape.def"] = { by_ptr = true },
	["b3CreateSphereShape.sphere"] = { by_ptr = true },
	["b3CreateCapsuleShape.def"] = { by_ptr = true },
	["b3CreateCapsuleShape.capsule"] = { by_ptr = true },
	["b3CreateHullShape.def"] = { by_ptr = true },
	["b3CreateMeshShape.def"] = { by_ptr = true },
}
-- Create* factories return handle IDs that callers must keep; b3DefaultWorldDef
-- is a static inline and is not emitted as a foreign symbol.
config.procs.require_results = {
	"b3CreateWorld",
	"b3CreateSphereShape",
	"b3CreateCapsuleShape",
	"b3CreateHullShape",
	"b3CreateMeshShape",
}

return config
