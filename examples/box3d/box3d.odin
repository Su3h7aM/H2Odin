package box3d

foreign import lib "system:box3d"

/// World id references a world instance. This should be treated as an opaque handle.
WorldId :: struct {
	index1: u16,
	generation: u16,
}

/// World definition used to create a simulation world. Must be initialized using b3DefaultWorldDef.
/// @ingroup world
WorldDef :: struct {
	/// Gravity vector. Box3D has no up-vector defined.
	gravity: Vec3,
	/// Restitution speed threshold, usually in m/s. Collisions above this
		/// speed have restitution applied (will bounce).
	restitutionThreshold: f32,
	/// Hit event speed threshold, usually in m/s. Collisions above this
		/// speed can generate hit events if the shape also enables hit events.
	hitEventThreshold: f32,
	/// Contact stiffness. Cycles per second. Increasing this increases the speed of overlap recovery, but can introduce jitter.
	contactHertz: f32,
	/// Contact bounciness. Non-dimensional. You can speed up overlap recovery by decreasing this with
		/// the trade-off that overlap resolution becomes more energetic.
	contactDampingRatio: f32,
	/// This parameter controls how fast overlap is resolved and usually has units of meters per second. This only
		/// puts a cap on the resolution speed. The resolution speed is increased by increasing the hertz and/or
		/// decreasing the damping ratio.
	contactSpeed: f32,
	/// Maximum linear speed. Usually meters per second.
	maximumLinearSpeed: f32,
	/// Optional mixing callback for friction. The default uses sqrt(frictionA * frictionB).
	frictionCallback: ^FrictionCallback,
	/// Optional mixing callback for restitution. The default uses max(restitutionA, restitutionB).
	restitutionCallback: ^RestitutionCallback,
	/// Can bodies go to sleep to improve performance
	enableSleep: bool,
	/// Enable continuous collision
	enableContinuous: bool,
	/// Number of workers to use with the provided task system. Box3D performs best when using only
		/// performance cores and accessing a single L2 cache. Efficiency cores and hyper-threading provide
		/// little benefit and may even harm performance.
		/// This is clamped to the range [1, B3_MAX_WORKERS]. Using a value above 1 will turn on multithreading.
		/// If task callbacks are provided then Box3D will use the user provided task system. Otherwise Box3D
		/// will create threads and use an internal scheduler.
	workerCount: u32,
	/// function to spawn task
	enqueueTask: ^EnqueueTaskCallback,
	/// function to finish a task
	finishTask: ^FinishTaskCallback,
	/// User context that is provided to enqueueTask and finishTask
	userTaskContext: rawptr,
	/// User data associated with a world
	userData: rawptr,
	/// Used to create debug draw shapes. This is called when a shape is
		/// first drawn using b3DebugDraw.
	createDebugShape: ^CreateDebugShapeCallback,
	/// Used to destroy debug draw shapes. This is called when a shape is modified or destroyed.
	destroyDebugShape: ^DestroyDebugShapeCallback,
	/// This is passed to the debug shape callbacks to provide a user context.
	userDebugShapeContext: rawptr,
	/// Optional initial capacities
	capacity: Capacity,
	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

/// A 3D vector.
Vec3 :: [3]f32

/// Optional friction mixing callback. This intentionally provides no context objects because this is called
/// from a worker thread.
/// @warning This function should not attempt to modify Box3D state or user application state.
/// @ingroup world
FrictionCallback :: proc "c" (_: f32, _: u64, _: f32, _: u64) -> f32

/// Optional restitution mixing callback. This intentionally provides no context objects because this is called
/// from a worker thread.
/// @warning This function should not attempt to modify Box3D state or user application state.
/// @ingroup world
RestitutionCallback :: proc "c" (_: f32, _: u64, _: f32, _: u64) -> f32

/// These functions can be provided to Box3D to invoke a task system.
/// Returns a pointer to the user's task object. May be nullptr. A nullptr indicates to Box3D that the work was executed
/// serially within the callback and there is no need to call b3FinishTaskCallback. Otherwise the returned
/// value must be non-null will be passed to b3FinishTaskCallback as the userTask.
/// @param task the Box3D task to be called by the scheduler
/// @param taskContext the Box3D context object that the scheduler must pass to the task
/// @param userContext the scheduler context object that is opaque to Box3D
/// @param taskName the Box3D task name that the scheduler can use for diagnostics
/// @ingroup world
EnqueueTaskCallback :: proc "c" (_: ^TaskCallback, _: rawptr, _: rawptr, _: cstring) -> rawptr

/// Task interface
/// This is the prototype for a Box3D task. Your task system is expected to run this callback on a worker thread,
/// exactly once per enqueue, passing back the same taskContext pointer supplied to b3EnqueueTaskCallback.
/// @ingroup world
TaskCallback :: proc "c" (_: rawptr)

/// Finishes a user task object that wraps a Box3D task. This must block until the task has completed.
/// The step blocks here on the tasks it spawned, so b3World_Step holds its stack across every
/// fork/join. Drive it from a thread you can dedicate to the step, or from a fiber this callback can
/// park to free the underlying thread. In a job system that cannot park a job's stack, do not call
/// b3World_Step from inside a job: a job that blocks on its own sub-jobs without yielding its thread
/// can deadlock. The in-tree scheduler instead runs other pending tasks on the waiting thread.
/// @ingroup world
FinishTaskCallback :: proc "c" (_: rawptr, _: rawptr)

/// The user needs to be able to create debug draw shapes for multi-pass rendering to work efficiently.
/// These user shapes are created and destroyed via callback so they can be bound to shape lifetime and scaling updates.
/// @ingroup debug_draw
CreateDebugShapeCallback :: proc "c" (_: DebugShape, _: rawptr) -> rawptr

/// This is sent to the user for debug shape creation. The user should know the type in case they have
/// custom sphere or capsule rendering.
DebugShape :: distinct rawptr

DestroyDebugShapeCallback :: proc "c" (_: rawptr, _: rawptr)

/// Optional world capacities that can be use to avoid run-time allocations
/// @ingroup world
Capacity :: struct {
	/// Number of expected static shapes.
	staticShapeCount: i32,
	/// Number of expected dynamic and kinematic shapes.
	dynamicShapeCount: i32,
	/// Number of expected static bodies.
	staticBodyCount: i32,
	/// Number of expected dynamic and kinematic bodies.
	dynamicBodyCount: i32,
	/// Number of expected contacts.
	contactCount: i32,
}

/// This struct is passed to b3World_Draw to draw a debug view of the simulation world.
/// Callbacks receive world coordinates. In large world mode the translation is double precision so
/// it stays accurate far from the origin. Shift into your own camera frame inside the callbacks.
DebugDraw :: struct {
	/// Draws a shape and returns true if drawing should continue
	DrawShapeFcn: proc "c" (_: rawptr, _: WorldTransform, _: HexColor, _: rawptr) -> bool,
	/// Draw a line segment.
	DrawSegmentFcn: proc "c" (_: Pos, _: Pos, _: HexColor, _: rawptr),
	/// Draw a transform. Choose your own length scale.
	DrawTransformFcn: proc "c" (_: WorldTransform, _: rawptr),
	/// Draw a point.
	DrawPointFcn: proc "c" (_: Pos, _: f32, _: HexColor, _: rawptr),
	/// Draw a sphere.
	DrawSphereFcn: proc "c" (_: Pos, _: f32, _: HexColor, _: f32, _: rawptr),
	/// Draw a capsule.
	DrawCapsuleFcn: proc "c" (_: Pos, _: Pos, _: f32, _: HexColor, _: f32, _: rawptr),
	/// Draw a bounding box.
	DrawBoundsFcn: proc "c" (_: AABB, _: HexColor, _: rawptr),
	/// Draw an oriented box.
	DrawBoxFcn: proc "c" (_: Vec3, _: WorldTransform, _: HexColor, _: rawptr),
	/// Draw a string in world space
	DrawStringFcn: proc "c" (_: Pos, _: cstring, _: HexColor, _: rawptr),
	/// World bounds to use for debug draw
	drawingBounds: AABB,
	/// Scale to use when drawing forces
	forceScale: f32,
	/// Global scaling for joint drawing
	jointScale: f32,
	/// Option to draw shapes
	drawShapes: bool,
	/// Option to draw joints
	drawJoints: bool,
	/// Option to draw additional information for joints
	drawJointExtras: bool,
	/// Option to draw the bounding boxes for shapes
	drawBounds: bool,
	/// Option to draw the mass and center of mass of dynamic bodies
	drawMass: bool,
	/// Option to draw the sleep information for dynamic and kinematic bodies
	drawSleep: bool,
	/// Option to draw body names
	drawBodyNames: bool,
	/// Option to draw contact points
	drawContacts: bool,
	/// Draw contact anchor A or B
	drawAnchorA: i32,
	/// Option to visualize the graph coloring used for contacts and joints
	drawGraphColors: bool,
	/// Option to draw contact features
	drawContactFeatures: bool,
	/// Option to draw contact normals
	drawContactNormals: bool,
	/// Option to draw contact normal forces
	drawContactForces: bool,
	/// Option to draw contact friction forces
	drawFrictionForces: bool,
	/// Option to draw islands as bounding boxes
	drawIslands: bool,
	/// User context that is passed as an argument to drawing callback functions
	context_: rawptr,
}

/// In single precision mode these types are the same.
WorldTransform :: Transform

/// A rigid transform.
Transform :: struct {
	p: Vec3,
	q: Quat,
}

/// A quaternion.
Quat :: struct {
	v: Vec3,
	s: f32,
}

/// These colors are used for debug draw and mostly match the named SVG colors.
/// See https://www.rapidtables.com/web/color/index.html
/// https://johndecember.com/html/spec/colorsvg.html
/// https://upload.wikimedia.org/wikipedia/commons/2/2b/SVG_Recognized_color_keyword_names.svg
HexColor :: enum u32 {
	_colorAliceBlue = 15792383,
	_colorAntiqueWhite = 16444375,
	_colorAqua = 65535,
	_colorAquamarine = 8388564,
	_colorAzure = 15794175,
	_colorBeige = 16119260,
	_colorBisque = 16770244,
	_colorBlack = 0,
	_colorBlanchedAlmond = 16772045,
	_colorBlue = 255,
	_colorBlueViolet = 9055202,
	_colorBrown = 10824234,
	_colorBurlywood = 14596231,
	_colorCadetBlue = 6266528,
	_colorChartreuse = 8388352,
	_colorChocolate = 13789470,
	_colorCoral = 16744272,
	_colorCornflowerBlue = 6591981,
	_colorCornsilk = 16775388,
	_colorCrimson = 14423100,
	_colorCyan = 65535,
	_colorDarkBlue = 139,
	_colorDarkCyan = 35723,
	_colorDarkGoldenRod = 12092939,
	_colorDarkGray = 11119017,
	_colorDarkGreen = 25600,
	_colorDarkKhaki = 12433259,
	_colorDarkMagenta = 9109643,
	_colorDarkOliveGreen = 5597999,
	_colorDarkOrange = 16747520,
	_colorDarkOrchid = 10040012,
	_colorDarkRed = 9109504,
	_colorDarkSalmon = 15308410,
	_colorDarkSeaGreen = 9419919,
	_colorDarkSlateBlue = 4734347,
	_colorDarkSlateGray = 3100495,
	_colorDarkTurquoise = 52945,
	_colorDarkViolet = 9699539,
	_colorDeepPink = 16716947,
	_colorDeepSkyBlue = 49151,
	_colorDimGray = 6908265,
	_colorDodgerBlue = 2003199,
	_colorFireBrick = 11674146,
	_colorFloralWhite = 16775920,
	_colorForestGreen = 2263842,
	_colorFuchsia = 16711935,
	_colorGainsboro = 14474460,
	_colorGhostWhite = 16316671,
	_colorGold = 16766720,
	_colorGoldenRod = 14329120,
	_colorGray = 8421504,
	_colorGreen = 32768,
	_colorGreenYellow = 11403055,
	_colorHoneyDew = 15794160,
	_colorHotPink = 16738740,
	_colorIndianRed = 13458524,
	_colorIndigo = 4915330,
	_colorIvory = 16777200,
	_colorKhaki = 15787660,
	_colorLavender = 15132410,
	_colorLavenderBlush = 16773365,
	_colorLawnGreen = 8190976,
	_colorLemonChiffon = 16775885,
	_colorLightBlue = 11393254,
	_colorLightCoral = 15761536,
	_colorLightCyan = 14745599,
	_colorLightGoldenRodYellow = 16448210,
	_colorLightGray = 13882323,
	_colorLightGreen = 9498256,
	_colorLightPink = 16758465,
	_colorLightSalmon = 16752762,
	_colorLightSeaGreen = 2142890,
	_colorLightSkyBlue = 8900346,
	_colorLightSlateGray = 7833753,
	_colorLightSteelBlue = 11584734,
	_colorLightYellow = 16777184,
	_colorLime = 65280,
	_colorLimeGreen = 3329330,
	_colorLinen = 16445670,
	_colorMagenta = 16711935,
	_colorMaroon = 8388608,
	_colorMediumAquaMarine = 6737322,
	_colorMediumBlue = 205,
	_colorMediumOrchid = 12211667,
	_colorMediumPurple = 9662683,
	_colorMediumSeaGreen = 3978097,
	_colorMediumSlateBlue = 8087790,
	_colorMediumSpringGreen = 64154,
	_colorMediumTurquoise = 4772300,
	_colorMediumVioletRed = 13047173,
	_colorMidnightBlue = 1644912,
	_colorMintCream = 16121850,
	_colorMistyRose = 16770273,
	_colorMoccasin = 16770229,
	_colorNavajoWhite = 16768685,
	_colorNavy = 128,
	_colorOldLace = 16643558,
	_colorOlive = 8421376,
	_colorOliveDrab = 7048739,
	_colorOrange = 16753920,
	_colorOrangeRed = 16729344,
	_colorOrchid = 14315734,
	_colorPaleGoldenRod = 15657130,
	_colorPaleGreen = 10025880,
	_colorPaleTurquoise = 11529966,
	_colorPaleVioletRed = 14381203,
	_colorPapayaWhip = 16773077,
	_colorPeachPuff = 16767673,
	_colorPeru = 13468991,
	_colorPink = 16761035,
	_colorPlum = 14524637,
	_colorPowderBlue = 11591910,
	_colorPurple = 8388736,
	_colorRebeccaPurple = 6697881,
	_colorRed = 16711680,
	_colorRosyBrown = 12357519,
	_colorRoyalBlue = 4286945,
	_colorSaddleBrown = 9127187,
	_colorSalmon = 16416882,
	_colorSandyBrown = 16032864,
	_colorSeaGreen = 3050327,
	_colorSeaShell = 16774638,
	_colorSienna = 10506797,
	_colorSilver = 12632256,
	_colorSkyBlue = 8900331,
	_colorSlateBlue = 6970061,
	_colorSlateGray = 7372944,
	_colorSnow = 16775930,
	_colorSpringGreen = 65407,
	_colorSteelBlue = 4620980,
	_colorTan = 13808780,
	_colorTeal = 32896,
	_colorThistle = 14204888,
	_colorTomato = 16737095,
	_colorTurquoise = 4251856,
	_colorViolet = 15631086,
	_colorWheat = 16113331,
	_colorWhite = 16777215,
	_colorWhiteSmoke = 16119285,
	_colorYellow = 16776960,
	_colorYellowGreen = 10145074,
	_colorBox2DRed = 14430514,
	_colorBox2DBlue = 3190463,
	_colorBox2DGreen = 9226532,
	_colorBox2DYellow = 16772748,
}

/// In single precision mode these types are the same.
Pos :: [3]f32

/// Axis aligned bounding box.
AABB :: struct {
	lowerBound: Vec3,
	upperBound: Vec3,
}

/// Body events are buffered in the world and are available
///	as event arrays after the time step is complete.
///	Note: this data becomes invalid if bodies are destroyed
BodyEvents :: struct {
	/// Array of move events
	moveEvents: ^BodyMoveEvent,
	/// Number of move events
	moveCount: i32,
}

/// Body move events triggered when a body moves.
/// Triggered when a body moves due to simulation. Not reported for bodies moved by the user.
/// This also has a flag to indicate that the body went to sleep so the application can also
/// sleep that actor/entity/object associated with the body.
/// On the other hand if the flag does not indicate the body went to sleep then the application
/// can treat the actor/entity/object associated with the body as awake.
/// This is an efficient way for an application to update game object transforms rather than
/// calling functions such as b3Body_GetTransform() because this data is delivered as a contiguous array
/// and it is only populated with bodies that have moved.
/// @note If sleeping is disabled all dynamic and kinematic bodies will trigger move events.
BodyMoveEvent :: struct {
	/// The body user data.
	userData: rawptr,
	/// The body transform.
	transform: WorldTransform,
	/// The body id.
	bodyId: BodyId,
	/// Did the body fall asleep this time step?
	fellAsleep: bool,
}

/// Body id references a body instance. This should be treated as an opaque handle.
BodyId :: struct {
	index1: i32,
	world0: u16,
	generation: u16,
}

/// Sensor events are buffered in the world and are available
///	as begin/end overlap event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
SensorEvents :: struct {
	/// Array of sensor begin touch events
	beginEvents: ^SensorBeginTouchEvent,
	/// Array of sensor end touch events
	endEvents: ^SensorEndTouchEvent,
	/// The number of begin touch events
	beginCount: i32,
	/// The number of end touch events
	endCount: i32,
}

/// A begin-touch event is generated when a shape starts to overlap a sensor shape.
SensorBeginTouchEvent :: struct {
	/// The id of the sensor shape
	sensorShapeId: ShapeId,
	/// The id of the shape that began touching the sensor shape
	visitorShapeId: ShapeId,
}

/// Shape id references a shape instance. This should be treated as an opaque handle.
ShapeId :: struct {
	index1: i32,
	world0: u16,
	generation: u16,
}

/// An end touch event is generated when a shape stops overlapping a sensor shape.
///	These include things like setting the transform, destroying a body or shape, or changing
///	a filter. You will also get an end event if the sensor or visitor are destroyed.
///	Therefore you should always confirm the shape id is valid using b3Shape_IsValid.
SensorEndTouchEvent :: struct {
	/// The id of the sensor shape
		///	@warning this shape may have been destroyed
		///	@see b3Shape_IsValid
	sensorShapeId: ShapeId,
	/// The id of the shape that stopped touching the sensor shape
		///	@warning this shape may have been destroyed
		///	@see b3Shape_IsValid
	visitorShapeId: ShapeId,
}

/// Contact events are buffered in the world and are available
///	as event arrays after the time step is complete.
///	Note: these may become invalid if bodies and/or shapes are destroyed
ContactEvents :: struct {
	/// Array of begin touch events
	beginEvents: ^ContactBeginTouchEvent,
	/// Array of end touch events
	endEvents: ^ContactEndTouchEvent,
	/// Array of hit events
	hitEvents: ^ContactHitEvent,
	/// Number of begin touch events
	beginCount: i32,
	/// Number of end touch events
	endCount: i32,
	/// Number of hit events
	hitCount: i32,
}

/// A begin-touch event is generated when two shapes begin touching.
ContactBeginTouchEvent :: struct {
	/// Id of the first shape
	shapeIdA: ShapeId,
	/// Id of the second shape
	shapeIdB: ShapeId,
	/// The transient contact id. This contact may be destroyed automatically when the world is modified or simulated.
		/// Use b3Contact_IsValid before using this id.
	contactId: ContactId,
}

/// Contact id references a contact instance. This should be treated as an opaque handle.
ContactId :: struct {
	index1: i32,
	world0: u16,
	padding: i16,
	generation: u32,
}

/// An end touch event is generated when two shapes stop touching.
///	You will get an end event if you do anything that destroys contacts previous to the last
///	world step. These include things like setting the transform, destroying a body
///	or shape, or changing a filter or body type.
ContactEndTouchEvent :: struct {
	/// Id of the first shape
		///	@warning this shape may have been destroyed
		///	@see b3Shape_IsValid
	shapeIdA: ShapeId,
	/// Id of the first shape
		///	@warning this shape may have been destroyed
		///	@see b3Shape_IsValid
	shapeIdB: ShapeId,
	/// Id of the contact.
		///	@warning this contact may have been destroyed
		///	@see b3Contact_IsValid
	contactId: ContactId,
}

/// A hit touch event is generated when two shapes collide with a speed faster than the hit speed threshold.
/// This may be reported for speculative contacts that have a confirmed impulse.
ContactHitEvent :: struct {
	/// Id of the first shape
	shapeIdA: ShapeId,
	/// Id of the second shape
	shapeIdB: ShapeId,
	/// Id of the contact.
		///	@warning this contact may have been destroyed
		///	@see b3Contact_IsValid
	contactId: ContactId,
	/// Point where the shapes hit at the beginning of the time step.
		/// This is a mid-point between the two surfaces. It could be at speculative
		/// point where the two shapes were not touching at the beginning of the time step.
	point: Pos,
	/// Normal vector pointing from shape A to shape B
	normal: Vec3,
	/// The speed the shapes are approaching. Always positive. Typically in meters per second.
	approachSpeed: f32,
	/// User material on shape A
	userMaterialIdA: u64,
	/// User material on shape B
	userMaterialIdB: u64,
}

/// Joint events are buffered in the world and are available
/// as event arrays after the time step is complete.
/// Note: this data becomes invalid if joints are destroyed
JointEvents :: struct {
	/// Array of events
	jointEvents: ^JointEvent,
	/// Number of events
	count: i32,
}

/// Joint events report joints that are awake and have a force and/or torque exceeding the threshold
/// The observed forces and torques are not returned for efficiency reasons.
JointEvent :: struct {
	/// The joint id
	jointId: JointId,
	/// The user data from the joint for convenience
	userData: rawptr,
}

/// Joint id references a joint instance. This should be treated as an opaque handle.
JointId :: struct {
	index1: i32,
	world0: u16,
	generation: u16,
}

/// These are performance results returned by dynamic tree queries.
TreeStats :: struct {
	/// Number of internal nodes visited during the query
	nodeVisits: i32,
	/// Number of leaf nodes visited during the query
	leafVisits: i32,
}

/// The query filter is used to filter collisions between queries and shapes. For example,
/// you may want a ray-cast representing a projectile to hit players and the static environment
/// but not debris.
QueryFilter :: struct {
	/// The collision category bits of this query. Normally you would just set one bit.
	categoryBits: u64,
	/// The collision mask bits. This states the shape categories that this
		/// query would accept for collision.
	maskBits: u64,
	/// Optional id combined with @ref name to identify this query in a recording, e.g. an entity id.
		/// Need not be unique on its own. 0 with a null name means untagged. Ignored when not recording.
	id: u64,
	/// Optional label combined with @ref id to identify this query, e.g. "bullet". Need not be unique
		/// on its own. The recorder hashes (id, name) into one stable key the viewer tracks the query by,
		/// so the same id and name pair identifies the same query across frames. NULL means none. Ignored
		/// when not recording.
	name: cstring,
}

/// Prototype callback for overlap queries.
/// Called for each shape found in the query.
/// @see b3World_OverlapAABB
/// @return false to terminate the query.
/// @ingroup world
OverlapResultFcn :: proc "c" (_: ShapeId, _: rawptr) -> bool

/// A shape proxy is used by the GJK algorithm. It can represent a convex shape.
ShapeProxy :: struct {
	/// The point cloud.
	points: ^Vec3,
	/// The number of points. Do not exceed B3_MAX_SHAPE_CAST_POINTS.
	count: i32,
	/// The external radius of the point cloud.
	radius: f32,
}

/// Prototype callback for ray casts.
/// Called for each shape found in the query. You control how the ray cast
/// proceeds by returning a float:
/// return -1: ignore this shape and continue
/// return 0: terminate the ray cast
/// return fraction: clip the ray to this point
/// return 1: don't clip the ray and continue
/// @param shapeId the shape hit by the ray
/// @param point the point of initial intersection
/// @param normal the normal vector at the point of intersection
/// @param fraction the fraction along the ray at the point of intersection
/// @param userMaterialId the shape or triangle surface type
/// @param triangleIndex the triangle index for mesh or height field shapes or -1 for other shape types
/// @param childIndex the child shape index for compound shapes
/// @param context the user context
/// @return -1 to filter, 0 to terminate, fraction to clip the ray for closest hit, 1 to continue
/// @see b3World_CastRay
/// @ingroup world
CastResultFcn :: proc "c" (_: ShapeId, _: Pos, _: Vec3, _: f32, _: u64, _: i32, _: i32, _: rawptr) -> f32

/// Result from b3World_RayCastClosest.
RayResult :: struct {
	/// The shape hit.
	shapeId: ShapeId,
	/// The world point of the hit.
	point: Pos,
	/// The world normal of the shape surface at the hit point.
	normal: Vec3,
	/// The user material id at the hit point. This can be per triangle
		/// if the shape is a mesh, height-field, or compound with child mesh.
	userMaterialId: u64,
	/// The fraction of the input ray.
	fraction: f32,
	/// The triangle index if the shape is a mesh, height-field, or compound with
		/// child mesh.
	triangleIndex: i32,
	/// The child index if the shape is a compound.
	childIndex: i32,
	/// The number of BVH nodes visited. Diagnostic.
	nodeVisits: i32,
	/// The number of BVH leaves visited. Diagnostic.
	leafVisits: i32,
	/// Did the ray hit? If false, all other data is invalid.
	hit: bool,
}

/// A solid capsule can be viewed as two hemispheres connected
/// by a rectangle.
Capsule :: struct {
	/// Local center of the first hemisphere
	center1: Vec3,
	/// Local center of the second hemisphere
	center2: Vec3,
	/// The radius of the hemispheres
	radius: f32,
}

/// Used to filter shapes for shape casting character movers.
/// Return true to accept the collision
MoverFilterFcn :: proc "c" (_: ShapeId, _: rawptr) -> bool

/// Used to collect collision planes for character movers.
/// Return true to continue gathering planes.
PlaneResultFcn :: proc "c" (_: ShapeId, _: ^PlaneResult, _: i32, _: rawptr) -> bool

/// The plane between a character mover and a shape
PlaneResult :: struct {
	/// Outward pointing plane.
	plane: Plane,
	/// Closest point on the shape. May not be unique.
	point: Vec3,
}

/// A plane.
/// separation = dot(normal, point) - offset
Plane :: struct {
	normal: Vec3,
	offset: f32,
}

/// Prototype for a contact filter callback.
/// This is called when a contact pair is considered for collision. This allows you to
/// perform custom logic to prevent collision between shapes. This is only called if
/// one of the two shapes has custom filtering enabled. @see b3ShapeDef.
/// Notes:
/// - this function must be thread-safe
/// - this is only called if one of the two shapes has enabled custom filtering
/// - this is called only for awake dynamic bodies
/// Return false if you want to disable the collision
/// @warning Do not attempt to modify the world inside this callback
/// @ingroup world
CustomFilterFcn :: proc "c" (_: ShapeId, _: ShapeId, _: rawptr) -> bool

/// Prototype for a pre-solve callback.
/// This is called after a contact is updated. This allows you to inspect a
/// collision before it goes to the solver.
/// Notes:
/// - this function must be thread-safe
/// - this is only called if the shape has enabled pre-solve events
/// - this may be called for awake dynamic bodies and sensors
/// - this is not called for sensors
/// Return false if you want to disable the contact this step
/// This has limited information because it is used during CCD which does not have the
/// full contact manifold.
/// @warning Do not attempt to modify the world inside this callback
/// @ingroup world
PreSolveFcn :: proc "c" (_: ShapeId, _: ShapeId, _: Pos, _: Vec3, _: rawptr) -> bool

/// The explosion definition is used to configure options for explosions. Explosions
/// consider shape geometry when computing the impulse.
/// @ingroup world
ExplosionDef :: struct {
	/// Mask bits to filter shapes
	maskBits: u64,
	/// The center of the explosion in world space
	position: Pos,
	/// The radius of the explosion
	radius: f32,
	/// The falloff distance beyond the radius. Impulse is reduced to zero at this distance.
	falloff: f32,
	/// Impulse per unit area. This applies an impulse according to the shape area that
		/// is facing the explosion. Explosions only apply to spheres, capsules, and hulls. This
		/// may be negative for implosions.
	impulsePerArea: f32,
}

//! @cond
/// Profiling data. Times are in milliseconds.
/// @ingroup world
Profile :: struct {
	step: f32,
	pairs: f32,
	collide: f32,
	solve: f32,
	solverSetup: f32,
	constraints: f32,
	prepareConstraints: f32,
	integrateVelocities: f32,
	warmStart: f32,
	solveImpulses: f32,
	integratePositions: f32,
	relaxImpulses: f32,
	applyRestitution: f32,
	storeImpulses: f32,
	splitIslands: f32,
	transforms: f32,
	sensorHits: f32,
	jointEvents: f32,
	hitEvents: f32,
	refit: f32,
	bullets: f32,
	sleepIslands: f32,
	sensors: f32,
}

/// Counters that give details of the simulation size.
/// @ingroup world
Counters :: struct {
	bodyCount: i32,
	shapeCount: i32,
	contactCount: i32,
	jointCount: i32,
	islandCount: i32,
	stackUsed: i32,
	arenaCapacity: i32,
	staticTreeHeight: i32,
	treeHeight: i32,
	satCallCount: i32,
	satCacheHitCount: i32,
	byteCount: i32,
	taskCount: i32,
	colorCounts: [24]i32,
	manifoldCounts: [8]i32,
	/// Number of contacts touched by the collide pass
		/// graph contacts + awake-set non-touching
	awakeContactCount: i32,
	/// Number of contacts recycled in the most recent step.
	recycledContactCount: i32,
	/// Maximum number of time of impact iterations
	distanceIterations: i32,
	pushBackIterations: i32,
	rootIterations: i32,
}

/// The body simulation type.
/// Each body is one of these three types. The type determines how the body behaves in the simulation.
/// @ingroup body
BodyType :: enum u32 {
	/// zero mass, zero velocity, may be manually moved
	_staticBody,
	/// zero mass, velocity set by user, moved by solver
	_kinematicBody,
	/// positive mass, velocity determined by forces, moved by solver
	_dynamicBody,
	/// number of body types
	_bodyTypeCount,
}

Recording :: distinct rawptr

RecPlayer :: distinct rawptr

/// Summary of a recording, read once at open so a viewer can frame and label it.
RecPlayerInfo :: struct {
	// total recorded steps
	frameCount: i32,
	// worker count requested for the replay world
	workerCount: i32,
	// dt of the recorded steps
	timeStep: f32,
	// recorded sub-steps
	subStepCount: i32,
	// length units per meter in effect when recorded
	lengthScale: f32,
	// accumulated world bounds over the recording, zero-extent if unavailable
	bounds: AABB,
}

/// The kind of a recorded spatial query, matching the public query and cast functions.
RecQueryType :: enum u32 {
	_recQueryOverlapAABB,
	_recQueryOverlapShape,
	_recQueryCastRay,
	_recQueryCastShape,
	_recQueryCastRayClosest,
	_recQueryCastMover,
	_recQueryCollideMover,
}

/// A spatial query recorded during a replayed frame, exposed for inspection.
RecQueryInfo :: struct {
	type: RecQueryType,
	filter: QueryFilter,
	// world-space bounds of the query, swept for casts
	aabb: AABB,
	// query origin (zero for overlap AABB)
	origin: Pos,
	// ray and cast translation
	translation: Vec3,
	// number of recorded results
	hitCount: i32,
	// identity key, the hash of (id, name), 0 if untagged
	key: u64,
	// query id, 0 if none
	id: u64,
	// query label, NULL if none
	name: cstring,
}

/// One result of a recorded spatial query.
RecQueryHit :: struct {
	shape: ShapeId,
	point: Pos,
	normal: Vec3,
	fraction: f32,
}

/// A body definition holds all the data needed to construct a rigid body.
/// You can safely re-use body definitions. Shapes are added to a body after construction.
/// Body definitions are temporary objects used to bundle creation parameters.
/// Must be initialized using b3DefaultBodyDef().
/// @ingroup body
BodyDef :: struct {
	/// The body type: static, kinematic, or dynamic.
	type: BodyType,
	/// The initial world position of the body. Bodies should be created with the desired position.
		/// @note Creating bodies at the origin and then moving them nearly doubles the cost of body creation, especially
		/// if the body is moved after shapes have been added.
	position: Pos,
	/// The initial world rotation of the body.
	rotation: Quat,
	/// The initial linear velocity of the body's origin. Usually in meters per second.
	linearVelocity: Vec3,
	/// The initial angular velocity of the body. Radians per second.
	angularVelocity: Vec3,
	/// Linear damping is used to reduce the linear velocity. The damping parameter
		/// can be larger than 1 but the damping effect becomes sensitive to the
		/// time step when the damping parameter is large.
		/// Generally linear damping is undesirable because it makes objects move slowly
		/// as if they are floating.
	linearDamping: f32,
	/// Angular damping is used to reduce the angular velocity. The damping parameter
		/// can be larger than 1.0f but the damping effect becomes sensitive to the
		/// time step when the damping parameter is large.
		/// Angular damping can be used to slow down rotating bodies.
	angularDamping: f32,
	/// Scale the gravity applied to this body. Non-dimensional.
	gravityScale: f32,
	/// Sleep speed threshold, default is 0.05 meters per second
	sleepThreshold: f32,
	/// Optional body name for debugging.
	name: cstring,
	/// Use this to store application specific body data.
	userData: rawptr,
	/// Motions locks to restrict linear and angular movement
	motionLocks: MotionLocks,
	/// Set this flag to false if this body should never fall asleep.
	enableSleep: bool,
	/// Is this body initially awake or sleeping?
	isAwake: bool,
	/// Treat this body as a high speed object that performs continuous collision detection
		/// against dynamic and kinematic bodies, but not other bullet bodies.
		/// @warning Bullets should be used sparingly. They are not a solution for general dynamic-versus-dynamic
		/// continuous collision. They do not guarantee accurate collision if both bodies are fast moving because
		/// the bullet does a continuous check after all non-bullet bodies have moved. You could get unlucky and have
		/// the bullet body end a time step very close to a non-bullet body and the non-bullet body then moves over
		/// the bullet body. In continuous collision, initial overlap is ignored to avoid freezing bodies in place.
		/// I do not recommend using them for game projectiles if precise collision timing is needed. Instead consider
		/// using a ray or shape cast. You can use a marching ray or shape cast for projectile that moves over time.
		/// If you want a fast moving projectile to collide with a fast moving target, you need to consider the relative
		/// movement in your ray or shape cast. This is out of the scope of Box3D.
		/// So what are good use cases for bullets? Pinball games or games with dynamic containers that hold other objects.
		/// It should be a use case where it doesn't break the game if there is a collision missed, but having them
		/// captured improves the quality of the game.
	isBullet: bool,
	/// Used to disable a body. A disabled body does not move or collide.
	isEnabled: bool,
	/// This allows this body to bypass rotational speed limits. Should only be used
		/// for circular objects, like wheels.
	allowFastRotation: bool,
	/// Enable contact recycling. True by default. Leaving this enabled improves performance
		/// but may lead to ghost collision that should be avoided on characters.
	enableContactRecycling: bool,
	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

/// Motion locks to restrict the body movement
/// @ingroup body
MotionLocks :: struct {
	/// Prevent translation along the x-axis
	linearX: bool,
	/// Prevent translation along the y-axis
	linearY: bool,
	/// Prevent translation along the z-axis
	linearZ: bool,
	/// Prevent rotation around the x-axis
	angularX: bool,
	/// Prevent rotation around the y-axis
	angularY: bool,
	/// Prevent rotation around the z-axis
	angularZ: bool,
}

/// A 3x3 matrix.
Matrix3 :: struct {
	cx: Vec3,
	cy: Vec3,
	cz: Vec3,
}

/// This holds the mass data computed for a shape.
MassData :: struct {
	/// The shape mass
	mass: f32,
	/// The local center of mass position.
	center: Vec3,
	/// The inertia tensor about the shape center of mass.
	inertia: Matrix3,
}

/// The contact data for two shapes. By convention the manifold normal points
/// from shape A to shape B.
/// @see b3Shape_GetContactData() and b3Body_GetContactData()
ContactData :: struct {
	/// The contact id. You may hold onto this to track a contact across time steps.
		/// This id may become orphaned. Use b3Contact_IsValid before using it for other functions.
	contactId: ContactId,
	/// The first shape id.
	shapeIdA: ShapeId,
	/// The second shape id.
	shapeIdB: ShapeId,
	/// The contact manifold. This points to internal data and may become invalid. Do not store
		/// this pointer.
	manifolds: Manifold,
	/// The number of contact manifolds. For mesh and height-field collision there can be multiple manifolds.
	manifoldCount: i32,
}

/// A contact manifold describes the contact points between colliding shapes.
/// @note Box3D uses speculative collision so some contact points may be separated.
Manifold :: distinct rawptr

/// Body cast result for ray and shape casts.
BodyCastResult :: struct {
	/// The shape hit.
	shapeId: ShapeId,
	/// The world point on the shape surface.
	point: Pos,
	/// The world normal vector on the shape surface.
	normal: Vec3,
	/// The fraction along the ray hit.
		/// hit point = origin + fraction * translation
	fraction: f32,
	/// The triangle index if the shape is a mesh or height-field.
	triangleIndex: i32,
	/// The user material id at the hit point. This can be per triangle
		/// if the shape is a mesh, height-field, or compound with child mesh.
	userMaterialId: u64,
	/// The number of iterations used. Diagnostic.
	iterations: i32,
	/// Did the cast hit? If false, all other fields are invalid.
	hit: bool,
}

/// Body plane result for movers.
BodyPlaneResult :: struct {
	/// The shape id on the body.
	shapeId: ShapeId,
	/// The plane result.
	result: PlaneResult,
}

/// Used to create a shape
/// @ingroup shape
ShapeDef :: struct {
	/// Optional shape name for debugging
	name: cstring,
	/// Use this to store application specific shape data.
	userData: rawptr,
	/// Surface material used on mesh shapes per triangle. Ignored for convex shapes. Ignored for compound shapes.
	materials: ^SurfaceMaterial,
	/// Surface material count.
	materialCount: i32,
	/// The base surface material. Ignored for compound shapes.
	baseMaterial: SurfaceMaterial,
	/// The density, usually in kg/m^3.
	density: f32,
	/// Explosion scale for b3World_Explode. non-dimensional
	explosionScale: f32,
	/// Contact filtering data.
	filter: Filter,
	/// Enable custom filtering. Only one of the two shapes needs to enable custom filtering. See b3WorldDef.
	enableCustomFiltering: bool,
	/// A sensor shape generates overlap events but never generates a collision response.
		/// Sensors do not have continuous collision. Instead, use a ray or shape cast for those scenarios.
		/// Sensors still contribute to the body mass if they have non-zero density.
		/// @note Sensor events are disabled by default.
		/// @see enableSensorEvents
	isSensor: bool,
	/// Enable sensor events for this shape. This applies to sensors and non-sensors. False by default, even for sensors.
	enableSensorEvents: bool,
	/// Enable contact events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors. False by default.
	enableContactEvents: bool,
	/// Enable hit events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors. False by default.
	enableHitEvents: bool,
	/// Enable pre-solve contact events for this shape. Only applies to dynamic bodies. These are expensive
		///	and must be carefully handled due to multithreading. Ignored for sensors.
	enablePreSolveEvents: bool,
	/// When shapes are created they will scan the environment for collision the next time step. This can significantly slow down
		/// static body creation when there are many static shapes.
		/// This is flag is ignored for dynamic and kinematic shapes which always invoke contact creation.
	invokeContactCreation: bool,
	/// Should the body update the mass properties when this shape is created. Default is true.
		/// Warning: if this is false, you MUST call b3Body_ApplyMassFromShapes or b3Body_SetMassData before simulating the world.
	updateBodyMass: bool,
	/// Enable speculative collision. Leave this true unless you care about reducing ghost collision
		/// more than continuous collision under rotation.
		/// Experimental: this can only disable speculative contact between hulls and triangles (meshes and height fields).
	enableSpeculativeContact: bool,
	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

/// Material properties supported per triangle on meshes and height fields
/// @ingroup shape
SurfaceMaterial :: struct {
	/// The Coulomb (dry) friction coefficient, usually in the range [0,1].
	friction: f32,
	/// The coefficient of restitution (bounce) usually in the range [0,1].
		/// https://en.wikipedia.org/wiki/Coefficient_of_restitution
	restitution: f32,
	/// The rolling resistance usually in the range [0,1]. This is only used for spheres and capsules.
	rollingResistance: f32,
	/// The tangent velocity for conveyor belts. This is local to the shape and will be projected
		/// onto the contact surface.
	tangentVelocity: Vec3,
	/// User material identifier. This is passed with query results and to friction and restitution
		/// combining functions. It is not used internally.
	userMaterialId: u64,
	/// Custom debug draw color. Ignored if 0. The low 24 bits are RGB. The high byte may
		/// carry a b3DebugMaterial preset, see b3MakeDebugColor.
		/// @see b3HexColor
	customColor: u32,
}

/// This is used to filter collision on shapes. It affects shape-vs-shape collision
/// and shape-versus-query collision (such as b3World_CastRay).
/// @ingroup shape
Filter :: struct {
	/// The collision category bits. Normally you would just set one bit. The category bits should
		/// represent your application object types. For example:
		/// @code{.cpp}
		/// enum MyCategories
		/// {
		///    Static  = 0x00000001,
		///    Dynamic = 0x00000002,
		///    Debris  = 0x00000004,
		///    Player  = 0x00000008,
		///    // etc
		/// };
		/// @endcode
	categoryBits: u64,
	/// The collision mask bits. This states the categories that this
		/// shape would accept for collision.
		/// For example, you may want your player to only collide with static objects
		/// and other players.
		/// @code{.c}
		/// maskBits = Static | Player;
		/// @endcode
	maskBits: u64,
	/// Collision groups allow a certain group of objects to never collide (negative)
		/// or always collide (positive). A group index of zero has no effect. Non-zero group filtering
		/// always wins against the mask bits.
		/// For example, you may want ragdolls to collide with other ragdolls but you don't want
		/// ragdoll self-collision. In this case you would give each ragdoll a unique negative group index
		/// and apply that group index to all shapes on the ragdoll.
	groupIndex: i32,
}

/// A solid sphere
Sphere :: struct {
	/// The local center
	center: Vec3,
	/// The radius
	radius: f32,
}

/// A convex hull.
/// @note This data structure has data hanging off the end and cannot be directly copied.
HullData :: struct {
	/// Version must be first and match B3_HULL_VERSION
	version: u64,
	/// The total number of bytes for this hull.
	byteCount: i32,
	/// Hash of this hull (this field is zero when the hash is computed).
	hash: u32,
	/// Axis-aligned box in local space.
	aabb: AABB,
	/// Surface area, typically in squared meters.
	surfaceArea: f32,
	/// Volume, typically in m^3.
	volume: f32,
	/// The radius of the largest sphere at the center.
	innerRadius: f32,
	/// The local centroid
	center: Vec3,
	/// The inertia tensor about the centroid.
	centralInertia: Matrix3,
	/// The vertex count.
	vertexCount: i32,
	/// Offset of the vertex array in bytes from the struct address.
	vertexOffset: i32,
	/// Offset of the point array in bytes from the struct address.
	pointOffset: i32,
	/// This is the half-edge count (double the edge count)
	edgeCount: i32,
	/// Offset of the edge array in bytes from the struct address.
	edgeOffset: i32,
	/// The face count. Hulls faces are convex polygons.
	faceCount: i32,
	/// Offset of the face array in bytes from the struct address.
	faceOffset: i32,
	/// Offset of the face plane array in bytes from the struct address.
	planeOffset: i32,
	/// Explicit padding. Hull identity is a content hash and memcmp over raw bytes,
		/// so there must be no unnamed padding for struct copies to scramble.
	padding: i32,
}

/// This is a sorted triangle collision bounding volume hierarchy.
/// @note This struct has data hanging off the end and cannot be directly copied.
MeshData :: struct {
	/// Version must be first.
	version: u64,
	/// The total number of bytes for this mesh.
	byteCount: i32,
	/// Hash of this mesh (this field is zero when the hash is computed)
	hash: u32,
	/// Local axis-aligned box.
	bounds: AABB,
	/// Combined surface area of all triangles. Single-sided.
	surfaceArea: f32,
	/// The height of the bounding volume hierarchy.
	treeHeight: i32,
	/// The number of degenerate triangles. Diagnostic.
	degenerateCount: i32,
	/// Offset of the node array in bytes from the struct address.
	nodeOffset: i32,
	/// The number of BVH nodes.
	nodeCount: i32,
	/// Offset of the vertex array in bytes from the struct address.
	vertexOffset: i32,
	/// The number of vertices.
	vertexCount: i32,
	/// Offset of the triangle array in bytes from the struct address.
	triangleOffset: i32,
	/// The number of triangles.
	triangleCount: i32,
	/// Offset of the material array in bytes from the struct address.
	materialOffset: i32,
	/// The number of materials.
	materialCount: i32,
	/// Offset of the triangle flag array in bytes from the struct address.
	flagsOffset: i32,
}

/// A height field with compressed storage.
/// @note This data structure has data hanging off the end and cannot be directly copied.
HeightFieldData :: struct {
	/// Version must be first and match B3_HEIGHT_FIELD_VERSION
	version: u64,
	/// The total number of bytes for this height field.
	byteCount: i32,
	/// Hash of this height field (this field is zero when the hash is computed).
	hash: u32,
	/// The local axis-aligned bounding box.
	aabb: AABB,
	/// The minimum y value.
	minHeight: f32,
	/// The maximum y value
	maxHeight: f32,
	/// The quantization scale.
	heightScale: f32,
	/// The overall scale.
	scale: Vec3,
	/// The number of grid columns along the local x-axis.
	columnCount: i32,
	/// The number of grid rows along the local z-axis.
	rowCount: i32,
	/// Offset of the compressed height array in bytes from the struct address.
		/// uint16_t, one per grid point.
	heightsOffset: i32,
	/// Offset of the material index array in bytes from the struct address.
		/// uint8_t, one per cell.
	materialOffset: i32,
	/// Offset of the flag array in bytes from the struct address.
		/// uint8_t, one per triangle.
	flagsOffset: i32,
	/// Triangle winding.
	clockwise: bool,
	/// Explicit padding. Identity is a content hash over raw bytes, so there must
		/// be no unnamed padding for struct copies to scramble.
	padding: [3]u8,
}

/// The runtime data for a baked compound shape. This is a potentially large yet highly optimized
/// data structure. It can contain thousands of child shapes, yet at runtime it populates
/// into the world as a single shape in the runtime broad-phase.
/// This data structure has data living off the end and must be accessed using offsets.
/// Accessors are provided for user relevant data.
/// Note: you don't need to use this to create runtime compounds. For runtime compounds you can
/// add multiple shapes to a body using the regular shape creation functions.
CompoundData :: struct {
	/// The compound version is always first.
	version: u64,
	/// The total number of bytes for this compound.
	byteCount: i32,
	/// Offset of the tree node array in bytes from the struct address.
	nodeOffset: i32,
	/// Immutable dynamic tree. The tree node pointer must be fixed up using the node offset
	tree: DynamicTree,
	/// Offset of the material array in bytes from the struct address.
	materialOffset: i32,
	/// The number of materials.
	materialCount: i32,
	/// Offset of the capsule array in bytes from the struct address.
	capsuleOffset: i32,
	/// The number of capsules.
	capsuleCount: i32,
	/// Offset of the hull instance array in bytes from the struct address.
	hullOffset: i32,
	/// The number of hull instances.
	hullCount: i32,
	/// The number of unique hulls. Diagnostic.
	sharedHullCount: i32,
	/// Offset of the mesh instance array in bytes from the struct address.
	meshOffset: i32,
	/// The number of mesh instances.
	meshCount: i32,
	/// The number of unique meshes. Diagnostic.
	sharedMeshCount: i32,
	/// Offset of the sphere array in bytes from the struct address.
	sphereOffset: i32,
	/// The number of spheres.
	sphereCount: i32,
}

/// The dynamic tree structure. This should be considered private data.
/// It is placed here for performance reasons.
DynamicTree :: struct {
	/// The dynamic tree version. Always the first field. Useful
		/// if the tree is serialized.
	version: u64,
	/// The tree nodes
	nodes: ^TreeNode,
	/// The root index
	root: i32,
	/// The number of nodes
	nodeCount: i32,
	/// The allocated node space
	nodeCapacity: i32,
	/// Number of proxies created
	proxyCount: i32,
	/// Node free list
	freeList: i32,
	/// Leaf indices for rebuild
	leafIndices: ^i32,
	/// Leaf bounding boxes for rebuild
	leafBoxes: ^AABB,
	/// Leaf bounding box centers for rebuild
	leafCenters: ^Vec3,
	/// Bins for sorting during rebuild
	binIndices: ^i32,
	/// Allocated space for rebuilding
	rebuildCapacity: i32,
}

/// A node in the dynamic tree. This is private data placed here for performance reasons.
/// todo test padding to 64 bytes to avoid straddling cache lines
TreeNode :: struct {
	// 24
	aabb: AABB,
	// 8
	categoryBits: u64,
	using _: struct #raw_union {
		/// Children (internal node)
		children: TreeNodeChildren,
		/// User data (leaf node)
		userData: u64,
	},
	using _: struct #raw_union {
		/// The node parent index (allocated node)
		parent: i32,
		/// The node freelist next index (free node)
		next: i32,
	},
	// 2
	height: u16,
	// 2
	flags: u16,
}

/// Tree node child indices. For internal usage.
TreeNodeChildren :: struct {
	///< child node index 1
	child1: i32,
	///< child node index 2
	child2: i32,
}

/// Shape type
/// @ingroup shape
ShapeType :: enum u32 {
	/// A capsule is an extruded sphere
	_capsuleShape,
	/// A baked compound shape composed of spheres, capsules, hulls, and meshes
	_compoundShape,
	/// A height field useful for terrain
	_heightShape,
	/// A convex hull
	_hullShape,
	/// A triangle soup
	_meshShape,
	/// A sphere with an offset
	_sphereShape,
	/// The number of shape types
	_shapeTypeCount,
}

/// Same type in single precision.
WorldCastOutput :: CastOutput

/// Low level ray cast or shape-cast output data.
CastOutput :: struct {
	/// The surface normal at the hit point.
	normal: Vec3,
	/// The surface hit point.
	point: Vec3,
	/// The fraction of the input translation at collision.
	fraction: f32,
	/// The number of iterations used.
	iterations: i32,
	/// The index of the mesh or height field triangle hit.
	triangleIndex: i32,
	/// The index of the compound child shape.
	childIndex: i32,
	/// The material index. May be -1 for null.
	materialIndex: i32,
	/// Did the cast hit?
	hit: bool,
}

/// This allows mesh data to be re-used with different scales.
Mesh :: struct {
	/// Immutable pointer to the mesh data.
	data: ^MeshData,
	/// This scale may be non-uniform and have negative components. However,
		/// no component may be very small in magnitude.
	scale: Vec3,
}

/// Joint type enumeration. This is useful because all joint types use b3JointId and sometimes you
/// want to get the type of a joint.
/// @ingroup joint
JointType :: enum u32 {
	_parallelJoint,
	_distanceJoint,
	_filterJoint,
	_motorJoint,
	_prismaticJoint,
	_revoluteJoint,
	_sphericalJoint,
	_weldJoint,
	_wheelJoint,
}

/// Parallel joint definition. Constrains the angle between axis z in body A and axis z in body B
/// using a spring. Useful to keep a body upright.
/// @ingroup parallel_joint
ParallelJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// The spring stiffness Hertz, cycles per second
	hertz: f32,
	/// The spring damping ratio, non-dimensional
	dampingRatio: f32,
	/// The maximum spring torque, typically in newton-meters.
	maxTorque: f32,
}

/// Base joint definition used by all joint types. The local frames are measured from the
/// body's origin rather than the center of mass because:
/// 1. You might not know where the center of mass will be.
/// 2. If you add/remove shapes from a body and recompute the mass, the joints will be broken.
/// @ingroup joint
JointDef :: struct {
	/// User data pointer
	userData: rawptr,
	/// The first attached body
	bodyIdA: BodyId,
	/// The second attached body
	bodyIdB: BodyId,
	/// The first local joint frame
	localFrameA: Transform,
	/// The second local joint frame
	localFrameB: Transform,
	/// Force threshold for joint events
	forceThreshold: f32,
	/// Torque threshold for joint events
	torqueThreshold: f32,
	/// Constraint hertz (advanced feature)
	constraintHertz: f32,
	/// Constraint damping ratio (advanced feature)
	constraintDampingRatio: f32,
	/// Debug draw scale
	drawScale: f32,
	/// Set this flag to true if the attached bodies should collide
	collideConnected: bool,
	/// Used internally to detect a valid definition. DO NOT SET.
	internalValue: i32,
}

/// Distance joint definition.
/// Connects a point on body A with a point on body B by a segment.
/// Useful for ropes and springs.
/// @ingroup distance_joint
DistanceJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// The rest length of this joint. Clamped to a stable minimum value.
	length: f32,
	/// Enable the distance constraint to behave like a spring. If false
		/// then the distance joint will be rigid, overriding the limit and motor.
	enableSpring: bool,
	/// The lower spring force controls how much tension it can sustain
	lowerSpringForce: f32,
	/// The upper spring force controls how much compression it can sustain
	upperSpringForce: f32,
	/// The spring linear stiffness Hertz, cycles per second
	hertz: f32,
	/// The spring linear damping ratio, non-dimensional
	dampingRatio: f32,
	/// Enable/disable the joint limit
	enableLimit: bool,
	/// Minimum length. Clamped to a stable minimum value.
	minLength: f32,
	/// Maximum length. Must be greater than or equal to the minimum length.
	maxLength: f32,
	/// Enable/disable the joint motor
	enableMotor: bool,
	/// The maximum motor force, usually in newtons
	maxMotorForce: f32,
	/// The desired motor speed, usually in meters per second
	motorSpeed: f32,
}

/// A motor joint is used to control the relative position and velocity between two bodies.
/// @ingroup motor_joint
MotorJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// The desired linear velocity
	linearVelocity: Vec3,
	/// The maximum motor force in newtons
	maxVelocityForce: f32,
	/// The desired angular velocity
	angularVelocity: Vec3,
	/// The maximum motor torque in newton-meters
	maxVelocityTorque: f32,
	/// Linear spring hertz for position control
	linearHertz: f32,
	/// Linear spring damping ratio
	linearDampingRatio: f32,
	/// Maximum spring force in newtons
	maxSpringForce: f32,
	/// Angular spring hertz for position control
	angularHertz: f32,
	/// Angular spring damping ratio
	angularDampingRatio: f32,
	/// Maximum spring torque in newton-meters
	maxSpringTorque: f32,
}

/// A filter joint is used to disable collision between two specific bodies.
/// @ingroup filter_joint
FilterJointDef :: struct {
	/// Base joint definition
	base: JointDef,
}

/// Prismatic joint definition. Body B may slide along the x-axis in local frame A.
/// Body B cannot rotate relative to body A. The joint translation is zero when the
/// local frame origins coincide in world space.
/// @ingroup prismatic_joint
PrismaticJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// Enable a linear spring along the prismatic joint axis
	enableSpring: bool,
	/// The spring stiffness Hertz, cycles per second
	hertz: f32,
	/// The spring damping ratio, non-dimensional
	dampingRatio: f32,
	/// The target translation for the joint in meters. The spring-damper will drive
		/// to this translation.
	targetTranslation: f32,
	/// Enable/disable the joint limit
	enableLimit: bool,
	/// The lower translation limit
	lowerTranslation: f32,
	/// The upper translation limit
	upperTranslation: f32,
	/// Enable/disable the joint motor
	enableMotor: bool,
	/// The maximum motor force, typically in newtons
	maxMotorForce: f32,
	/// The desired motor speed, typically in meters per second
	motorSpeed: f32,
}

/// Revolute joint definition. A point on body B is fixed to a point on body A.
/// Allows relative rotation about the z-axis.
/// @ingroup revolute_joint
RevoluteJointDef :: struct {
	/// Base joint definition.
	base: JointDef,
	/// The bodyB angle minus bodyA angle in the reference state (radians).
		/// This defines the zero angle for the joint limit.
	targetAngle: f32,
	/// Enable a rotational spring on the revolute hinge axis.
	enableSpring: bool,
	/// The spring stiffness Hertz, cycles per second.
	hertz: f32,
	/// The spring damping ratio, non-dimensional.
	dampingRatio: f32,
	/// A flag to enable joint limits.
	enableLimit: bool,
	/// The lower angle for the joint limit in radians. Minimum of -0.99*pi radians.
	lowerAngle: f32,
	/// The upper angle for the joint limit in radians. Maximum of 0.99*pi radians.
	upperAngle: f32,
	/// A flag to enable the joint motor.
	enableMotor: bool,
	/// The maximum motor torque, typically in newton-meters.
	maxMotorTorque: f32,
	/// The desired motor speed in radians per second.
	motorSpeed: f32,
}

/// Spherical joint definition. A point on body B is fixed to a point on body A.
/// Allows rotation about the shared point.
/// @ingroup spherical_joint
SphericalJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// Enable a rotational spring that attempts to align the two joint frames.
	enableSpring: bool,
	/// The spring stiffness Hertz, cycles per second. This may be clamped internally
		/// according to the time step to maintain stability. Non-negative number.
	hertz: f32,
	/// The spring damping ratio, non-dimensional. Non-negative number.
	dampingRatio: f32,
	/// Target spring rotation, joint frame B relative to joint frame A.
	targetRotation: Quat,
	/// A flag to enable the cone limit. The cone is centered on the frameA z-axis.
	enableConeLimit: bool,
	/// The angle for the cone limit in radians. Valid range is [0, pi]
	coneAngle: f32,
	/// A flag to enable the twist limit. The twist is centered on the frameB z-axis.
	enableTwistLimit: bool,
	/// The angle for the lower twist limit in radians. Minimum of -0.99*pi radians.
	lowerTwistAngle: f32,
	/// The angle for the upper twist limit in radians. Maximum of 0.99*pi radians.
	upperTwistAngle: f32,
	/// A flag to enable the joint motor
	enableMotor: bool,
	/// The maximum motor torque, typically in newton-meters. Non-negative number.
	maxMotorTorque: f32,
	/// The desired motor angular velocity in radians per second.
	motorVelocity: Vec3,
}

/// Weld joint definition
/// Connects two bodies together rigidly. This constraint provides springs to mimic
/// soft-body simulation.
/// @note The approximate solver in Box3D cannot hold many bodies together rigidly
/// @ingroup weld_joint
WeldJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// Linear stiffness expressed as Hertz (cycles per second). Use zero for maximum stiffness.
	linearHertz: f32,
	/// Angular stiffness as Hertz (cycles per second). Use zero for maximum stiffness.
	angularHertz: f32,
	/// Linear damping ratio, non-dimensional. Use 1 for critical damping.
	linearDampingRatio: f32,
	/// Linear damping ratio, non-dimensional. Use 1 for critical damping.
	angularDampingRatio: f32,
}

/// Wheel joint definition
/// Body A is the chassis and body B is the wheel.
/// The wheel rotates around the local z-axis in frame B.
/// The wheel translates along the local x-axis in frame A.
/// The wheel can optionally steer along the x-axis in frame A.
/// @ingroup wheel_joint
WheelJointDef :: struct {
	/// Base joint definition
	base: JointDef,
	/// Enable a linear spring along the local axis
	enableSuspensionSpring: bool,
	/// Spring stiffness in Hertz
	suspensionHertz: f32,
	/// Spring damping ratio, non-dimensional
	suspensionDampingRatio: f32,
	/// Enable/disable the joint linear limit
	enableSuspensionLimit: bool,
	/// The lower suspension translation limit
	lowerSuspensionLimit: f32,
	/// The upper translation limit
	upperSuspensionLimit: f32,
	/// Enable/disable the joint rotational motor
	enableSpinMotor: bool,
	/// The maximum motor torque, typically in newton-meters
	maxSpinTorque: f32,
	/// The desired motor speed in radians per second
	spinSpeed: f32,
	/// Enable steering, otherwise the steering is fixed forward
	enableSteering: bool,
	/// Steering stiffness in Hertz
	steeringHertz: f32,
	/// Spring damping ratio, non-dimensional
	steeringDampingRatio: f32,
	/// The target steering angle in radians
	targetSteeringAngle: f32,
	/// The maximum steering torque in N*m
	maxSteeringTorque: f32,
	/// Enable/disable the steering angular limit
	enableSteeringLimit: bool,
	/// The lower steering angle in radians
	lowerSteeringLimit: f32,
	/// The upper steering angle in radians
	upperSteeringLimit: f32,
}

@(link_prefix = "b3")
foreign lib {
	/// Create a world for rigid body simulation. A world contains bodies, shapes, and constraints. You may create
	/// up to 128 worlds. Each world is completely independent and may be simulated in parallel.
	/// @return the world id.
	CreateWorld :: proc(def: ^WorldDef) -> WorldId ---
	/// Destroy a world
	DestroyWorld :: proc(worldId: WorldId) ---
	/// Get the current number of worlds
	GetWorldCount :: proc() -> i32 ---
	/// Get the maximum number of simultaneous worlds that have been created
	GetMaxWorldCount :: proc() -> i32 ---
	/// World id validation. Provides validation for up to 64K allocations.
	World_IsValid :: proc(id: WorldId) -> bool ---
	/// Simulate a world for one time step. This performs collision detection, integration, and constraint solution.
	/// @param worldId The world to simulate
	/// @param timeStep The amount of time to simulate, this should be a fixed number. Usually 1/60.
	/// @param subStepCount The number of sub-steps, increasing the sub-step count can increase accuracy. Usually 4.
	World_Step :: proc(worldId: WorldId, timeStep: f32, subStepCount: i32) ---
	/// Call this to draw shapes and other debug draw data
	World_Draw :: proc(worldId: WorldId, draw: ^DebugDraw, maskBits: u64) ---
	/// Get the world's bounds. This is the bounding box that covers the current simulation. May have a small
	/// amount of padding.
	World_GetBounds :: proc(worldId: WorldId) -> AABB ---
	/// Get the body events for the current time step. The event data is transient. Do not store a reference to this data.
	World_GetBodyEvents :: proc(worldId: WorldId) -> BodyEvents ---
	/// Get sensor events for the current time step. The event data is transient. Do not store a reference to this data.
	World_GetSensorEvents :: proc(worldId: WorldId) -> SensorEvents ---
	/// Get contact events for this current time step. The event data is transient. Do not store a reference to this data.
	World_GetContactEvents :: proc(worldId: WorldId) -> ContactEvents ---
	/// Get the joint events for the current time step. The event data is transient. Do not store a reference to this data.
	World_GetJointEvents :: proc(worldId: WorldId) -> JointEvents ---
	/// Overlap test for all shapes that *potentially* overlap the provided AABB
	World_OverlapAABB :: proc(worldId: WorldId, aabb: AABB, filter: QueryFilter, fcn: ^OverlapResultFcn, context_: rawptr) -> TreeStats ---
	/// Overlap test for all shapes that overlap the provided shape proxy. The proxy points are relative
	/// to the world origin, which lets the query stay precise far from the world origin.
	World_OverlapShape :: proc(worldId: WorldId, origin: Pos, proxy: ^ShapeProxy, filter: QueryFilter, fcn: ^OverlapResultFcn, context_: rawptr) -> TreeStats ---
	/// Cast a ray into the world to collect shapes in the path of the ray.
	/// Your callback function controls whether you get the closest point, any point, or n-points.
	/// @note The callback function may receive shapes in any order
	/// @param worldId The world to cast the ray against
	/// @param origin The start point of the ray
	/// @param translation The translation of the ray from the start point to the end point
	/// @param filter Contains bit flags to filter unwanted shapes from the results
	/// @param fcn A user implemented callback function
	/// @param context A user context that is passed along to the callback function
	///	@return traversal performance counters
	World_CastRay :: proc(worldId: WorldId, origin: Pos, translation: Vec3, filter: QueryFilter, fcn: ^CastResultFcn, context_: rawptr) -> TreeStats ---
	/// Cast a ray into the world to collect the closest hit. This is a convenience function. Ignores initial overlap.
	/// This is less general than b3World_CastRay() and does not allow for custom filtering.
	World_CastRayClosest :: proc(worldId: WorldId, origin: Pos, translation: Vec3, filter: QueryFilter) -> RayResult ---
	/// Cast a shape through the world. Similar to a cast ray except that a shape is cast instead of a point.
	/// The proxy points are relative to the origin and the hit points come back as world positions, so the
	/// cast stays precise far from the world origin.
	///	@see b3World_CastRay
	World_CastShape :: proc(worldId: WorldId, origin: Pos, proxy: ^ShapeProxy, translation: Vec3, filter: QueryFilter, fcn: ^CastResultFcn, context_: rawptr) -> TreeStats ---
	/// Cast a capsule mover through the world. This is a special shape cast that handles sliding along other shapes while reducing
	/// clipping. This is not a good source of information about what the mover is touching. Instead use the planes returned by
	/// b3World_CollideMover.
	/// @param worldId World to cast the mover against
	/// @param origin World position the mover capsule is relative to
	/// @param mover Capsule mover, relative to the origin
	/// @param translation Desired mover translation
	/// @param filter Contains bit flags to filter unwanted shapes from the results
	/// @param fcn Optional callback for custom shape filtering
	/// @param context A user context that is passed along to the callback function
	/// @return the translation fraction
	World_CastMover :: proc(worldId: WorldId, origin: Pos, mover: ^Capsule, translation: Vec3, filter: QueryFilter, fcn: ^MoverFilterFcn, context_: rawptr) -> f32 ---
	/// Collide a capsule mover with the world, gathering collision planes that can be fed to b3SolvePlanes. Useful for
	/// kinematic character movement. The mover and the returned planes are relative to the origin.
	World_CollideMover :: proc(worldId: WorldId, origin: Pos, mover: ^Capsule, filter: QueryFilter, fcn: ^PlaneResultFcn, context_: rawptr) ---
	/// Enable/disable sleep. If your application does not need sleeping, you can gain some performance
	/// by disabling sleep completely at the world level.
	/// @see b3WorldDef
	World_EnableSleeping :: proc(worldId: WorldId, flag: bool) ---
	/// Is body sleeping enabled?
	World_IsSleepingEnabled :: proc(worldId: WorldId) -> bool ---
	/// Enable/disable continuous collision between dynamic and static bodies. Generally you should keep continuous
	/// collision enabled to prevent fast moving objects from going through static objects. The performance gain from
	/// disabling continuous collision is minor.
	/// @see b3WorldDef
	World_EnableContinuous :: proc(worldId: WorldId, flag: bool) ---
	/// Is continuous collision enabled?
	World_IsContinuousEnabled :: proc(worldId: WorldId) -> bool ---
	/// Adjust the restitution threshold. It is recommended not to make this value very small
	/// because it will prevent bodies from sleeping. Usually in meters per second.
	/// @see b3WorldDef
	World_SetRestitutionThreshold :: proc(worldId: WorldId, value: f32) ---
	/// Get the restitution speed threshold. Usually in meters per second.
	World_GetRestitutionThreshold :: proc(worldId: WorldId) -> f32 ---
	/// Adjust the hit event threshold. This controls the collision speed needed to generate a b3ContactHitEvent.
	/// Usually in meters per second.
	/// @see b3WorldDef::hitEventThreshold
	World_SetHitEventThreshold :: proc(worldId: WorldId, value: f32) ---
	/// Get the hit event speed threshold. Usually in meters per second.
	World_GetHitEventThreshold :: proc(worldId: WorldId) -> f32 ---
	/// Register the custom filter callback. This is optional.
	World_SetCustomFilterCallback :: proc(worldId: WorldId, fcn: ^CustomFilterFcn, context_: rawptr) ---
	/// Register the pre-solve callback. This is optional.
	World_SetPreSolveCallback :: proc(worldId: WorldId, fcn: ^PreSolveFcn, context_: rawptr) ---
	/// Set the gravity vector for the entire world. Box3D has no concept of an up direction and this
	/// is left as a decision for the application. Usually in m/s^2.
	/// @see b3WorldDef
	World_SetGravity :: proc(worldId: WorldId, gravity: Vec3) ---
	/// Get the gravity vector
	World_GetGravity :: proc(worldId: WorldId) -> Vec3 ---
	/// Apply a radial explosion
	/// @param worldId The world id
	/// @param explosionDef The explosion definition
	World_Explode :: proc(worldId: WorldId, explosionDef: ^ExplosionDef) ---
	/// Adjust contact tuning parameters
	/// @param worldId The world id
	/// @param hertz The contact stiffness (cycles per second)
	/// @param dampingRatio The contact bounciness with 1 being critical damping (non-dimensional)
	/// @param contactSpeed The maximum contact constraint push out speed (meters per second)
	/// @note Advanced feature
	World_SetContactTuning :: proc(worldId: WorldId, hertz: f32, dampingRatio: f32, contactSpeed: f32) ---
	/// Set the contact point recycling distance. Setting this to zero disables contact point recycling.
	/// Usually in meters.
	World_SetContactRecycleDistance :: proc(worldId: WorldId, recycleDistance: f32) ---
	/// Get the contact point recycling distance. Usually in meters.
	World_GetContactRecycleDistance :: proc(worldId: WorldId) -> f32 ---
	/// Set the maximum linear speed. Usually in m/s.
	World_SetMaximumLinearSpeed :: proc(worldId: WorldId, maximumLinearSpeed: f32) ---
	/// Get the maximum linear speed. Usually in m/s.
	World_GetMaximumLinearSpeed :: proc(worldId: WorldId) -> f32 ---
	/// Enable/disable constraint warm starting. Advanced feature for testing. Disabling
	/// warm starting greatly reduces stability and provides no performance gain.
	World_EnableWarmStarting :: proc(worldId: WorldId, flag: bool) ---
	/// Is constraint warm starting enabled?
	World_IsWarmStartingEnabled :: proc(worldId: WorldId) -> bool ---
	/// Get the number of awake bodies
	World_GetAwakeBodyCount :: proc(worldId: WorldId) -> i32 ---
	/// Get the current world performance profile
	World_GetProfile :: proc(worldId: WorldId) -> Profile ---
	/// Get world counters and sizes
	World_GetCounters :: proc(worldId: WorldId) -> Counters ---
	/// Get max capacity. This can be used with b3WorldDef to avoid run-time allocations and copies
	World_GetMaxCapacity :: proc(worldId: WorldId) -> Capacity ---
	/// Set the user data pointer.
	World_SetUserData :: proc(worldId: WorldId, userData: rawptr) ---
	/// Get the user data pointer.
	World_GetUserData :: proc(worldId: WorldId) -> rawptr ---
	/// Set the friction callback. Passing NULL resets to default.
	World_SetFrictionCallback :: proc(worldId: WorldId, callback: ^FrictionCallback) ---
	/// Set the restitution callback. Passing NULL resets to default.
	World_SetRestitutionCallback :: proc(worldId: WorldId, callback: ^RestitutionCallback) ---
	/// Set the worker count. Must be in the range [1, B3_MAX_WORKERS]
	World_SetWorkerCount :: proc(worldId: WorldId, count: i32) ---
	/// Get the worker count.
	World_GetWorkerCount :: proc(worldId: WorldId) -> i32 ---
	/// Dump memory stats to log.
	World_DumpMemoryStats :: proc(worldId: WorldId) ---
	/// Dump shape bounds to box3d_bounds.txt
	World_DumpShapeBounds :: proc(worldId: WorldId, type: BodyType) ---
	/// This is for internal testing
	World_RebuildStaticTree :: proc(worldId: WorldId) ---
	/// This is for internal testing
	World_EnableSpeculative :: proc(worldId: WorldId, flag: bool) ---
	/// Create a recording buffer with an optional initial byte capacity.
	/// Pass 0 to use the default (64 KiB). The buffer grows on demand.
	/// @return a new recording, owned by the caller
	CreateRecording :: proc(byteCapacity: i32) -> Recording ---
	/// Destroy a recording and free its buffer.
	/// @param recording may be NULL
	DestroyRecording :: proc(recording: Recording) ---
	/// Get a pointer to the raw recording bytes.
	/// Valid until the recording buffer is modified or destroyed.
	/// @param recording the recording handle
	/// @return pointer to the byte buffer, or NULL if no bytes have been written
	Recording_GetData :: proc(recording: Recording) -> ^u8 ---
	/// Get the number of bytes currently in the recording buffer.
	/// @param recording the recording handle
	Recording_GetSize :: proc(recording: Recording) -> i32 ---
	/// Begin recording world mutations into the provided buffer.
	/// The buffer is reset on each call so a single b3Recording can be reused for multiple sessions.
	/// @param worldId the world to record
	/// @param recording the recording handle to write into
	World_StartRecording :: proc(worldId: WorldId, recording: Recording) ---
	/// End the current recording session. Writes the trailing geometry registry and
	/// backpatches the header. The buffer remains valid until the recording is destroyed.
	/// @param worldId the world currently being recorded
	World_StopRecording :: proc(worldId: WorldId) ---
	/// Save the recording buffer to a file. Returns true on success.
	/// @param recording the recording to save
	/// @param path file path to write
	SaveRecordingToFile :: proc(recording: Recording, path: cstring) -> bool ---
	/// Load a recording from a file. Returns NULL on failure (file not found, wrong magic).
	/// The caller owns the returned recording and must destroy it with b3DestroyRecording.
	/// @param path file path to read
	LoadRecordingFromFile :: proc(path: cstring) -> Recording ---
	/// Replay a recording from memory and verify it reproduces the same world-state hashes.
	/// Stands up a fresh world, restores the seed snapshot, replays every op, and checks each embedded
	/// StateHash record. Returns true if replay completed without id mismatches or hash divergences.
	/// @param data pointer to recording bytes
	/// @param size byte count of the recording
	/// @param workerCount reserved for future multithreaded replay; pass 1 for now
	ValidateReplay :: proc(data: rawptr, size: i32, workerCount: i32) -> bool ---
	/// Create a player over a recording. Owns a private copy of the bytes.
	/// @param data pointer to recording bytes
	/// @param size byte count of the recording
	/// @param workerCount worker count for the replay world; pass 1 to match a serial recording.
	/// Replaying at a different count re-partitions the constraint graph, so the StateHash check
	/// becomes a cross-thread determinism test. Adjustable later with b3RecPlayer_SetWorkerCount.
	/// @return a new player, or NULL on bad header or deserialization failure
	RecPlayer_Create :: proc(data: rawptr, size: i32, workerCount: i32) -> RecPlayer ---
	/// Destroy the player and free all memory. Restores the previous global length scale.
	RecPlayer_Destroy :: proc(player: RecPlayer) ---
	/// Advance one frame. dispatch ops until the next Step completes.
	/// @return true when a frame was stepped, false at end-of-recording
	RecPlayer_StepFrame :: proc(player: RecPlayer) -> bool ---
	/// Sub-step one frame. This will sub-step and return immediately after body creation.
	/// The next call will execute the time step. This allows bodies to be rendered
	/// at the creation pose.
	RecPlayer_SubStepFrame :: proc(player: RecPlayer) ---
	/// Rewind to frame 0 (in-place restore so the world id stays stable).
	RecPlayer_Restart :: proc(player: RecPlayer) ---
	/// Seek to a specific frame. Forward seek steps op-by-op; backward seek restores
	/// the nearest keyframe then re-steps the remaining gap.
	RecPlayer_SeekFrame :: proc(player: RecPlayer, targetFrame: i32) ---
	/// @return the world currently driven by this player
	RecPlayer_GetWorldId :: proc(player: RecPlayer) -> WorldId ---
	/// @return the last fully-stepped frame index (0 before any step)
	RecPlayer_GetFrame :: proc(player: RecPlayer) -> i32 ---
	/// @return total number of recorded frames
	RecPlayer_GetFrameCount :: proc(player: RecPlayer) -> i32 ---
	/// @return true when the op stream is exhausted
	RecPlayer_IsAtEnd :: proc(player: RecPlayer) -> bool ---
	/// @return true when the op stream is paused between body creation and world step.
	RecPlayer_IsAtPreStep :: proc(player: RecPlayer) -> bool ---
	/// @return true when any StateHash mismatch has been detected
	RecPlayer_HasDiverged :: proc(player: RecPlayer) -> bool ---
	/// @return a summary of the recording read at open: frame count, recorded tuning, and bounds
	RecPlayer_GetInfo :: proc(player: RecPlayer) -> RecPlayerInfo ---
	/// @return the first frame at which replay diverged, or -1 if it has not diverged
	RecPlayer_GetDivergeFrame :: proc(player: RecPlayer) -> i32 ---
	/// Set the worker count of the replay world. Clamped to [1, B3_MAX_WORKERS]. Applied to the live
	/// world at once and reused whenever the player rebuilds its world on Restart or a backward seek.
	/// Replaying at a different count than recorded re-partitions the constraint graph, so the StateHash
	/// check becomes a cross-thread determinism test.
	RecPlayer_SetWorkerCount :: proc(player: RecPlayer, count: i32) ---
	/// Tune the keyframe ring used to speed up backward seeking. A keyframe is a periodic snapshot the
	/// player restores from instead of replaying from the start, trading memory for seek speed.
	/// @param player the recording player
	/// @param budgetBytes memory cap for the kept snapshots; the spacing widens to stay under it
	/// @param minIntervalFrames finest spacing between keyframes, in frames
	/// A zero budget or a non-positive interval keeps that value. Clears the existing ring, so call
	/// b3RecPlayer_Restart afterward to repopulate it under the new policy.
	RecPlayer_SetKeyframePolicy :: proc(player: RecPlayer, budgetBytes: uint, minIntervalFrames: i32) ---
	/// @return the keyframe memory budget in bytes
	RecPlayer_GetKeyframeBudget :: proc(player: RecPlayer) -> uint ---
	/// @return the finest keyframe spacing in frames
	RecPlayer_GetKeyframeMinInterval :: proc(player: RecPlayer) -> i32 ---
	/// @return the current keyframe spacing in frames; starts at the min interval and doubles as the
	/// ring evicts to stay under budget, so it reflects the effective backward-seek granularity now
	RecPlayer_GetKeyframeInterval :: proc(player: RecPlayer) -> i32 ---
	/// @return the memory currently held by keyframe snapshots, in bytes
	RecPlayer_GetKeyframeBytes :: proc(player: RecPlayer) -> uint ---
	/// @return the number of bodies tracked in creation order (including holes for destroyed bodies)
	RecPlayer_GetBodyCount :: proc(player: RecPlayer) -> i32 ---
	/// Resolve a creation ordinal to the live body id at the current frame.
	/// @return the body id, or a null id if that ordinal is out of range or its body is destroyed
	RecPlayer_GetBodyId :: proc(player: RecPlayer, index: i32) -> BodyId ---
	/// Wire host debug-shape callbacks into the player's replay world so a renderer can build
	/// per-shape draw resources (the 3D sample needs this or the replay world draws nothing).
	/// Rebuilds the current world under the new callbacks and rewinds to frame 0, so call it
	/// once right after b3RecPlayer_Create and re-read the world id afterward. The callbacks
	/// persist across Restart and backward seeks, which recreate the world internally.
	/// @param player the player to configure
	/// @param createDebugShape called when a replayed shape is added; returns a user draw handle
	/// @param destroyDebugShape called when a replayed shape is removed; may be NULL
	/// @param context user context passed to both callbacks
	RecPlayer_SetDebugShapeCallbacks :: proc(player: RecPlayer, createDebugShape: ^CreateDebugShapeCallback, destroyDebugShape: ^DestroyDebugShapeCallback, context_: rawptr) ---
	/// Draw the spatial queries recorded during the most recently replayed frame, layered on top of the
	/// world. Call after b3World_Draw. NULL draw function pointers are skipped.
	/// @param player a valid player handle
	/// @param draw debug draw callbacks
	/// @param queryIndex index of the frame query to draw, or -1 to draw all of them
	/// @param selectedIndex index of the query to emphasize (reserved color plus a label), or -1 for none
	RecPlayer_DrawFrameQueries :: proc(player: RecPlayer, draw: ^DebugDraw, queryIndex: i32, selectedIndex: i32) ---
	/// @return the number of spatial queries recorded for the most recently replayed frame
	RecPlayer_GetFrameQueryCount :: proc(player: RecPlayer) -> i32 ---
	/// Get a recorded query from the most recently replayed frame by index.
	RecPlayer_GetFrameQuery :: proc(player: RecPlayer, index: i32) -> RecQueryInfo ---
	/// Get one result of a recorded query from the most recently replayed frame.
	RecPlayer_GetFrameQueryHit :: proc(player: RecPlayer, queryIndex: i32, hitIndex: i32) -> RecQueryHit ---
	/// Create a rigid body given a definition. No reference to the definition is retained. So you can create the definition
	/// on the stack and pass it as a pointer.
	/// @code{.c}
	/// b3BodyDef bodyDef = b3DefaultBodyDef();
	/// b3BodyId myBodyId = b3CreateBody(myWorldId, &bodyDef);
	/// @endcode
	/// @warning This function is locked during callbacks.
	CreateBody :: proc(worldId: WorldId, def: ^BodyDef) -> BodyId ---
	/// Destroy a rigid body given an id. This destroys all shapes and joints attached to the body.
	/// Do not keep references to the associated shapes and joints.
	DestroyBody :: proc(bodyId: BodyId) ---
	/// Body identifier validation. A valid body exists in a world and is non-null.
	/// This can be used to detect orphaned ids. Provides validation for up to 64K allocations.
	Body_IsValid :: proc(id: BodyId) -> bool ---
	/// Get the body type: static, kinematic, or dynamic
	Body_GetType :: proc(bodyId: BodyId) -> BodyType ---
	/// Change the body type. This is an expensive operation. This automatically updates the mass
	/// properties regardless of the automatic mass setting.
	Body_SetType :: proc(bodyId: BodyId, type: BodyType) ---
	/// Set the body name.
	Body_SetName :: proc(bodyId: BodyId, name: cstring) ---
	/// Get the body name. Returns an empty string if the name isn't set.
	Body_GetName :: proc(bodyId: BodyId) -> cstring ---
	/// Set the user data for a body
	Body_SetUserData :: proc(bodyId: BodyId, userData: rawptr) ---
	/// Get the user data stored in a body
	Body_GetUserData :: proc(bodyId: BodyId) -> rawptr ---
	/// Get the world position of a body. This is the location of the body origin.
	Body_GetPosition :: proc(bodyId: BodyId) -> Pos ---
	/// Get the world rotation of a body as a quaternion
	Body_GetRotation :: proc(bodyId: BodyId) -> Quat ---
	/// Get the world transform of a body.
	Body_GetTransform :: proc(bodyId: BodyId) -> WorldTransform ---
	/// Set the world transform of a body. This acts as a teleport and is fairly expensive.
	/// @note Generally you should create a body with the intended transform.
	/// @see b3BodyDef::position and b3BodyDef::rotation
	Body_SetTransform :: proc(bodyId: BodyId, position: Pos, rotation: Quat) ---
	/// Get a local point on a body given a world point
	Body_GetLocalPoint :: proc(bodyId: BodyId, worldPoint: Pos) -> Vec3 ---
	/// Get a world point on a body given a local point
	Body_GetWorldPoint :: proc(bodyId: BodyId, localPoint: Vec3) -> Pos ---
	/// Get a local vector on a body given a world vector
	Body_GetLocalVector :: proc(bodyId: BodyId, worldVector: Vec3) -> Vec3 ---
	/// Get a world vector on a body given a local vector
	Body_GetWorldVector :: proc(bodyId: BodyId, localVector: Vec3) -> Vec3 ---
	/// Get the linear velocity of a body's center of mass. Usually in meters per second.
	Body_GetLinearVelocity :: proc(bodyId: BodyId) -> Vec3 ---
	/// Get the angular velocity of a body in radians per second
	Body_GetAngularVelocity :: proc(bodyId: BodyId) -> Vec3 ---
	/// Set the linear velocity of a body. Usually in meters per second.
	Body_SetLinearVelocity :: proc(bodyId: BodyId, linearVelocity: Vec3) ---
	/// Set the angular velocity of a body in radians per second
	Body_SetAngularVelocity :: proc(bodyId: BodyId, angularVelocity: Vec3) ---
	/// Set the velocity to reach the given transform after a given time step.
	/// The result will be close but maybe not exact. This is meant for kinematic bodies.
	/// The target is not applied if the velocity would be below the sleep threshold.
	/// This will optionally wake the body if asleep, but only if the movement is significant.
	Body_SetTargetTransform :: proc(bodyId: BodyId, target: WorldTransform, timeStep: f32, wake: bool) ---
	/// Get the linear velocity of a local point attached to a body. Usually in meters per second.
	Body_GetLocalPointVelocity :: proc(bodyId: BodyId, localPoint: Vec3) -> Vec3 ---
	/// Get the linear velocity of a world point attached to a body. Usually in meters per second.
	Body_GetWorldPointVelocity :: proc(bodyId: BodyId, worldPoint: Pos) -> Vec3 ---
	/// Apply a force at a world point. If the force is not applied at the center of mass,
	/// it will generate a torque and affect the angular velocity. This optionally wakes up the body.
	/// The force is ignored if the body is not awake.
	/// @param bodyId The body id
	/// @param force The world force vector, usually in newtons (N)
	/// @param point The world position of the point of application
	/// @param wake Option to wake up the body
	Body_ApplyForce :: proc(bodyId: BodyId, force: Vec3, point: Pos, wake: bool) ---
	/// Apply a force to the center of mass. This optionally wakes up the body.
	/// The force is ignored if the body is not awake.
	/// @param bodyId The body id
	/// @param force the world force vector, usually in newtons (N).
	/// @param wake also wake up the body
	Body_ApplyForceToCenter :: proc(bodyId: BodyId, force: Vec3, wake: bool) ---
	/// Apply a torque. This affects the angular velocity without affecting the linear velocity.
	/// This optionally wakes the body. The torque is ignored if the body is not awake.
	/// @param bodyId The body id
	/// @param torque the world torque vector, usually in N*m.
	/// @param wake also wake up the body
	Body_ApplyTorque :: proc(bodyId: BodyId, torque: Vec3, wake: bool) ---
	/// Apply an impulse at a point. This immediately modifies the velocity.
	/// It also modifies the angular velocity if the point of application
	/// is not at the center of mass. This optionally wakes the body.
	/// The impulse is ignored if the body is not awake.
	/// @param bodyId The body id
	/// @param impulse the world impulse vector, usually in N*s or kg*m/s.
	/// @param point the world position of the point of application.
	/// @param wake also wake up the body
	/// @warning This should be used for one-shot impulses. If you need a steady force,
	/// use a force instead, which will work better with the sub-stepping solver.
	Body_ApplyLinearImpulse :: proc(bodyId: BodyId, impulse: Vec3, point: Pos, wake: bool) ---
	/// Apply an impulse to the center of mass. This immediately modifies the velocity.
	/// The impulse is ignored if the body is not awake. This optionally wakes the body.
	/// @param bodyId The body id
	/// @param impulse the world impulse vector, usually in N*s or kg*m/s.
	/// @param wake also wake up the body
	/// @warning This should be used for one-shot impulses. If you need a steady force,
	/// use a force instead, which will work better with the sub-stepping solver.
	Body_ApplyLinearImpulseToCenter :: proc(bodyId: BodyId, impulse: Vec3, wake: bool) ---
	/// Apply an angular impulse in world space. The impulse is ignored if the body is not awake.
	/// This optionally wakes the body.
	/// @param bodyId The body id
	/// @param impulse the world angular impulse vector, usually in units of kg*m*m/s
	/// @param wake also wake up the body
	/// @warning This should be used for one-shot impulses. If you need a steady torque,
	/// use a torque instead, which will work better with the sub-stepping solver.
	Body_ApplyAngularImpulse :: proc(bodyId: BodyId, impulse: Vec3, wake: bool) ---
	/// Get the mass of the body, usually in kilograms
	Body_GetMass :: proc(bodyId: BodyId) -> f32 ---
	/// Get the rotational inertia of the body in local space, usually in kg*m^2
	Body_GetLocalRotationalInertia :: proc(bodyId: BodyId) -> Matrix3 ---
	/// Get the inverse mass of the body, usually in 1/kilograms
	Body_GetInverseMass :: proc(bodyId: BodyId) -> f32 ---
	/// Get the inverse rotational inertia of the body in world space, usually in 1/kg*m^2
	Body_GetWorldInverseRotationalInertia :: proc(bodyId: BodyId) -> Matrix3 ---
	/// Get the center of mass position of the body in local space
	Body_GetLocalCenter :: proc(bodyId: BodyId) -> Vec3 ---
	/// Get the center of mass position of the body in world space
	Body_GetWorldCenter :: proc(bodyId: BodyId) -> Pos ---
	/// Override the body's mass properties. Normally this is computed automatically using the
	/// shape geometry and density. This information is lost if a shape is added or removed or if the
	/// body type changes.
	Body_SetMassData :: proc(bodyId: BodyId, massData: MassData) ---
	/// Get the mass data for a body
	Body_GetMassData :: proc(bodyId: BodyId) -> MassData ---
	/// This updates the mass properties to the sum of the mass properties of the shapes.
	/// This normally does not need to be called unless you called SetMassData to override
	/// the mass and you later want to reset the mass.
	/// You may also use this when automatic mass computation has been disabled.
	/// You should call this regardless of body type.
	Body_ApplyMassFromShapes :: proc(bodyId: BodyId) ---
	/// Adjust the linear damping. Normally this is set in b3BodyDef before creation.
	Body_SetLinearDamping :: proc(bodyId: BodyId, linearDamping: f32) ---
	/// Get the current linear damping.
	Body_GetLinearDamping :: proc(bodyId: BodyId) -> f32 ---
	/// Adjust the angular damping. Normally this is set in b3BodyDef before creation.
	Body_SetAngularDamping :: proc(bodyId: BodyId, angularDamping: f32) ---
	/// Get the current angular damping.
	Body_GetAngularDamping :: proc(bodyId: BodyId) -> f32 ---
	/// Adjust the gravity scale. Normally this is set in b3BodyDef before creation.
	/// @see b3BodyDef::gravityScale
	Body_SetGravityScale :: proc(bodyId: BodyId, gravityScale: f32) ---
	/// Get the current gravity scale
	Body_GetGravityScale :: proc(bodyId: BodyId) -> f32 ---
	/// @return true if this body is awake
	Body_IsAwake :: proc(bodyId: BodyId) -> bool ---
	/// Wake a body from sleep. This wakes the entire island the body is touching.
	/// @warning Putting a body to sleep will put the entire island of bodies touching this body to sleep,
	/// which can be expensive and possibly unintuitive.
	Body_SetAwake :: proc(bodyId: BodyId, awake: bool) ---
	/// Enable or disable sleeping for this body. If sleeping is disabled the body will wake.
	Body_EnableSleep :: proc(bodyId: BodyId, enableSleep: bool) ---
	/// Returns true if sleeping is enabled for this body
	Body_IsSleepEnabled :: proc(bodyId: BodyId) -> bool ---
	/// Set the sleep threshold, usually in meters per second
	Body_SetSleepThreshold :: proc(bodyId: BodyId, sleepThreshold: f32) ---
	/// Get the sleep threshold, usually in meters per second.
	Body_GetSleepThreshold :: proc(bodyId: BodyId) -> f32 ---
	/// Returns true if this body is enabled
	Body_IsEnabled :: proc(bodyId: BodyId) -> bool ---
	/// Disable a body by removing it completely from the simulation. This is expensive.
	Body_Disable :: proc(bodyId: BodyId) ---
	/// Enable a body by adding it to the simulation. This is expensive.
	Body_Enable :: proc(bodyId: BodyId) ---
	/// Set the motion locks on this body.
	Body_SetMotionLocks :: proc(bodyId: BodyId, locks: MotionLocks) ---
	/// Get the motion locks for this body.
	Body_GetMotionLocks :: proc(bodyId: BodyId) -> MotionLocks ---
	/// Set this body to be a bullet. A bullet does continuous collision detection
	/// against dynamic bodies (but not other bullets).
	Body_SetBullet :: proc(bodyId: BodyId, flag: bool) ---
	/// Is this body a bullet?
	Body_IsBullet :: proc(bodyId: BodyId) -> bool ---
	/// Enable or disable contact recycling for this body. Contact recycling is a performance optimization
	/// that reuses contact manifolds when bodies move slightly. Disabling it can avoid ghost collisions
	/// on characters at the cost of higher per-step work. Existing contacts retain their prior setting;
	/// only contacts created after this call see the new value.
	/// @see b3BodyDef::enableContactRecycling
	Body_EnableContactRecycling :: proc(bodyId: BodyId, flag: bool) ---
	/// Is contact recycling enabled on this body?
	Body_IsContactRecyclingEnabled :: proc(bodyId: BodyId) -> bool ---
	/// Enable/disable hit events on all shapes
	/// @see b3ShapeDef::enableHitEvents
	Body_EnableHitEvents :: proc(bodyId: BodyId, flag: bool) ---
	/// Get the world that owns this body
	Body_GetWorld :: proc(bodyId: BodyId) -> WorldId ---
	/// Get the number of shapes on this body
	Body_GetShapeCount :: proc(bodyId: BodyId) -> i32 ---
	/// Get the shape ids for all shapes on this body, up to the provided capacity.
	/// @returns the number of shape ids stored in the user array
	Body_GetShapes :: proc(bodyId: BodyId, shapeArray: ^ShapeId, capacity: i32) -> i32 ---
	/// Get the number of joints on this body
	Body_GetJointCount :: proc(bodyId: BodyId) -> i32 ---
	/// Get the joint ids for all joints on this body, up to the provided capacity
	/// @returns the number of joint ids stored in the user array
	Body_GetJoints :: proc(bodyId: BodyId, jointArray: ^JointId, capacity: i32) -> i32 ---
	/// Get the maximum capacity required for retrieving all the touching contacts on a body
	Body_GetContactCapacity :: proc(bodyId: BodyId) -> i32 ---
	/// Get the touching contact data for a body
	Body_GetContactData :: proc(bodyId: BodyId, contactData: ^ContactData, capacity: i32) -> i32 ---
	/// Get the current world AABB that contains all the attached shapes. Note that this may not encompass the body origin.
	/// If there are no shapes attached then the returned AABB is empty and centered on the body origin.
	Body_ComputeAABB :: proc(bodyId: BodyId) -> AABB ---
	/// Get the closest point on a body to a world target.
	Body_GetClosestPoint :: proc(bodyId: BodyId, result: ^Vec3, target: Vec3) -> f32 ---
	/// Cast a ray at a specific body using a specified body transform.
	Body_CastRay :: proc(bodyId: BodyId, origin: Pos, translation: Vec3, filter: QueryFilter, maxFraction: f32, bodyTransform: WorldTransform) -> BodyCastResult ---
	/// Cast a shape at a specific body using a specified body transform.
	Body_CastShape :: proc(bodyId: BodyId, origin: Pos, proxy: ^ShapeProxy, translation: Vec3, filter: QueryFilter, maxFraction: f32, canEncroach: bool, bodyTransform: WorldTransform) -> BodyCastResult ---
	/// Overlap a shape with a specific body using a specified body transform.
	Body_OverlapShape :: proc(bodyId: BodyId, origin: Pos, proxy: ^ShapeProxy, filter: QueryFilter, bodyTransform: WorldTransform) -> bool ---
	/// Collide a character mover with a specific body using a specified body transform.
	Body_CollideMover :: proc(bodyId: BodyId, bodyPlanes: ^BodyPlaneResult, planeCapacity: i32, origin: Pos, mover: ^Capsule, filter: QueryFilter, bodyTransform: WorldTransform) -> i32 ---
	/// Create a circle shape and attach it to a body. The shape definition and geometry are fully cloned.
	/// Contacts are not created until the next time step.
	/// @return the shape id for accessing the shape
	CreateSphereShape :: proc(bodyId: BodyId, def: ^ShapeDef, sphere: ^Sphere) -> ShapeId ---
	/// Create a capsule shape and attach it to a body. The shape definition and geometry are fully cloned.
	/// Contacts are not created until the next time step.
	/// @return the shape id for accessing the shape
	CreateCapsuleShape :: proc(bodyId: BodyId, def: ^ShapeDef, capsule: ^Capsule) -> ShapeId ---
	/// Create a convex hull shape and attach it to a body. The shape definition is fully cloned. Contacts are not created
	/// until the next time step.
	/// @return the shape id for accessing the shape
	CreateHullShape :: proc(bodyId: BodyId, def: ^ShapeDef, hull: ^HullData) -> ShapeId ---
	/// Create a convex hull shape and attach it to a body. The hull is cloned then transformed with scale applied first.
	/// Use this for non-uniform or mirrored scale or a baked local transform. The baked result is shared through the
	/// world hull database. The shape definition and geometry are fully cloned. Contacts are not created until the next time step.
	/// @return the shape id for accessing the shape
	CreateTransformedHullShape :: proc(bodyId: BodyId, def: ^ShapeDef, hull: ^HullData, transform: Transform, scale: Vec3) -> ShapeId ---
	/// Create a mesh hull shape and attach it to a body. The shape definition is fully cloned but the mesh is not.
	/// Contacts are not created until the next time step.
	/// Mesh collision only creates contacts on static bodies.
	/// @warning this holds reference to the input mesh data which must remain valid for the lifetime of this shape
	/// @return the shape id for accessing the shape
	CreateMeshShape :: proc(bodyId: BodyId, def: ^ShapeDef, mesh: ^MeshData, scale: Vec3) -> ShapeId ---
	/// Create a height-field shape and attach it to a body. The shape definition is fully cloned but the height field is not.
	/// Contacts are not created until the next time step.
	/// Height field is only allowed on static bodies.
	/// @warning this holds reference to the input height field which must remain valid for the lifetime of this shape
	/// @return the shape id for accessing the shape
	CreateHeightFieldShape :: proc(bodyId: BodyId, def: ^ShapeDef, heightField: ^HeightFieldData) -> ShapeId ---
	/// Compound shapes are only allowed on static bodies.
	CreateCompoundShape :: proc(bodyId: BodyId, def: ^ShapeDef, compound: ^CompoundData) -> ShapeId ---
	/// Destroy a shape. You may defer the body mass update which can improve performance if several shapes on a
	///	body are destroyed at once.
	///	@see b3Body_ApplyMassFromShapes
	DestroyShape :: proc(shapeId: ShapeId, updateBodyMass: bool) ---
	/// Shape identifier validation. Provides validation for up to 64K allocations.
	Shape_IsValid :: proc(id: ShapeId) -> bool ---
	/// Get the type of a shape
	Shape_GetType :: proc(shapeId: ShapeId) -> ShapeType ---
	/// Get the id of the body that a shape is attached to
	Shape_GetBody :: proc(shapeId: ShapeId) -> BodyId ---
	/// Get the world that owns this shape
	Shape_GetWorld :: proc(shapeId: ShapeId) -> WorldId ---
	/// Returns true if the shape is a sensor
	Shape_IsSensor :: proc(shapeId: ShapeId) -> bool ---
	/// Set the shape name.
	Shape_SetName :: proc(shapeId: ShapeId, name: cstring) ---
	/// Get the shape name. Returns an empty string if the name isn't set.
	Shape_GetName :: proc(shapeId: ShapeId) -> cstring ---
	/// Set the user data for a shape
	Shape_SetUserData :: proc(shapeId: ShapeId, userData: rawptr) ---
	/// Get the user data for a shape. This is useful when you get a shape id
	/// from an event or query.
	Shape_GetUserData :: proc(shapeId: ShapeId) -> rawptr ---
	/// Set the mass density of a shape, usually in kg/m^3.
	/// This will optionally update the mass properties on the parent body.
	/// @see b3ShapeDef::density, b3Body_ApplyMassFromShapes
	Shape_SetDensity :: proc(shapeId: ShapeId, density: f32, updateBodyMass: bool) ---
	/// Get the density of a shape, usually in kg/m^3
	Shape_GetDensity :: proc(shapeId: ShapeId) -> f32 ---
	/// Set the friction on a shape
	Shape_SetFriction :: proc(shapeId: ShapeId, friction: f32) ---
	/// Get the friction of a shape
	Shape_GetFriction :: proc(shapeId: ShapeId) -> f32 ---
	/// Set the shape restitution (bounciness)
	Shape_SetRestitution :: proc(shapeId: ShapeId, restitution: f32) ---
	/// Get the shape restitution
	Shape_GetRestitution :: proc(shapeId: ShapeId) -> f32 ---
	/// Set the shape base surface material. Does not change per triangle materials.
	Shape_SetSurfaceMaterial :: proc(shapeId: ShapeId, surfaceMaterial: SurfaceMaterial) ---
	/// Get the base shape surface material.
	Shape_GetSurfaceMaterial :: proc(shapeId: ShapeId) -> SurfaceMaterial ---
	/// Get the number of mesh surface materials.
	Shape_GetMeshMaterialCount :: proc(shapeId: ShapeId) -> i32 ---
	/// Set a surface material for a mesh shape.
	Shape_SetMeshMaterial :: proc(shapeId: ShapeId, surfaceMaterial: SurfaceMaterial, index: i32) ---
	/// Get a surface material for a mesh shape
	Shape_GetMeshSurfaceMaterial :: proc(shapeId: ShapeId, index: i32) -> SurfaceMaterial ---
	/// Get the shape filter
	Shape_GetFilter :: proc(shapeId: ShapeId) -> Filter ---
	/// Set the current filter. This is almost as expensive as recreating the shape.
	/// @see b3ShapeDef::filter
	/// @param shapeId the shape
	/// @param filter the new filter
	/// @param invokeContacts if true then the shape will have all contacts recomputed the next time step (expensive)
	Shape_SetFilter :: proc(shapeId: ShapeId, filter: Filter, invokeContacts: bool) ---
	/// Enable sensor events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
	/// @see b3ShapeDef::isSensor
	Shape_EnableSensorEvents :: proc(shapeId: ShapeId, flag: bool) ---
	/// Returns true if sensor events are enabled
	Shape_AreSensorEventsEnabled :: proc(shapeId: ShapeId) -> bool ---
	/// Enable contact events for this shape. Only applies to kinematic and dynamic bodies. Ignored for sensors.
	/// @see b3ShapeDef::enableContactEvents
	Shape_EnableContactEvents :: proc(shapeId: ShapeId, flag: bool) ---
	/// Returns true if contact events are enabled
	Shape_AreContactEventsEnabled :: proc(shapeId: ShapeId) -> bool ---
	/// Enable pre-solve contact events for this shape. Only applies to dynamic bodies. These are expensive
	/// and must be carefully handled due to multithreading. Ignored for sensors.
	/// @see b3PreSolveFcn
	Shape_EnablePreSolveEvents :: proc(shapeId: ShapeId, flag: bool) ---
	/// Returns true if pre-solve events are enabled
	Shape_ArePreSolveEventsEnabled :: proc(shapeId: ShapeId) -> bool ---
	/// Enable contact hit events for this shape. Ignored for sensors.
	/// @see b3WorldDef.hitEventThreshold
	Shape_EnableHitEvents :: proc(shapeId: ShapeId, flag: bool) ---
	/// Returns true if hit events are enabled
	Shape_AreHitEventsEnabled :: proc(shapeId: ShapeId) -> bool ---
	/// Ray cast a shape directly. The ray runs from origin to origin + translation and the hit point
	/// comes back as a world position, so the cast stays precise far from the world origin.
	Shape_RayCast :: proc(shapeId: ShapeId, origin: Pos, translation: Vec3) -> WorldCastOutput ---
	/// Get a copy of the shape's sphere. Asserts the type is correct.
	Shape_GetSphere :: proc(shapeId: ShapeId) -> Sphere ---
	/// Get a copy of the shape's capsule. Asserts the type is correct.
	Shape_GetCapsule :: proc(shapeId: ShapeId) -> Capsule ---
	/// Get the shape's convex hull. Asserts the type is correct.
	Shape_GetHull :: proc(shapeId: ShapeId) -> ^HullData ---
	/// Get the shape's mesh. Asserts the type is correct.
	Shape_GetMesh :: proc(shapeId: ShapeId) -> Mesh ---
	/// Get the shape's height field. Asserts the type is correct.
	Shape_GetHeightField :: proc(shapeId: ShapeId) -> ^HeightFieldData ---
	/// Allows you to change a shape to be a sphere or update the current sphere.
	/// This does not modify the mass properties.
	/// @see b3Body_ApplyMassFromShapes
	Shape_SetSphere :: proc(shapeId: ShapeId, sphere: ^Sphere) ---
	/// Allows you to change a shape to be a capsule or update the current capsule.
	/// This does not modify the mass properties.
	/// @see b3Body_ApplyMassFromShapes
	Shape_SetCapsule :: proc(shapeId: ShapeId, capsule: ^Capsule) ---
	/// Allows you to change a shape to be a hull or update the current hull.
	/// This does not modify the mass properties.
	/// @see b3Body_ApplyMassFromShapes
	Shape_SetHull :: proc(shapeId: ShapeId, hull: ^HullData) ---
	/// Allows you to change a shape to be a mesh or update the current mesh.
	/// This does not modify the mass properties.
	/// @see b3Body_ApplyMassFromShapes
	Shape_SetMesh :: proc(shapeId: ShapeId, meshData: ^MeshData, scale: Vec3) ---
	/// Get the maximum capacity required for retrieving all the touching contacts on a shape
	Shape_GetContactCapacity :: proc(shapeId: ShapeId) -> i32 ---
	/// Get the touching contact data for a shape. The provided shapeId will be either shapeIdA or shapeIdB on the contact data.
	/// @note Box3D uses speculative collision so some contact points may be separated.
	/// @returns the number of elements filled in the provided array
	/// @warning do not ignore the return value, it specifies the valid number of elements
	Shape_GetContactData :: proc(shapeId: ShapeId, contactData: ^ContactData, capacity: i32) -> i32 ---
	/// Get the maximum capacity required for retrieving all the overlapped shapes on a sensor shape.
	/// This returns 0 if the provided shape is not a sensor.
	/// @param shapeId the id of a sensor shape
	/// @returns the required capacity to get all the overlaps in b3Shape_GetSensorOverlaps
	Shape_GetSensorCapacity :: proc(shapeId: ShapeId) -> i32 ---
	/// Get the overlap data for a sensor shape.
	/// @param shapeId the id of a sensor shape
	/// @param visitorIds a user allocated array that is filled with the overlapping shapes (visitors)
	/// @param capacity the capacity of overlappedShapes
	/// @returns the number of elements filled in the provided array
	/// @warning do not ignore the return value, it specifies the valid number of elements
	/// @warning overlaps may contain destroyed shapes so use b3Shape_IsValid to confirm each overlap
	Shape_GetSensorData :: proc(shapeId: ShapeId, visitorIds: ^ShapeId, capacity: i32) -> i32 ---
	/// Get the current world AABB
	Shape_GetAABB :: proc(shapeId: ShapeId) -> AABB ---
	/// Compute the mass data for a shape
	Shape_ComputeMassData :: proc(shapeId: ShapeId) -> MassData ---
	/// Get the closest point on a shape to a target point. Target and result are in world space.
	Shape_GetClosestPoint :: proc(shapeId: ShapeId, target: Vec3) -> Vec3 ---
	/// Apply a wind force to the body for this shape using the density of air. This considers
	/// the projected area of the shape in the wind direction. This also considers
	/// the relative velocity of the shape.
	/// @param shapeId the shape id
	/// @param wind the wind velocity in world space
	/// @param drag the drag coefficient, the force that opposes the relative velocity
	/// @param lift the lift coefficient, the force that is perpendicular to the relative velocity
	/// @param maxSpeed the maximum relative speed. Speed cap is necessary for stability. Typically 10m/s or less.
	/// @param wake should this wake the body
	Shape_ApplyWind :: proc(shapeId: ShapeId, wind: Vec3, drag: f32, lift: f32, maxSpeed: f32, wake: bool) ---
	/// Destroy a joint
	DestroyJoint :: proc(jointId: JointId, wakeAttached: bool) ---
	/// Joint identifier validation. Provides validation for up to 64K allocations.
	Joint_IsValid :: proc(id: JointId) -> bool ---
	/// Get the joint type
	Joint_GetType :: proc(jointId: JointId) -> JointType ---
	/// Get body A id on a joint
	Joint_GetBodyA :: proc(jointId: JointId) -> BodyId ---
	/// Get body B id on a joint
	Joint_GetBodyB :: proc(jointId: JointId) -> BodyId ---
	/// Get the world that owns this joint
	Joint_GetWorld :: proc(jointId: JointId) -> WorldId ---
	/// Set the local frame on bodyA
	Joint_SetLocalFrameA :: proc(jointId: JointId, localFrame: Transform) ---
	/// Get the local frame on bodyA
	Joint_GetLocalFrameA :: proc(jointId: JointId) -> Transform ---
	/// Set the local frame on bodyB
	Joint_SetLocalFrameB :: proc(jointId: JointId, localFrame: Transform) ---
	/// Get the local frame on bodyB
	Joint_GetLocalFrameB :: proc(jointId: JointId) -> Transform ---
	/// Toggle collision between connected bodies
	Joint_SetCollideConnected :: proc(jointId: JointId, shouldCollide: bool) ---
	/// Is collision allowed between connected bodies?
	Joint_GetCollideConnected :: proc(jointId: JointId) -> bool ---
	/// Set the user data on a joint
	Joint_SetUserData :: proc(jointId: JointId, userData: rawptr) ---
	/// Get the user data on a joint
	Joint_GetUserData :: proc(jointId: JointId) -> rawptr ---
	/// Wake the bodies connect to this joint
	Joint_WakeBodies :: proc(jointId: JointId) ---
	/// Get the current constraint force for this joint
	Joint_GetConstraintForce :: proc(jointId: JointId) -> Vec3 ---
	/// Get the current constraint torque for this joint
	Joint_GetConstraintTorque :: proc(jointId: JointId) -> Vec3 ---
	/// Get the current linear separation error for this joint. Does not consider admissible movement. Usually in meters.
	Joint_GetLinearSeparation :: proc(jointId: JointId) -> f32 ---
	/// Get the current angular separation error for this joint. Does not consider admissible movement. Usually in radians.
	Joint_GetAngularSeparation :: proc(jointId: JointId) -> f32 ---
	/// Set the joint constraint tuning. Advanced feature.
	/// @param jointId the joint
	/// @param hertz the stiffness in Hertz (cycles per second)
	/// @param dampingRatio the non-dimensional damping ratio (one for critical damping)
	Joint_SetConstraintTuning :: proc(jointId: JointId, hertz: f32, dampingRatio: f32) ---
	/// Get the joint constraint tuning. Advanced feature.
	Joint_GetConstraintTuning :: proc(jointId: JointId, hertz: ^f32, dampingRatio: ^f32) ---
	/// Set the force threshold for joint events (Newtons)
	Joint_SetForceThreshold :: proc(jointId: JointId, threshold: f32) ---
	/// Get the force threshold for joint events (Newtons)
	Joint_GetForceThreshold :: proc(jointId: JointId) -> f32 ---
	/// Set the torque threshold for joint events (N-m)
	Joint_SetTorqueThreshold :: proc(jointId: JointId, threshold: f32) ---
	/// Get the torque threshold for joint events (N-m)
	Joint_GetTorqueThreshold :: proc(jointId: JointId) -> f32 ---
	/// Create a parallel joint
	/// @see b3ParallelJointDef for details
	CreateParallelJoint :: proc(worldId: WorldId, def: ^ParallelJointDef) -> JointId ---
	/// Set the spring stiffness in Hertz
	ParallelJoint_SetSpringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Set the spring damping ratio, non-dimensional
	ParallelJoint_SetSpringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the spring Hertz
	ParallelJoint_GetSpringHertz :: proc(jointId: JointId) -> f32 ---
	/// Get the spring damping ratio
	ParallelJoint_GetSpringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the maximum spring torque, usually in newton-meters
	ParallelJoint_SetMaxTorque :: proc(jointId: JointId, force: f32) ---
	/// Get the maximum spring torque, usually in newton-meters
	ParallelJoint_GetMaxTorque :: proc(jointId: JointId) -> f32 ---
	/// Create a distance joint
	/// @see b3DistanceJointDef for details
	CreateDistanceJoint :: proc(worldId: WorldId, def: ^DistanceJointDef) -> JointId ---
	/// Set the rest length of a distance joint
	/// @param jointId The id for a distance joint
	/// @param length The new distance joint length
	DistanceJoint_SetLength :: proc(jointId: JointId, length: f32) ---
	/// Get the rest length of a distance joint
	DistanceJoint_GetLength :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the distance joint spring. When disabled the distance joint is rigid.
	DistanceJoint_EnableSpring :: proc(jointId: JointId, enableSpring: bool) ---
	/// Is the distance joint spring enabled?
	DistanceJoint_IsSpringEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the force range for the spring.
	DistanceJoint_SetSpringForceRange :: proc(jointId: JointId, lowerForce: f32, upperForce: f32) ---
	/// Get the force range for the spring.
	DistanceJoint_GetSpringForceRange :: proc(jointId: JointId, lowerForce: ^f32, upperForce: ^f32) ---
	/// Set the spring stiffness in Hertz
	DistanceJoint_SetSpringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Set the spring damping ratio, non-dimensional
	DistanceJoint_SetSpringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the spring Hertz
	DistanceJoint_GetSpringHertz :: proc(jointId: JointId) -> f32 ---
	/// Get the spring damping ratio
	DistanceJoint_GetSpringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Enable joint limit. The limit only works if the joint spring is enabled. Otherwise the joint is rigid
	/// and the limit has no effect.
	DistanceJoint_EnableLimit :: proc(jointId: JointId, enableLimit: bool) ---
	/// Is the distance joint limit enabled?
	DistanceJoint_IsLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the minimum and maximum length parameters of a distance joint
	DistanceJoint_SetLengthRange :: proc(jointId: JointId, minLength: f32, maxLength: f32) ---
	/// Get the distance joint minimum length
	DistanceJoint_GetMinLength :: proc(jointId: JointId) -> f32 ---
	/// Get the distance joint maximum length
	DistanceJoint_GetMaxLength :: proc(jointId: JointId) -> f32 ---
	/// Get the current length of a distance joint
	DistanceJoint_GetCurrentLength :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the distance joint motor
	DistanceJoint_EnableMotor :: proc(jointId: JointId, enableMotor: bool) ---
	/// Is the distance joint motor enabled?
	DistanceJoint_IsMotorEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the distance joint motor speed, usually in meters per second
	DistanceJoint_SetMotorSpeed :: proc(jointId: JointId, motorSpeed: f32) ---
	/// Get the distance joint motor speed, usually in meters per second
	DistanceJoint_GetMotorSpeed :: proc(jointId: JointId) -> f32 ---
	/// Set the distance joint maximum motor force, usually in newtons
	DistanceJoint_SetMaxMotorForce :: proc(jointId: JointId, force: f32) ---
	/// Get the distance joint maximum motor force, usually in newtons
	DistanceJoint_GetMaxMotorForce :: proc(jointId: JointId) -> f32 ---
	/// Get the distance joint current motor force, usually in newtons
	DistanceJoint_GetMotorForce :: proc(jointId: JointId) -> f32 ---
	/// Create a motor joint
	/// @see b3MotorJointDef for details
	CreateMotorJoint :: proc(worldId: WorldId, def: ^MotorJointDef) -> JointId ---
	/// Set the desired relative linear velocity in meters per second
	MotorJoint_SetLinearVelocity :: proc(jointId: JointId, velocity: Vec3) ---
	/// Get the desired relative linear velocity in meters per second
	MotorJoint_GetLinearVelocity :: proc(jointId: JointId) -> Vec3 ---
	/// Set the desired relative angular velocity in radians per second
	MotorJoint_SetAngularVelocity :: proc(jointId: JointId, velocity: Vec3) ---
	/// Get the desired relative angular velocity in radians per second
	MotorJoint_GetAngularVelocity :: proc(jointId: JointId) -> Vec3 ---
	/// Set the motor joint maximum force, usually in newtons
	MotorJoint_SetMaxVelocityForce :: proc(jointId: JointId, maxForce: f32) ---
	/// Get the motor joint maximum force, usually in newtons
	MotorJoint_GetMaxVelocityForce :: proc(jointId: JointId) -> f32 ---
	/// Set the motor joint maximum torque, usually in newton-meters
	MotorJoint_SetMaxVelocityTorque :: proc(jointId: JointId, maxTorque: f32) ---
	/// Get the motor joint maximum torque, usually in newton-meters
	MotorJoint_GetMaxVelocityTorque :: proc(jointId: JointId) -> f32 ---
	/// Set the spring linear hertz stiffness
	MotorJoint_SetLinearHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the spring linear hertz stiffness
	MotorJoint_GetLinearHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the spring linear damping ratio. Use 1.0 for critical damping.
	MotorJoint_SetLinearDampingRatio :: proc(jointId: JointId, damping: f32) ---
	/// Get the spring linear damping ratio.
	MotorJoint_GetLinearDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the spring angular hertz stiffness
	MotorJoint_SetAngularHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the spring angular hertz stiffness
	MotorJoint_GetAngularHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the spring angular damping ratio. Use 1.0 for critical damping.
	MotorJoint_SetAngularDampingRatio :: proc(jointId: JointId, damping: f32) ---
	/// Get the spring angular damping ratio.
	MotorJoint_GetAngularDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the maximum spring force in newtons.
	MotorJoint_SetMaxSpringForce :: proc(jointId: JointId, maxForce: f32) ---
	/// Get the maximum spring force in newtons.
	MotorJoint_GetMaxSpringForce :: proc(jointId: JointId) -> f32 ---
	/// Set the maximum spring torque in newtons * meters
	MotorJoint_SetMaxSpringTorque :: proc(jointId: JointId, maxTorque: f32) ---
	/// Get the maximum spring torque in newtons * meters
	MotorJoint_GetMaxSpringTorque :: proc(jointId: JointId) -> f32 ---
	/// Create a filter joint.
	/// @see b3FilterJointDef for details
	CreateFilterJoint :: proc(worldId: WorldId, def: ^FilterJointDef) -> JointId ---
	/// Create a prismatic (slider) joint.
	/// @see b3PrismaticJointDef for details
	CreatePrismaticJoint :: proc(worldId: WorldId, def: ^PrismaticJointDef) -> JointId ---
	/// Enable/disable the joint spring.
	PrismaticJoint_EnableSpring :: proc(jointId: JointId, enableSpring: bool) ---
	/// Is the prismatic joint spring enabled or not?
	PrismaticJoint_IsSpringEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the prismatic joint stiffness in Hertz.
	/// This should usually be less than a quarter of the simulation rate. For example, if the simulation
	/// runs at 60Hz then the joint stiffness should be 15Hz or less.
	PrismaticJoint_SetSpringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the prismatic joint stiffness in Hertz
	PrismaticJoint_GetSpringHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the prismatic joint damping ratio (non-dimensional)
	PrismaticJoint_SetSpringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the prismatic spring damping ratio (non-dimensional)
	PrismaticJoint_GetSpringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the prismatic joint target translation. Usually in meters.
	PrismaticJoint_SetTargetTranslation :: proc(jointId: JointId, targetTranslation: f32) ---
	/// Get the prismatic joint target translation. Usually in meters.
	PrismaticJoint_GetTargetTranslation :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable a prismatic joint limit
	PrismaticJoint_EnableLimit :: proc(jointId: JointId, enableLimit: bool) ---
	/// Is the prismatic joint limit enabled?
	PrismaticJoint_IsLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the prismatic joint lower limit
	PrismaticJoint_GetLowerLimit :: proc(jointId: JointId) -> f32 ---
	/// Get the prismatic joint upper limit
	PrismaticJoint_GetUpperLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the prismatic joint limits
	PrismaticJoint_SetLimits :: proc(jointId: JointId, lower: f32, upper: f32) ---
	/// Enable/disable a prismatic joint motor
	PrismaticJoint_EnableMotor :: proc(jointId: JointId, enableMotor: bool) ---
	/// Is the prismatic joint motor enabled?
	PrismaticJoint_IsMotorEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the prismatic joint motor speed, usually in meters per second
	PrismaticJoint_SetMotorSpeed :: proc(jointId: JointId, motorSpeed: f32) ---
	/// Get the prismatic joint motor speed, usually in meters per second
	PrismaticJoint_GetMotorSpeed :: proc(jointId: JointId) -> f32 ---
	/// Set the prismatic joint maximum motor force, usually in newtons
	PrismaticJoint_SetMaxMotorForce :: proc(jointId: JointId, force: f32) ---
	/// Get the prismatic joint maximum motor force, usually in newtons
	PrismaticJoint_GetMaxMotorForce :: proc(jointId: JointId) -> f32 ---
	/// Get the prismatic joint current motor force, usually in newtons
	PrismaticJoint_GetMotorForce :: proc(jointId: JointId) -> f32 ---
	/// Get the current joint translation, usually in meters.
	PrismaticJoint_GetTranslation :: proc(jointId: JointId) -> f32 ---
	/// Get the current joint translation speed, usually in meters per second.
	PrismaticJoint_GetSpeed :: proc(jointId: JointId) -> f32 ---
	/// Create a revolute joint
	/// @see b3RevoluteJointDef for details
	CreateRevoluteJoint :: proc(worldId: WorldId, def: ^RevoluteJointDef) -> JointId ---
	/// Enable/disable the revolute joint spring
	RevoluteJoint_EnableSpring :: proc(jointId: JointId, enableSpring: bool) ---
	/// Is the revolute angular spring enabled?
	RevoluteJoint_IsSpringEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the revolute joint spring stiffness in Hertz
	RevoluteJoint_SetSpringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the revolute joint spring stiffness in Hertz
	RevoluteJoint_GetSpringHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the revolute joint spring damping ratio, non-dimensional
	RevoluteJoint_SetSpringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the revolute joint spring damping ratio, non-dimensional
	RevoluteJoint_GetSpringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the revolute joint target angle in radians
	RevoluteJoint_SetTargetAngle :: proc(jointId: JointId, targetRadians: f32) ---
	/// Get the revolute joint target angle in radians
	RevoluteJoint_GetTargetAngle :: proc(jointId: JointId) -> f32 ---
	/// Get the revolute joint current angle in radians relative to the reference angle
	/// @see b3RevoluteJointDef::referenceAngle
	RevoluteJoint_GetAngle :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the revolute joint limit
	RevoluteJoint_EnableLimit :: proc(jointId: JointId, enableLimit: bool) ---
	/// Is the revolute joint limit enabled?
	RevoluteJoint_IsLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the revolute joint lower limit in radians
	RevoluteJoint_GetLowerLimit :: proc(jointId: JointId) -> f32 ---
	/// Get the revolute joint upper limit in radians
	RevoluteJoint_GetUpperLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the revolute joint limits in radians
	RevoluteJoint_SetLimits :: proc(jointId: JointId, lowerLimitRadians: f32, upperLimitRadians: f32) ---
	/// Enable/disable a revolute joint motor
	RevoluteJoint_EnableMotor :: proc(jointId: JointId, enableMotor: bool) ---
	/// Is the revolute joint motor enabled?
	RevoluteJoint_IsMotorEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the revolute joint motor speed in radians per second
	RevoluteJoint_SetMotorSpeed :: proc(jointId: JointId, motorSpeed: f32) ---
	/// Get the revolute joint motor speed in radians per second
	RevoluteJoint_GetMotorSpeed :: proc(jointId: JointId) -> f32 ---
	/// Get the revolute joint current motor torque, usually in newton-meters
	RevoluteJoint_GetMotorTorque :: proc(jointId: JointId) -> f32 ---
	/// Set the revolute joint maximum motor torque, usually in newton-meters
	RevoluteJoint_SetMaxMotorTorque :: proc(jointId: JointId, torque: f32) ---
	/// Get the revolute joint maximum motor torque, usually in newton-meters
	RevoluteJoint_GetMaxMotorTorque :: proc(jointId: JointId) -> f32 ---
	/// Create a spherical joint
	/// @see b3SphericalJointDef for details
	CreateSphericalJoint :: proc(worldId: WorldId, def: ^SphericalJointDef) -> JointId ---
	/// Enable/disable the spherical joint cone limit
	SphericalJoint_EnableConeLimit :: proc(jointId: JointId, enableLimit: bool) ---
	/// Is the spherical joint cone limit enabled?
	SphericalJoint_IsConeLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the spherical joint cone limit in radians
	SphericalJoint_GetConeLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the spherical joint limits in radians
	SphericalJoint_SetConeLimit :: proc(jointId: JointId, angleRadians: f32) ---
	/// Get the spherical joint current cone angle in radians.
	SphericalJoint_GetConeAngle :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the spherical joint limit
	SphericalJoint_EnableTwistLimit :: proc(jointId: JointId, enableLimit: bool) ---
	/// Is the spherical joint limit enabled?
	SphericalJoint_IsTwistLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the spherical joint lower limit in radians
	SphericalJoint_GetLowerTwistLimit :: proc(jointId: JointId) -> f32 ---
	/// Get the spherical joint upper limit in radians
	SphericalJoint_GetUpperTwistLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the spherical joint limits in radians
	SphericalJoint_SetTwistLimits :: proc(jointId: JointId, lowerLimitRadians: f32, upperLimitRadians: f32) ---
	/// Get the spherical joint current twist angle in radians.
	SphericalJoint_GetTwistAngle :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the spherical joint spring
	SphericalJoint_EnableSpring :: proc(jointId: JointId, enableSpring: bool) ---
	/// Is the spherical angular spring enabled?
	SphericalJoint_IsSpringEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the spherical joint spring stiffness in Hertz
	SphericalJoint_SetSpringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the spherical joint spring stiffness in Hertz
	SphericalJoint_GetSpringHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the spherical joint spring damping ratio, non-dimensional
	SphericalJoint_SetSpringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the spherical joint spring damping ratio, non-dimensional
	SphericalJoint_GetSpringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the spherical joint spring target rotation
	SphericalJoint_SetTargetRotation :: proc(jointId: JointId, targetRotation: Quat) ---
	/// Get the spherical joint spring target rotation
	SphericalJoint_GetTargetRotation :: proc(jointId: JointId) -> Quat ---
	/// Enable/disable a spherical joint motor
	SphericalJoint_EnableMotor :: proc(jointId: JointId, enableMotor: bool) ---
	/// Is the spherical joint motor enabled?
	SphericalJoint_IsMotorEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the spherical joint motor velocity in radians per second
	SphericalJoint_SetMotorVelocity :: proc(jointId: JointId, motorVelocity: Vec3) ---
	/// Get the spherical joint motor velocity in radians per second
	SphericalJoint_GetMotorVelocity :: proc(jointId: JointId) -> Vec3 ---
	/// Get the spherical joint current motor torque, usually in newton-meters
	SphericalJoint_GetMotorTorque :: proc(jointId: JointId) -> Vec3 ---
	/// Set the spherical joint maximum motor torque, usually in newton-meters
	SphericalJoint_SetMaxMotorTorque :: proc(jointId: JointId, torque: f32) ---
	/// Get the spherical joint maximum motor torque, usually in newton-meters
	SphericalJoint_GetMaxMotorTorque :: proc(jointId: JointId) -> f32 ---
	/// Create a weld joint
	/// @see b3WeldJointDef for details
	CreateWeldJoint :: proc(worldId: WorldId, def: ^WeldJointDef) -> JointId ---
	/// Set the weld joint linear stiffness in Hertz. 0 is rigid.
	WeldJoint_SetLinearHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the weld joint linear stiffness in Hertz
	WeldJoint_GetLinearHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the weld joint linear damping ratio (non-dimensional)
	WeldJoint_SetLinearDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the weld joint linear damping ratio (non-dimensional)
	WeldJoint_GetLinearDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the weld joint angular stiffness in Hertz. 0 is rigid.
	WeldJoint_SetAngularHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the weld joint angular stiffness in Hertz
	WeldJoint_GetAngularHertz :: proc(jointId: JointId) -> f32 ---
	/// Set weld joint angular damping ratio, non-dimensional
	WeldJoint_SetAngularDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the weld joint angular damping ratio, non-dimensional
	WeldJoint_GetAngularDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Create a wheel joint.
	/// @see b3WheelJointDef for details.
	CreateWheelJoint :: proc(worldId: WorldId, def: ^WheelJointDef) -> JointId ---
	/// Enable/disable the wheel joint spring.
	WheelJoint_EnableSuspension :: proc(jointId: JointId, flag: bool) ---
	/// Is the wheel joint spring enabled?
	WheelJoint_IsSuspensionEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the wheel joint stiffness in Hertz.
	WheelJoint_SetSuspensionHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the wheel joint stiffness in Hertz.
	WheelJoint_GetSuspensionHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint damping ratio, non-dimensional.
	WheelJoint_SetSuspensionDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the wheel joint damping ratio, non-dimensional.
	WheelJoint_GetSuspensionDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the wheel joint limit.
	WheelJoint_EnableSuspensionLimit :: proc(jointId: JointId, flag: bool) ---
	/// Is the wheel joint limit enabled?
	WheelJoint_IsSuspensionLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the wheel joint lower limit.
	WheelJoint_GetLowerSuspensionLimit :: proc(jointId: JointId) -> f32 ---
	/// Get the wheel joint upper limit.
	WheelJoint_GetUpperSuspensionLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint limits.
	WheelJoint_SetSuspensionLimits :: proc(jointId: JointId, lower: f32, upper: f32) ---
	/// Enable/disable the wheel joint motor.
	WheelJoint_EnableSpinMotor :: proc(jointId: JointId, flag: bool) ---
	/// Is the wheel joint motor enabled?
	WheelJoint_IsSpinMotorEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the wheel joint motor speed in radians per second.
	WheelJoint_SetSpinMotorSpeed :: proc(jointId: JointId, speed: f32) ---
	/// Get the wheel joint motor speed in radians per second.
	WheelJoint_GetSpinMotorSpeed :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint maximum motor torque, usually in newton-meters.
	WheelJoint_SetMaxSpinTorque :: proc(jointId: JointId, torque: f32) ---
	/// Get the wheel joint maximum motor torque, usually in newton-meters.
	WheelJoint_GetMaxSpinTorque :: proc(jointId: JointId) -> f32 ---
	/// Get the current spin speed in radians per second.
	WheelJoint_GetSpinSpeed :: proc(jointId: JointId) -> f32 ---
	/// Get the wheel joint current motor torque, usually in newton-meters.
	WheelJoint_GetSpinTorque :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable wheel steering. Steering allows the wheel to rotate about the suspension axis.
	WheelJoint_EnableSteering :: proc(jointId: JointId, flag: bool) ---
	/// Can the wheel steer?
	WheelJoint_IsSteeringEnabled :: proc(jointId: JointId) -> bool ---
	/// Set the wheel joint steering stiffness in Hertz.
	WheelJoint_SetSteeringHertz :: proc(jointId: JointId, hertz: f32) ---
	/// Get the wheel joint steering stiffness in Hertz.
	WheelJoint_GetSteeringHertz :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint steering damping ratio, non-dimensional.
	WheelJoint_SetSteeringDampingRatio :: proc(jointId: JointId, dampingRatio: f32) ---
	/// Get the wheel joint steering damping ratio, non-dimensional.
	WheelJoint_GetSteeringDampingRatio :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint maximum steering torque in N*m.
	WheelJoint_SetMaxSteeringTorque :: proc(jointId: JointId, torque: f32) ---
	/// Get the wheel joint maximum steering torque in N*m.
	WheelJoint_GetMaxSteeringTorque :: proc(jointId: JointId) -> f32 ---
	/// Enable/disable the wheel joint steering limit.
	WheelJoint_EnableSteeringLimit :: proc(jointId: JointId, flag: bool) ---
	/// Is the wheel joint steering limit enabled?
	WheelJoint_IsSteeringLimitEnabled :: proc(jointId: JointId) -> bool ---
	/// Get the wheel joint lower steering limit in radians.
	WheelJoint_GetLowerSteeringLimit :: proc(jointId: JointId) -> f32 ---
	/// Get the wheel joint upper steering limit in radians.
	WheelJoint_GetUpperSteeringLimit :: proc(jointId: JointId) -> f32 ---
	/// Set the wheel joint steering limits in radians.
	WheelJoint_SetSteeringLimits :: proc(jointId: JointId, lowerRadians: f32, upperRadians: f32) ---
	/// Set the wheel joint target steering angle in radians.
	WheelJoint_SetTargetSteeringAngle :: proc(jointId: JointId, radians: f32) ---
	/// Get the wheel joint target steering angle in radians.
	WheelJoint_GetTargetSteeringAngle :: proc(jointId: JointId) -> f32 ---
	/// Get the current steering angle in radians.
	WheelJoint_GetSteeringAngle :: proc(jointId: JointId) -> f32 ---
	/// Get the current steering torque in N*m.
	WheelJoint_GetSteeringTorque :: proc(jointId: JointId) -> f32 ---
	/// Contact identifier validation. Provides validation for up to 2^32 allocations.
	Contact_IsValid :: proc(id: ContactId) -> bool ---
	/// Get the manifolds for a contact. The manifold may have no points if the contact is not touching.
	Contact_GetData :: proc(contactId: ContactId) -> ContactData ---
}
