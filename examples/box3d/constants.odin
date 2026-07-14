package box3d

foreign import lib "system:box3d"

MAX_WORKERS :: 32
MAX_TASKS :: 256
GRAPH_COLOR_COUNT :: 24
CONTACT_MANIFOLD_COUNT_BUCKETS :: 8
MAX_WORLDS :: 128
MAX_MANIFOLD_POINTS :: 4
MAX_SHAPE_CAST_POINTS :: 64
SHAPE_POWER :: 22
@(link_prefix = "b3")
foreign lib {
	/// Box3D bases all length units on meters, but you may need different units for your game.
	/// You can set this value to use different units. This should be done at application startup
	/// and only modified once. Default value is 1.
	/// @warning This must be modified before any calls to Box3D
	SetLengthUnitsPerMeter :: proc(lengthUnits: f32) ---
	/// Get the current length units per meter.
	GetLengthUnitsPerMeter :: proc() -> f32 ---
	/// Set the threshold for logging stalls.
	SetStallThreshold :: proc(seconds: f32) ---
	/// Get the threshold for logging stalls.
	GetStallThreshold :: proc() -> f32 ---
}
