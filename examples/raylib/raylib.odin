package raylib

foreign import lib "system:raylib"

RAYLIB_VERSION_MAJOR :: 6
RAYLIB_VERSION_MINOR :: 0
RAYLIB_VERSION_PATCH :: 0
RAYLIB_VERSION :: "6.0"
// Vector2, 2 components
Vector2 :: [2]f32

// Vector3, 3 components
Vector3 :: [3]f32

// Vector4, 4 components
Vector4 :: [4]f32

// Quaternion, 4 components (Vector4 alias)
Quaternion :: quaternion128

// Matrix, 4x4 components, column major, OpenGL style, right-handed
Matrix :: #row_major matrix[4, 4]f32

// Color, 4 components, R8G8B8A8 (32bit)
Color :: distinct [4]u8

// Rectangle, 4 components
Rectangle :: struct {
	// Rectangle top-left corner position x
	x:      f32,
	// Rectangle top-left corner position y
	y:      f32,
	// Rectangle width
	width:  f32,
	// Rectangle height
	height: f32,
}

// Image, pixel data stored in CPU memory (RAM)
Image :: struct {
	// Image raw data
	data:    rawptr,
	// Image base width
	width:   i32,
	// Image base height
	height:  i32,
	// Mipmap levels, 1 by default
	mipmaps: i32,
	// Data format (PixelFormat type)
	format:  i32,
}

// Texture, tex data stored in GPU memory (VRAM)
Texture :: struct {
	// OpenGL texture id
	id:      u32,
	// Texture base width
	width:   i32,
	// Texture base height
	height:  i32,
	// Mipmap levels, 1 by default
	mipmaps: i32,
	// Data format (PixelFormat type)
	format:  i32,
}

// Texture2D, same as Texture
Texture2D :: Texture

// TextureCubemap, same as Texture
TextureCubemap :: Texture

// RenderTexture, fbo for texture rendering
RenderTexture :: struct {
	// OpenGL framebuffer object id
	id:      u32,
	// Color buffer attachment texture
	texture: Texture,
	// Depth buffer attachment texture
	depth:   Texture,
}

// RenderTexture2D, same as RenderTexture
RenderTexture2D :: RenderTexture

// NPatchInfo, n-patch layout info
NPatchInfo :: struct {
	// Texture source rectangle
	source: Rectangle,
	// Left border offset
	left:   i32,
	// Top border offset
	top:    i32,
	// Right border offset
	right:  i32,
	// Bottom border offset
	bottom: i32,
	// Layout of the n-patch: 3x3, 1x3 or 3x1
	layout: i32,
}

// GlyphInfo, font characters glyphs info
GlyphInfo :: struct {
	// Character value (Unicode)
	value:    i32,
	// Character offset X when drawing
	offsetX:  i32,
	// Character offset Y when drawing
	offsetY:  i32,
	// Character advance position X
	advanceX: i32,
	// Character image data
	image:    Image,
}

// Font, font texture and GlyphInfo array data
Font :: struct {
	// Base size (default chars height)
	baseSize:     i32,
	// Number of glyph characters
	glyphCount:   i32,
	// Padding around the glyph characters
	glyphPadding: i32,
	// Texture atlas containing the glyphs
	texture:      Texture2D,
	// Rectangles in texture for the glyphs
	recs:         ^Rectangle,
	// Glyphs info data
	glyphs:       ^GlyphInfo,
}

// Camera, defines position/orientation in 3d space
Camera3D :: struct {
	// Camera position
	position:   Vector3,
	// Camera target it looks-at
	target:     Vector3,
	// Camera up vector (rotation over its axis)
	up:         Vector3,
	// Camera field-of-view aperture in Y (degrees) in perspective, used as near plane height in world units in orthographic
	fovy:       f32,
	// Camera projection: CAMERA_PERSPECTIVE or CAMERA_ORTHOGRAPHIC
	projection: i32,
}

Camera :: Camera3D

// Camera2D, defines position/orientation in 2d space
Camera2D :: struct {
	// Camera offset (screen space offset from window origin)
	offset:   Vector2,
	// Camera target (world space target point that is mapped to screen space offset)
	target:   Vector2,
	// Camera rotation in degrees (pivots around target)
	rotation: f32,
	// Camera zoom (scaling around target), must not be set to 0, set to 1.0f for no scale
	zoom:     f32,
}

// Mesh, vertex data and vao/vbo
Mesh :: struct {
	// Number of vertices stored in arrays
	vertexCount:   i32,
	// Number of triangles stored (indexed or not)
	triangleCount: i32,
	// Vertex position (XYZ - 3 components per vertex) (shader-location = 0)
	vertices:      ^f32,
	// Vertex texture coordinates (UV - 2 components per vertex) (shader-location = 1)
	texcoords:     ^f32,
	// Vertex texture second coordinates (UV - 2 components per vertex) (shader-location = 5)
	texcoords2:    ^f32,
	// Vertex normals (XYZ - 3 components per vertex) (shader-location = 2)
	normals:       ^f32,
	// Vertex tangents (XYZW - 4 components per vertex) (shader-location = 4)
	tangents:      ^f32,
	// Vertex colors (RGBA - 4 components per vertex) (shader-location = 3)
	colors:        ^u8,
	// Vertex indices (in case vertex data comes indexed)
	indices:       ^u16,
	// Number of bones (MAX: 256 bones)
	boneCount:     i32,
	// Vertex bone indices, up to 4 bones influence by vertex (skinning) (shader-location = 6)
	boneIndices:   ^u8,
	// Vertex bone weight, up to 4 bones influence by vertex (skinning) (shader-location = 7)
	boneWeights:   ^f32,
	// Animated vertex positions (after bones transformations)
	animVertices:  ^f32,
	// Animated normals (after bones transformations)
	animNormals:   ^f32,
	// OpenGL Vertex Array Object id
	vaoId:         u32,
	// OpenGL Vertex Buffer Objects id (default vertex data)
	vboId:         ^u32,
}

// Shader
Shader :: struct {
	// Shader program id
	id:   u32,
	// Shader locations array (RL_MAX_SHADER_LOCATIONS)
	locs: ^i32,
}

// MaterialMap
MaterialMap :: struct {
	// Material map texture
	texture: Texture2D,
	// Material map color
	color:   Color,
	// Material map value
	value:   f32,
}

// Material, includes shader and maps
Material :: struct {
	// Material shader
	shader: Shader,
	// Material maps array (MAX_MATERIAL_MAPS)
	maps:   ^MaterialMap,
	// Material generic parameters (if required)
	params: [4]f32,
}

// Transform, vertex transformation data
Transform :: struct {
	// Translation
	translation: Vector3,
	// Rotation
	rotation:    Quaternion,
	// Scale
	scale:       Vector3,
}

// Anim pose, an array of Transform[]
ModelAnimPose :: ^Transform

// Bone, skeletal animation bone
BoneInfo :: struct {
	// Bone name
	name:   [32]u8,
	// Bone parent
	parent: i32,
}

// Skeleton, animation bones hierarchy
ModelSkeleton :: struct {
	// Number of bones
	boneCount: i32,
	// Bones information (skeleton)
	bones:     ^BoneInfo,
	// Bones base transformation (Transform[])
	bindPose:  ModelAnimPose,
}

// Model, meshes, materials and animation data
Model :: struct {
	// Local transform matrix
	transform:     Matrix,
	// Number of meshes
	meshCount:     i32,
	// Number of materials
	materialCount: i32,
	// Meshes array
	meshes:        ^Mesh,
	// Materials array
	materials:     ^Material,
	// Mesh material number
	meshMaterial:  ^i32,
	// Skeleton for animation
	skeleton:      ModelSkeleton,
	// Current animation pose (Transform[])
	currentPose:   ModelAnimPose,
	// Bones animated transformation matrices
	boneMatrices:  ^Matrix,
}

// ModelAnimation, contains a full animation sequence
ModelAnimation :: struct {
	// Animation name
	name:          [32]u8,
	// Number of bones (per pose)
	boneCount:     i32,
	// Number of animation key frames
	keyframeCount: i32,
	// Animation sequence keyframe poses [keyframe][pose]
	keyframePoses: ^ModelAnimPose,
}

// Ray, ray for raycasting
Ray :: struct {
	// Ray position (origin)
	position:  Vector3,
	// Ray direction (normalized)
	direction: Vector3,
}

// RayCollision, ray hit information
RayCollision :: struct {
	// Did the ray hit something?
	hit:      bool,
	// Distance to the nearest hit
	distance: f32,
	// Point of the nearest hit
	point:    Vector3,
	// Surface normal of hit
	normal:   Vector3,
}

// BoundingBox
BoundingBox :: struct {
	// Minimum vertex box-corner
	min: Vector3,
	// Maximum vertex box-corner
	max: Vector3,
}

// Wave, audio wave data
Wave :: struct {
	// Total number of frames (considering channels)
	frameCount: u32,
	// Frequency (samples per second)
	sampleRate: u32,
	// Bit depth (bits per sample): 8, 16, 32 (24 not supported)
	sampleSize: u32,
	// Number of channels (1-mono, 2-stereo, ...)
	channels:   u32,
	// Buffer data pointer
	data:       rawptr,
}

rAudioBuffer :: distinct rawptr

rAudioProcessor :: distinct rawptr

// AudioStream, custom audio stream
AudioStream :: struct {
	// Pointer to internal data used by the audio system
	buffer:     rAudioBuffer,
	// Pointer to internal data processor, useful for audio effects
	processor:  rAudioProcessor,
	// Frequency (samples per second)
	sampleRate: u32,
	// Bit depth (bits per sample): 8, 16, 32 (24 not supported)
	sampleSize: u32,
	// Number of channels (1-mono, 2-stereo, ...)
	channels:   u32,
}

// Sound
Sound :: struct {
	// Audio stream
	stream:     AudioStream,
	// Total number of frames (considering channels)
	frameCount: u32,
}

// Music, audio stream, anything longer than ~10 seconds should be streamed
Music :: struct {
	// Audio stream
	stream:     AudioStream,
	// Total number of frames (considering channels)
	frameCount: u32,
	// Music looping enable
	looping:    bool,
	// Type of music context (audio filetype)
	ctxType:    i32,
	// Audio context data, depends on type
	ctxData:    rawptr,
}

// VrDeviceInfo, Head-Mounted-Display device parameters
VrDeviceInfo :: struct {
	// Horizontal resolution in pixels
	hResolution:            i32,
	// Vertical resolution in pixels
	vResolution:            i32,
	// Horizontal size in meters
	hScreenSize:            f32,
	// Vertical size in meters
	vScreenSize:            f32,
	// Distance between eye and display in meters
	eyeToScreenDistance:    f32,
	// Lens separation distance in meters
	lensSeparationDistance: f32,
	// IPD (distance between pupils) in meters
	interpupillaryDistance: f32,
	// Lens distortion constant parameters
	lensDistortionValues:   [4]f32,
	// Chromatic aberration correction parameters
	chromaAbCorrection:     [4]f32,
}

// VrStereoConfig, VR stereo rendering configuration for simulator
VrStereoConfig :: struct {
	// VR projection matrices (per eye)
	projection:        [2]Matrix,
	// VR view offset matrices (per eye)
	viewOffset:        [2]Matrix,
	// VR left lens center
	leftLensCenter:    [2]f32,
	// VR right lens center
	rightLensCenter:   [2]f32,
	// VR left screen center
	leftScreenCenter:  [2]f32,
	// VR right screen center
	rightScreenCenter: [2]f32,
	// VR distortion scale
	scale:             [2]f32,
	// VR distortion scale in
	scaleIn:           [2]f32,
}

// File path list
FilePathList :: struct {
	// Filepaths entries count
	count: u32,
	// Filepaths entries
	paths: ^^u8,
}

// Automation event
AutomationEvent :: struct {
	// Event frame
	frame:  u32,
	// Event type (AutomationEventType)
	type:   u32,
	// Event parameters (if required)
	params: [4]i32,
}

// Automation event list
AutomationEventList :: struct {
	// Events max entries (MAX_AUTOMATION_EVENTS)
	capacity: u32,
	// Events entries count
	count:    u32,
	// Events entries
	events:   ^AutomationEvent,
}

//----------------------------------------------------------------------------------
// Enumerators Definition
//----------------------------------------------------------------------------------
// System/Window config flags
// NOTE: Every bit registers one state (use it with bit masks)
// By default all flags are set to 0
ConfigFlags :: enum u32 {
	// Set to try enabling V-Sync on GPU
	FLAG_VSYNC_HINT               = 64,
	// Set to run program in fullscreen
	FLAG_FULLSCREEN_MODE          = 2,
	// Set to allow resizable window
	FLAG_WINDOW_RESIZABLE         = 4,
	// Set to disable window decoration (frame and buttons)
	FLAG_WINDOW_UNDECORATED       = 8,
	// Set to hide window
	FLAG_WINDOW_HIDDEN            = 128,
	// Set to minimize window (iconify)
	FLAG_WINDOW_MINIMIZED         = 512,
	// Set to maximize window (expanded to monitor)
	FLAG_WINDOW_MAXIMIZED         = 1024,
	// Set to window non focused
	FLAG_WINDOW_UNFOCUSED         = 2048,
	// Set to window always on top
	FLAG_WINDOW_TOPMOST           = 4096,
	// Set to allow windows running while minimized
	FLAG_WINDOW_ALWAYS_RUN        = 256,
	// Set to allow transparent framebuffer
	FLAG_WINDOW_TRANSPARENT       = 16,
	// Set to support HighDPI
	FLAG_WINDOW_HIGHDPI           = 8192,
	// Set to support mouse passthrough, only supported when FLAG_WINDOW_UNDECORATED
	FLAG_WINDOW_MOUSE_PASSTHROUGH = 16384,
	// Set to run program in borderless windowed mode
	FLAG_BORDERLESS_WINDOWED_MODE = 32768,
	// Set to try enabling MSAA 4X
	FLAG_MSAA_4X_HINT             = 32,
	// Set to try enabling interlaced video format (for V3D)
	FLAG_INTERLACED_HINT          = 65536,
}

// Trace log level
// NOTE: Organized by priority level
TraceLogLevel :: enum u32 {
	// Display all logs
	LOG_ALL,
	// Trace logging, intended for internal use only
	LOG_TRACE,
	// Debug logging, used for internal debugging, it should be disabled on release builds
	LOG_DEBUG,
	// Info logging, used for program execution info
	LOG_INFO,
	// Warning logging, used on recoverable failures
	LOG_WARNING,
	// Error logging, used on unrecoverable failures
	LOG_ERROR,
	// Fatal logging, used to abort program: exit(EXIT_FAILURE)
	LOG_FATAL,
	// Disable logging
	LOG_NONE,
}

// Keyboard keys (US keyboard layout)
// NOTE: Use GetKeyPressed() to allow redefining required keys for alternative layouts
KeyboardKey :: enum u32 {
	// Key: NULL, used for no key pressed
	KEY_NULL,
	// Key: '
	KEY_APOSTROPHE = 39,
	// Key: ,
	KEY_COMMA = 44,
	// Key: -
	KEY_MINUS,
	// Key: .
	KEY_PERIOD,
	// Key: /
	KEY_SLASH,
	// Key: 0
	KEY_ZERO,
	// Key: 1
	KEY_ONE,
	// Key: 2
	KEY_TWO,
	// Key: 3
	KEY_THREE,
	// Key: 4
	KEY_FOUR,
	// Key: 5
	KEY_FIVE,
	// Key: 6
	KEY_SIX,
	// Key: 7
	KEY_SEVEN,
	// Key: 8
	KEY_EIGHT,
	// Key: 9
	KEY_NINE,
	// Key: ;
	KEY_SEMICOLON = 59,
	// Key: =
	KEY_EQUAL = 61,
	// Key: A | a
	KEY_A = 65,
	// Key: B | b
	KEY_B,
	// Key: C | c
	KEY_C,
	// Key: D | d
	KEY_D,
	// Key: E | e
	KEY_E,
	// Key: F | f
	KEY_F,
	// Key: G | g
	KEY_G,
	// Key: H | h
	KEY_H,
	// Key: I | i
	KEY_I,
	// Key: J | j
	KEY_J,
	// Key: K | k
	KEY_K,
	// Key: L | l
	KEY_L,
	// Key: M | m
	KEY_M,
	// Key: N | n
	KEY_N,
	// Key: O | o
	KEY_O,
	// Key: P | p
	KEY_P,
	// Key: Q | q
	KEY_Q,
	// Key: R | r
	KEY_R,
	// Key: S | s
	KEY_S,
	// Key: T | t
	KEY_T,
	// Key: U | u
	KEY_U,
	// Key: V | v
	KEY_V,
	// Key: W | w
	KEY_W,
	// Key: X | x
	KEY_X,
	// Key: Y | y
	KEY_Y,
	// Key: Z | z
	KEY_Z,
	// Key: [
	KEY_LEFT_BRACKET,
	// Key: '\'
	KEY_BACKSLASH,
	// Key: ]
	KEY_RIGHT_BRACKET,
	// Key: `
	KEY_GRAVE = 96,
	// Key: Space
	KEY_SPACE = 32,
	// Key: Esc
	KEY_ESCAPE = 256,
	// Key: Enter
	KEY_ENTER,
	// Key: Tab
	KEY_TAB,
	// Key: Backspace
	KEY_BACKSPACE,
	// Key: Ins
	KEY_INSERT,
	// Key: Del
	KEY_DELETE,
	// Key: Cursor right
	KEY_RIGHT,
	// Key: Cursor left
	KEY_LEFT,
	// Key: Cursor down
	KEY_DOWN,
	// Key: Cursor up
	KEY_UP,
	// Key: Page up
	KEY_PAGE_UP,
	// Key: Page down
	KEY_PAGE_DOWN,
	// Key: Home
	KEY_HOME,
	// Key: End
	KEY_END,
	// Key: Caps lock
	KEY_CAPS_LOCK = 280,
	// Key: Scroll down
	KEY_SCROLL_LOCK,
	// Key: Num lock
	KEY_NUM_LOCK,
	// Key: Print screen
	KEY_PRINT_SCREEN,
	// Key: Pause
	KEY_PAUSE,
	// Key: F1
	KEY_F1 = 290,
	// Key: F2
	KEY_F2,
	// Key: F3
	KEY_F3,
	// Key: F4
	KEY_F4,
	// Key: F5
	KEY_F5,
	// Key: F6
	KEY_F6,
	// Key: F7
	KEY_F7,
	// Key: F8
	KEY_F8,
	// Key: F9
	KEY_F9,
	// Key: F10
	KEY_F10,
	// Key: F11
	KEY_F11,
	// Key: F12
	KEY_F12,
	// Key: Shift left
	KEY_LEFT_SHIFT = 340,
	// Key: Control left
	KEY_LEFT_CONTROL,
	// Key: Alt left
	KEY_LEFT_ALT,
	// Key: Super left
	KEY_LEFT_SUPER,
	// Key: Shift right
	KEY_RIGHT_SHIFT,
	// Key: Control right
	KEY_RIGHT_CONTROL,
	// Key: Alt right
	KEY_RIGHT_ALT,
	// Key: Super right
	KEY_RIGHT_SUPER,
	// Key: KB menu
	KEY_KB_MENU,
	// Key: Keypad 0
	KEY_KP_0 = 320,
	// Key: Keypad 1
	KEY_KP_1,
	// Key: Keypad 2
	KEY_KP_2,
	// Key: Keypad 3
	KEY_KP_3,
	// Key: Keypad 4
	KEY_KP_4,
	// Key: Keypad 5
	KEY_KP_5,
	// Key: Keypad 6
	KEY_KP_6,
	// Key: Keypad 7
	KEY_KP_7,
	// Key: Keypad 8
	KEY_KP_8,
	// Key: Keypad 9
	KEY_KP_9,
	// Key: Keypad .
	KEY_KP_DECIMAL,
	// Key: Keypad /
	KEY_KP_DIVIDE,
	// Key: Keypad *
	KEY_KP_MULTIPLY,
	// Key: Keypad -
	KEY_KP_SUBTRACT,
	// Key: Keypad +
	KEY_KP_ADD,
	// Key: Keypad Enter
	KEY_KP_ENTER,
	// Key: Keypad =
	KEY_KP_EQUAL,
	// Key: Android back button
	KEY_BACK = 4,
	// Key: Android menu button
	KEY_MENU,
	// Key: Android volume up button
	KEY_VOLUME_UP = 24,
	// Key: Android volume down button
	KEY_VOLUME_DOWN,
}

// Mouse buttons
MouseButton :: enum u32 {
	// Mouse button left
	MOUSE_BUTTON_LEFT,
	// Mouse button right
	MOUSE_BUTTON_RIGHT,
	// Mouse button middle (pressed wheel)
	MOUSE_BUTTON_MIDDLE,
	// Mouse button side (advanced mouse device)
	MOUSE_BUTTON_SIDE,
	// Mouse button extra (advanced mouse device)
	MOUSE_BUTTON_EXTRA,
	// Mouse button forward (advanced mouse device)
	MOUSE_BUTTON_FORWARD,
	// Mouse button back (advanced mouse device)
	MOUSE_BUTTON_BACK,
}

// Mouse cursor
MouseCursor :: enum u32 {
	// Default pointer shape
	MOUSE_CURSOR_DEFAULT,
	// Arrow shape
	MOUSE_CURSOR_ARROW,
	// Text writing cursor shape
	MOUSE_CURSOR_IBEAM,
	// Cross shape
	MOUSE_CURSOR_CROSSHAIR,
	// Pointing hand cursor
	MOUSE_CURSOR_POINTING_HAND,
	// Horizontal resize/move arrow shape
	MOUSE_CURSOR_RESIZE_EW,
	// Vertical resize/move arrow shape
	MOUSE_CURSOR_RESIZE_NS,
	// Top-left to bottom-right diagonal resize/move arrow shape
	MOUSE_CURSOR_RESIZE_NWSE,
	// The top-right to bottom-left diagonal resize/move arrow shape
	MOUSE_CURSOR_RESIZE_NESW,
	// The omnidirectional resize/move cursor shape
	MOUSE_CURSOR_RESIZE_ALL,
	// The operation-not-allowed shape
	MOUSE_CURSOR_NOT_ALLOWED,
}

// Gamepad buttons
GamepadButton :: enum u32 {
	// Unknown button, for error checking
	GAMEPAD_BUTTON_UNKNOWN,
	// Gamepad left DPAD up button
	GAMEPAD_BUTTON_LEFT_FACE_UP,
	// Gamepad left DPAD right button
	GAMEPAD_BUTTON_LEFT_FACE_RIGHT,
	// Gamepad left DPAD down button
	GAMEPAD_BUTTON_LEFT_FACE_DOWN,
	// Gamepad left DPAD left button
	GAMEPAD_BUTTON_LEFT_FACE_LEFT,
	// Gamepad right button up (i.e. PS3: Triangle, Xbox: Y)
	GAMEPAD_BUTTON_RIGHT_FACE_UP,
	// Gamepad right button right (i.e. PS3: Circle, Xbox: B)
	GAMEPAD_BUTTON_RIGHT_FACE_RIGHT,
	// Gamepad right button down (i.e. PS3: Cross, Xbox: A)
	GAMEPAD_BUTTON_RIGHT_FACE_DOWN,
	// Gamepad right button left (i.e. PS3: Square, Xbox: X)
	GAMEPAD_BUTTON_RIGHT_FACE_LEFT,
	// Gamepad top/back trigger left (first), it could be a trailing button
	GAMEPAD_BUTTON_LEFT_TRIGGER_1,
	// Gamepad top/back trigger left (second), it could be a trailing button
	GAMEPAD_BUTTON_LEFT_TRIGGER_2,
	// Gamepad top/back trigger right (first), it could be a trailing button
	GAMEPAD_BUTTON_RIGHT_TRIGGER_1,
	// Gamepad top/back trigger right (second), it could be a trailing button
	GAMEPAD_BUTTON_RIGHT_TRIGGER_2,
	// Gamepad center buttons, left one (i.e. PS3: Select)
	GAMEPAD_BUTTON_MIDDLE_LEFT,
	// Gamepad center buttons, middle one (i.e. PS3: PS, Xbox: XBOX)
	GAMEPAD_BUTTON_MIDDLE,
	// Gamepad center buttons, right one (i.e. PS3: Start)
	GAMEPAD_BUTTON_MIDDLE_RIGHT,
	// Gamepad joystick pressed button left
	GAMEPAD_BUTTON_LEFT_THUMB,
	// Gamepad joystick pressed button right
	GAMEPAD_BUTTON_RIGHT_THUMB,
}

// Gamepad axes
GamepadAxis :: enum u32 {
	// Gamepad left stick X axis
	GAMEPAD_AXIS_LEFT_X,
	// Gamepad left stick Y axis
	GAMEPAD_AXIS_LEFT_Y,
	// Gamepad right stick X axis
	GAMEPAD_AXIS_RIGHT_X,
	// Gamepad right stick Y axis
	GAMEPAD_AXIS_RIGHT_Y,
	// Gamepad back trigger left, pressure level: [1..-1]
	GAMEPAD_AXIS_LEFT_TRIGGER,
	// Gamepad back trigger right, pressure level: [1..-1]
	GAMEPAD_AXIS_RIGHT_TRIGGER,
}

// Material map index
MaterialMapIndex :: enum u32 {
	// Albedo material (same as: MATERIAL_MAP_DIFFUSE)
	MATERIAL_MAP_ALBEDO,
	// Metalness material (same as: MATERIAL_MAP_SPECULAR)
	MATERIAL_MAP_METALNESS,
	// Normal material
	MATERIAL_MAP_NORMAL,
	// Roughness material
	MATERIAL_MAP_ROUGHNESS,
	// Ambient occlusion material
	MATERIAL_MAP_OCCLUSION,
	// Emission material
	MATERIAL_MAP_EMISSION,
	// Heightmap material
	MATERIAL_MAP_HEIGHT,
	// Cubemap material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	MATERIAL_MAP_CUBEMAP,
	// Irradiance material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	MATERIAL_MAP_IRRADIANCE,
	// Prefilter material (NOTE: Uses GL_TEXTURE_CUBE_MAP)
	MATERIAL_MAP_PREFILTER,
	// Brdf material
	MATERIAL_MAP_BRDF,
}

// Shader location index
// NOTE: Some locations are tried to be set automatically on shader loading,
// but only if default attributes/uniforms names are found, check config.h for names
ShaderLocationIndex :: enum u32 {
	// Shader location: vertex attribute: position
	SHADER_LOC_VERTEX_POSITION,
	// Shader location: vertex attribute: texcoord01
	SHADER_LOC_VERTEX_TEXCOORD01,
	// Shader location: vertex attribute: texcoord02
	SHADER_LOC_VERTEX_TEXCOORD02,
	// Shader location: vertex attribute: normal
	SHADER_LOC_VERTEX_NORMAL,
	// Shader location: vertex attribute: tangent
	SHADER_LOC_VERTEX_TANGENT,
	// Shader location: vertex attribute: color
	SHADER_LOC_VERTEX_COLOR,
	// Shader location: matrix uniform: model-view-projection
	SHADER_LOC_MATRIX_MVP,
	// Shader location: matrix uniform: view (camera transform)
	SHADER_LOC_MATRIX_VIEW,
	// Shader location: matrix uniform: projection
	SHADER_LOC_MATRIX_PROJECTION,
	// Shader location: matrix uniform: model (transform)
	SHADER_LOC_MATRIX_MODEL,
	// Shader location: matrix uniform: normal
	SHADER_LOC_MATRIX_NORMAL,
	// Shader location: vector uniform: view
	SHADER_LOC_VECTOR_VIEW,
	// Shader location: vector uniform: diffuse color
	SHADER_LOC_COLOR_DIFFUSE,
	// Shader location: vector uniform: specular color
	SHADER_LOC_COLOR_SPECULAR,
	// Shader location: vector uniform: ambient color
	SHADER_LOC_COLOR_AMBIENT,
	// Shader location: sampler2d texture: albedo (same as: SHADER_LOC_MAP_DIFFUSE)
	SHADER_LOC_MAP_ALBEDO,
	// Shader location: sampler2d texture: metalness (same as: SHADER_LOC_MAP_SPECULAR)
	SHADER_LOC_MAP_METALNESS,
	// Shader location: sampler2d texture: normal
	SHADER_LOC_MAP_NORMAL,
	// Shader location: sampler2d texture: roughness
	SHADER_LOC_MAP_ROUGHNESS,
	// Shader location: sampler2d texture: occlusion
	SHADER_LOC_MAP_OCCLUSION,
	// Shader location: sampler2d texture: emission
	SHADER_LOC_MAP_EMISSION,
	// Shader location: sampler2d texture: heightmap
	SHADER_LOC_MAP_HEIGHT,
	// Shader location: samplerCube texture: cubemap
	SHADER_LOC_MAP_CUBEMAP,
	// Shader location: samplerCube texture: irradiance
	SHADER_LOC_MAP_IRRADIANCE,
	// Shader location: samplerCube texture: prefilter
	SHADER_LOC_MAP_PREFILTER,
	// Shader location: sampler2d texture: brdf
	SHADER_LOC_MAP_BRDF,
	// Shader location: vertex attribute: bone indices
	SHADER_LOC_VERTEX_BONEIDS,
	// Shader location: vertex attribute: bone weights
	SHADER_LOC_VERTEX_BONEWEIGHTS,
	// Shader location: matrix attribute: bone transforms (animation)
	SHADER_LOC_MATRIX_BONETRANSFORMS,
	// Shader location: vertex attribute: instance transforms
	SHADER_LOC_VERTEX_INSTANCETRANSFORM,
}

// Shader uniform data type
ShaderUniformDataType :: enum u32 {
	// Shader uniform type: float
	SHADER_UNIFORM_FLOAT,
	// Shader uniform type: vec2 (2 float)
	SHADER_UNIFORM_VEC2,
	// Shader uniform type: vec3 (3 float)
	SHADER_UNIFORM_VEC3,
	// Shader uniform type: vec4 (4 float)
	SHADER_UNIFORM_VEC4,
	// Shader uniform type: int
	SHADER_UNIFORM_INT,
	// Shader uniform type: ivec2 (2 int)
	SHADER_UNIFORM_IVEC2,
	// Shader uniform type: ivec3 (3 int)
	SHADER_UNIFORM_IVEC3,
	// Shader uniform type: ivec4 (4 int)
	SHADER_UNIFORM_IVEC4,
	// Shader uniform type: unsigned int
	SHADER_UNIFORM_UINT,
	// Shader uniform type: uivec2 (2 unsigned int)
	SHADER_UNIFORM_UIVEC2,
	// Shader uniform type: uivec3 (3 unsigned int)
	SHADER_UNIFORM_UIVEC3,
	// Shader uniform type: uivec4 (4 unsigned int)
	SHADER_UNIFORM_UIVEC4,
	// Shader uniform type: sampler2d
	SHADER_UNIFORM_SAMPLER2D,
}

// Shader attribute data types
ShaderAttributeDataType :: enum u32 {
	// Shader attribute type: float
	SHADER_ATTRIB_FLOAT,
	// Shader attribute type: vec2 (2 float)
	SHADER_ATTRIB_VEC2,
	// Shader attribute type: vec3 (3 float)
	SHADER_ATTRIB_VEC3,
	// Shader attribute type: vec4 (4 float)
	SHADER_ATTRIB_VEC4,
}

// Pixel formats
// NOTE: Support depends on OpenGL version and platform
PixelFormat :: enum u32 {
	// 8 bit per pixel (no alpha)
	PIXELFORMAT_UNCOMPRESSED_GRAYSCALE = 1,
	// 8*2 bpp (2 channels)
	PIXELFORMAT_UNCOMPRESSED_GRAY_ALPHA,
	// 16 bpp
	PIXELFORMAT_UNCOMPRESSED_R5G6B5,
	// 24 bpp
	PIXELFORMAT_UNCOMPRESSED_R8G8B8,
	// 16 bpp (1 bit alpha)
	PIXELFORMAT_UNCOMPRESSED_R5G5B5A1,
	// 16 bpp (4 bit alpha)
	PIXELFORMAT_UNCOMPRESSED_R4G4B4A4,
	// 32 bpp
	PIXELFORMAT_UNCOMPRESSED_R8G8B8A8,
	// 32 bpp (1 channel - float)
	PIXELFORMAT_UNCOMPRESSED_R32,
	// 32*3 bpp (3 channels - float)
	PIXELFORMAT_UNCOMPRESSED_R32G32B32,
	// 32*4 bpp (4 channels - float)
	PIXELFORMAT_UNCOMPRESSED_R32G32B32A32,
	// 16 bpp (1 channel - half float)
	PIXELFORMAT_UNCOMPRESSED_R16,
	// 16*3 bpp (3 channels - half float)
	PIXELFORMAT_UNCOMPRESSED_R16G16B16,
	// 16*4 bpp (4 channels - half float)
	PIXELFORMAT_UNCOMPRESSED_R16G16B16A16,
	// 4 bpp (no alpha)
	PIXELFORMAT_COMPRESSED_DXT1_RGB,
	// 4 bpp (1 bit alpha)
	PIXELFORMAT_COMPRESSED_DXT1_RGBA,
	// 8 bpp
	PIXELFORMAT_COMPRESSED_DXT3_RGBA,
	// 8 bpp
	PIXELFORMAT_COMPRESSED_DXT5_RGBA,
	// 4 bpp
	PIXELFORMAT_COMPRESSED_ETC1_RGB,
	// 4 bpp
	PIXELFORMAT_COMPRESSED_ETC2_RGB,
	// 8 bpp
	PIXELFORMAT_COMPRESSED_ETC2_EAC_RGBA,
	// 4 bpp
	PIXELFORMAT_COMPRESSED_PVRT_RGB,
	// 4 bpp
	PIXELFORMAT_COMPRESSED_PVRT_RGBA,
	// 8 bpp
	PIXELFORMAT_COMPRESSED_ASTC_4x4_RGBA,
	// 2 bpp
	PIXELFORMAT_COMPRESSED_ASTC_8x8_RGBA,
}

// Texture parameters: filter mode
// NOTE 1: Filtering considers mipmaps if available in the texture
// NOTE 2: Filter is accordingly set for minification and magnification
TextureFilter :: enum u32 {
	// No filter, pixel approximation
	TEXTURE_FILTER_POINT,
	// Linear filtering
	TEXTURE_FILTER_BILINEAR,
	// Trilinear filtering (linear with mipmaps)
	TEXTURE_FILTER_TRILINEAR,
	// Anisotropic filtering 4x
	TEXTURE_FILTER_ANISOTROPIC_4X,
	// Anisotropic filtering 8x
	TEXTURE_FILTER_ANISOTROPIC_8X,
	// Anisotropic filtering 16x
	TEXTURE_FILTER_ANISOTROPIC_16X,
}

// Texture parameters: wrap mode
TextureWrap :: enum u32 {
	// Repeats texture in tiled mode
	TEXTURE_WRAP_REPEAT,
	// Clamps texture to edge pixel in tiled mode
	TEXTURE_WRAP_CLAMP,
	// Mirrors and repeats the texture in tiled mode
	TEXTURE_WRAP_MIRROR_REPEAT,
	// Mirrors and clamps to border the texture in tiled mode
	TEXTURE_WRAP_MIRROR_CLAMP,
}

// Cubemap layouts
CubemapLayout :: enum u32 {
	// Automatically detect layout type
	CUBEMAP_LAYOUT_AUTO_DETECT,
	// Layout is defined by a vertical line with faces
	CUBEMAP_LAYOUT_LINE_VERTICAL,
	// Layout is defined by a horizontal line with faces
	CUBEMAP_LAYOUT_LINE_HORIZONTAL,
	// Layout is defined by a 3x4 cross with cubemap faces
	CUBEMAP_LAYOUT_CROSS_THREE_BY_FOUR,
	// Layout is defined by a 4x3 cross with cubemap faces
	CUBEMAP_LAYOUT_CROSS_FOUR_BY_THREE,
}

// Font type, defines generation method
FontType :: enum u32 {
	// Default font generation, anti-aliased
	FONT_DEFAULT,
	// Bitmap font generation, no anti-aliasing
	FONT_BITMAP,
	// SDF font generation, requires external shader
	FONT_SDF,
}

// Color blending modes (pre-defined)
BlendMode :: enum u32 {
	// Blend textures considering alpha (default)
	BLEND_ALPHA,
	// Blend textures adding colors
	BLEND_ADDITIVE,
	// Blend textures multiplying colors
	BLEND_MULTIPLIED,
	// Blend textures adding colors (alternative)
	BLEND_ADD_COLORS,
	// Blend textures subtracting colors (alternative)
	BLEND_SUBTRACT_COLORS,
	// Blend premultiplied textures considering alpha
	BLEND_ALPHA_PREMULTIPLY,
	// Blend textures using custom src/dst factors (use rlSetBlendFactors())
	BLEND_CUSTOM,
	// Blend textures using custom rgb/alpha separate src/dst factors (use rlSetBlendFactorsSeparate())
	BLEND_CUSTOM_SEPARATE,
}

// Gesture
// NOTE: Provided as bit-wise flags to enable only desired gestures
Gesture :: enum u32 {
	// No gesture
	GESTURE_NONE,
	// Tap gesture
	GESTURE_TAP,
	// Double tap gesture
	GESTURE_DOUBLETAP,
	// Hold gesture
	GESTURE_HOLD = 4,
	// Drag gesture
	GESTURE_DRAG = 8,
	// Swipe right gesture
	GESTURE_SWIPE_RIGHT = 16,
	// Swipe left gesture
	GESTURE_SWIPE_LEFT = 32,
	// Swipe up gesture
	GESTURE_SWIPE_UP = 64,
	// Swipe down gesture
	GESTURE_SWIPE_DOWN = 128,
	// Pinch in gesture
	GESTURE_PINCH_IN = 256,
	// Pinch out gesture
	GESTURE_PINCH_OUT = 512,
}

// Camera system modes
CameraMode :: enum u32 {
	// Camera custom, controlled by user (UpdateCamera() does nothing)
	CAMERA_CUSTOM,
	// Camera free mode
	CAMERA_FREE,
	// Camera orbital, around target, zoom supported
	CAMERA_ORBITAL,
	// Camera first person
	CAMERA_FIRST_PERSON,
	// Camera third person
	CAMERA_THIRD_PERSON,
}

// Camera projection
CameraProjection :: enum u32 {
	// Perspective projection
	CAMERA_PERSPECTIVE,
	// Orthographic projection
	CAMERA_ORTHOGRAPHIC,
}

// N-patch layout
NPatchLayout :: enum u32 {
	// Npatch layout: 3x3 tiles
	NPATCH_NINE_PATCH,
	// Npatch layout: 1x3 tiles
	NPATCH_THREE_PATCH_VERTICAL,
	// Npatch layout: 3x1 tiles
	NPATCH_THREE_PATCH_HORIZONTAL,
}

// Callbacks to hook some internal functions
// WARNING: These callbacks are intended for advanced users
TraceLogCallback :: proc "c" (_: i32, _: cstring, _: __builtin_va_list)

__builtin_va_list :: [1]__va_list_tag

__va_list_tag :: struct {
	gp_offset:         u32,
	fp_offset:         u32,
	overflow_arg_area: rawptr,
	reg_save_area:     rawptr,
}

LoadFileDataCallback :: proc "c" (_: cstring, _: ^i32) -> ^u8

SaveFileDataCallback :: proc "c" (_: cstring, _: rawptr, _: i32) -> bool

LoadFileTextCallback :: proc "c" (_: cstring) -> ^u8

SaveFileTextCallback :: proc "c" (_: cstring, _: cstring) -> bool

//------------------------------------------------------------------------------------
// Audio Loading and Playing Functions (Module: audio)
//------------------------------------------------------------------------------------
AudioCallback :: proc "c" (_: rawptr, _: u32)

foreign lib {
	// Window-related functions
	InitWindow :: proc(width: i32, height: i32, title: cstring) ---
	CloseWindow :: proc() ---
	WindowShouldClose :: proc() -> bool ---
	IsWindowReady :: proc() -> bool ---
	IsWindowFullscreen :: proc() -> bool ---
	IsWindowHidden :: proc() -> bool ---
	IsWindowMinimized :: proc() -> bool ---
	IsWindowMaximized :: proc() -> bool ---
	IsWindowFocused :: proc() -> bool ---
	IsWindowResized :: proc() -> bool ---
	IsWindowState :: proc(flag: u32) -> bool ---
	SetWindowState :: proc(flags: u32) ---
	ClearWindowState :: proc(flags: u32) ---
	ToggleFullscreen :: proc() ---
	ToggleBorderlessWindowed :: proc() ---
	MaximizeWindow :: proc() ---
	MinimizeWindow :: proc() ---
	RestoreWindow :: proc() ---
	SetWindowIcon :: proc(image: Image) ---
	SetWindowIcons :: proc(images: ^Image, count: i32) ---
	SetWindowTitle :: proc(title: cstring) ---
	SetWindowPosition :: proc(x: i32, y: i32) ---
	SetWindowMonitor :: proc(monitor: i32) ---
	SetWindowMinSize :: proc(width: i32, height: i32) ---
	SetWindowMaxSize :: proc(width: i32, height: i32) ---
	SetWindowSize :: proc(width: i32, height: i32) ---
	SetWindowOpacity :: proc(opacity: f32) ---
	SetWindowFocused :: proc() ---
	GetWindowHandle :: proc() -> rawptr ---
	GetScreenWidth :: proc() -> i32 ---
	GetScreenHeight :: proc() -> i32 ---
	GetRenderWidth :: proc() -> i32 ---
	GetRenderHeight :: proc() -> i32 ---
	GetMonitorCount :: proc() -> i32 ---
	GetCurrentMonitor :: proc() -> i32 ---
	GetMonitorPosition :: proc(monitor: i32) -> Vector2 ---
	GetMonitorWidth :: proc(monitor: i32) -> i32 ---
	GetMonitorHeight :: proc(monitor: i32) -> i32 ---
	GetMonitorPhysicalWidth :: proc(monitor: i32) -> i32 ---
	GetMonitorPhysicalHeight :: proc(monitor: i32) -> i32 ---
	GetMonitorRefreshRate :: proc(monitor: i32) -> i32 ---
	GetWindowPosition :: proc() -> Vector2 ---
	GetWindowScaleDPI :: proc() -> Vector2 ---
	GetMonitorName :: proc(monitor: i32) -> cstring ---
	SetClipboardText :: proc(text: cstring) ---
	GetClipboardText :: proc() -> cstring ---
	GetClipboardImage :: proc() -> Image ---
	EnableEventWaiting :: proc() ---
	DisableEventWaiting :: proc() ---
	// Cursor-related functions
	ShowCursor :: proc() ---
	HideCursor :: proc() ---
	IsCursorHidden :: proc() -> bool ---
	EnableCursor :: proc() ---
	DisableCursor :: proc() ---
	IsCursorOnScreen :: proc() -> bool ---
	// Drawing-related functions
	ClearBackground :: proc(color: Color) ---
	BeginDrawing :: proc() ---
	EndDrawing :: proc() ---
	BeginMode2D :: proc(camera: Camera2D) ---
	EndMode2D :: proc() ---
	BeginMode3D :: proc(camera: Camera3D) ---
	EndMode3D :: proc() ---
	BeginTextureMode :: proc(target: RenderTexture2D) ---
	EndTextureMode :: proc() ---
	BeginShaderMode :: proc(shader: Shader) ---
	EndShaderMode :: proc() ---
	BeginBlendMode :: proc(mode: i32) ---
	EndBlendMode :: proc() ---
	BeginScissorMode :: proc(x: i32, y: i32, width: i32, height: i32) ---
	EndScissorMode :: proc() ---
	BeginVrStereoMode :: proc(config: VrStereoConfig) ---
	EndVrStereoMode :: proc() ---
	// VR stereo config functions for VR simulator
	LoadVrStereoConfig :: proc(device: VrDeviceInfo) -> VrStereoConfig ---
	UnloadVrStereoConfig :: proc(config: VrStereoConfig) ---
	// Shader management functions
	// NOTE: Shader functionality is not available on OpenGL 1.1
	LoadShader :: proc(vsFileName: cstring, fsFileName: cstring) -> Shader ---
	LoadShaderFromMemory :: proc(vsCode: cstring, fsCode: cstring) -> Shader ---
	IsShaderValid :: proc(shader: Shader) -> bool ---
	GetShaderLocation :: proc(shader: Shader, uniformName: cstring) -> i32 ---
	GetShaderLocationAttrib :: proc(shader: Shader, attribName: cstring) -> i32 ---
	SetShaderValue :: proc(shader: Shader, locIndex: i32, value: rawptr, uniformType: i32) ---
	SetShaderValueV :: proc(shader: Shader, locIndex: i32, value: rawptr, uniformType: i32, count: i32) ---
	SetShaderValueMatrix :: proc(shader: Shader, locIndex: i32, mat: Matrix) ---
	SetShaderValueTexture :: proc(shader: Shader, locIndex: i32, texture: Texture2D) ---
	UnloadShader :: proc(shader: Shader) ---
	GetScreenToWorldRay :: proc(position: Vector2, camera: Camera) -> Ray ---
	GetScreenToWorldRayEx :: proc(position: Vector2, camera: Camera, width: i32, height: i32) -> Ray ---
	GetWorldToScreen :: proc(position: Vector3, camera: Camera) -> Vector2 ---
	GetWorldToScreenEx :: proc(position: Vector3, camera: Camera, width: i32, height: i32) -> Vector2 ---
	GetWorldToScreen2D :: proc(position: Vector2, camera: Camera2D) -> Vector2 ---
	GetScreenToWorld2D :: proc(position: Vector2, camera: Camera2D) -> Vector2 ---
	GetCameraMatrix :: proc(camera: Camera) -> Matrix ---
	GetCameraMatrix2D :: proc(camera: Camera2D) -> Matrix ---
	// Timing-related functions
	SetTargetFPS :: proc(fps: i32) ---
	GetFrameTime :: proc() -> f32 ---
	GetTime :: proc() -> f64 ---
	GetFPS :: proc() -> i32 ---
	// Custom frame control functions
	// NOTE: Those functions are intended for advanced users that want full control over the frame processing
	// By default EndDrawing() does this job: draws everything + SwapScreenBuffer() + manage frame timing + PollInputEvents()
	// To avoid that behaviour and control frame processes manually, enable in config.h: SUPPORT_CUSTOM_FRAME_CONTROL
	SwapScreenBuffer :: proc() ---
	PollInputEvents :: proc() ---
	WaitTime :: proc(seconds: f64) ---
	// Random values generation functions
	SetRandomSeed :: proc(seed: u32) ---
	GetRandomValue :: proc(min: i32, max: i32) -> i32 ---
	LoadRandomSequence :: proc(count: u32, min: i32, max: i32) -> ^i32 ---
	UnloadRandomSequence :: proc(sequence: ^i32) ---
	// Misc. functions
	TakeScreenshot :: proc(fileName: cstring) ---
	SetConfigFlags :: proc(flags: u32) ---
	OpenURL :: proc(url: cstring) ---
	// Logging system
	SetTraceLogLevel :: proc(logLevel: i32) ---
	TraceLog :: proc(logLevel: i32, text: cstring, #c_vararg _: ..any) ---
	SetTraceLogCallback :: proc(callback: TraceLogCallback) ---
	// Memory management, using internal allocators
	MemAlloc :: proc(size: u32) -> rawptr ---
	MemRealloc :: proc(ptr: rawptr, size: u32) -> rawptr ---
	MemFree :: proc(ptr: rawptr) ---
	// File system management functions
	LoadFileData :: proc(fileName: cstring, dataSize: ^i32) -> ^u8 ---
	UnloadFileData :: proc(data: ^u8) ---
	SaveFileData :: proc(fileName: cstring, data: rawptr, dataSize: i32) -> bool ---
	ExportDataAsCode :: proc(data: ^u8, dataSize: i32, fileName: cstring) -> bool ---
	LoadFileText :: proc(fileName: cstring) -> ^u8 ---
	UnloadFileText :: proc(text: ^u8) ---
	SaveFileText :: proc(fileName: cstring, text: cstring) -> bool ---
	// File access custom callbacks
	// WARNING: Callbacks setup is intended for advanced users
	SetLoadFileDataCallback :: proc(callback: LoadFileDataCallback) ---
	SetSaveFileDataCallback :: proc(callback: SaveFileDataCallback) ---
	SetLoadFileTextCallback :: proc(callback: LoadFileTextCallback) ---
	SetSaveFileTextCallback :: proc(callback: SaveFileTextCallback) ---
	FileRename :: proc(fileName: cstring, fileRename: cstring) -> i32 ---
	FileRemove :: proc(fileName: cstring) -> i32 ---
	FileCopy :: proc(srcPath: cstring, dstPath: cstring) -> i32 ---
	FileMove :: proc(srcPath: cstring, dstPath: cstring) -> i32 ---
	FileTextReplace :: proc(fileName: cstring, search: cstring, replacement: cstring) -> i32 ---
	FileTextFindIndex :: proc(fileName: cstring, search: cstring) -> i32 ---
	FileExists :: proc(fileName: cstring) -> bool ---
	DirectoryExists :: proc(dirPath: cstring) -> bool ---
	IsFileExtension :: proc(fileName: cstring, ext: cstring) -> bool ---
	GetFileLength :: proc(fileName: cstring) -> i32 ---
	GetFileModTime :: proc(fileName: cstring) -> i64 ---
	GetFileExtension :: proc(fileName: cstring) -> cstring ---
	GetFileName :: proc(filePath: cstring) -> cstring ---
	GetFileNameWithoutExt :: proc(filePath: cstring) -> cstring ---
	GetDirectoryPath :: proc(filePath: cstring) -> cstring ---
	GetPrevDirectoryPath :: proc(dirPath: cstring) -> cstring ---
	GetWorkingDirectory :: proc() -> cstring ---
	GetApplicationDirectory :: proc() -> cstring ---
	MakeDirectory :: proc(dirPath: cstring) -> i32 ---
	ChangeDirectory :: proc(dirPath: cstring) -> bool ---
	IsPathFile :: proc(path: cstring) -> bool ---
	IsFileNameValid :: proc(fileName: cstring) -> bool ---
	LoadDirectoryFiles :: proc(dirPath: cstring) -> FilePathList ---
	LoadDirectoryFilesEx :: proc(basePath: cstring, filter: cstring, scanSubdirs: bool) -> FilePathList ---
	UnloadDirectoryFiles :: proc(files: FilePathList) ---
	IsFileDropped :: proc() -> bool ---
	LoadDroppedFiles :: proc() -> FilePathList ---
	UnloadDroppedFiles :: proc(files: FilePathList) ---
	GetDirectoryFileCount :: proc(dirPath: cstring) -> u32 ---
	GetDirectoryFileCountEx :: proc(basePath: cstring, filter: cstring, scanSubdirs: bool) -> u32 ---
	// Compression/Encoding functionality
	CompressData :: proc(data: ^u8, dataSize: i32, compDataSize: ^i32) -> ^u8 ---
	DecompressData :: proc(compData: ^u8, compDataSize: i32, dataSize: ^i32) -> ^u8 ---
	EncodeDataBase64 :: proc(data: ^u8, dataSize: i32, outputSize: ^i32) -> ^u8 ---
	DecodeDataBase64 :: proc(text: cstring, outputSize: ^i32) -> ^u8 ---
	ComputeCRC32 :: proc(data: ^u8, dataSize: i32) -> u32 ---
	ComputeMD5 :: proc(data: ^u8, dataSize: i32) -> ^u32 ---
	ComputeSHA1 :: proc(data: ^u8, dataSize: i32) -> ^u32 ---
	ComputeSHA256 :: proc(data: ^u8, dataSize: i32) -> ^u32 ---
	// Automation events functionality
	LoadAutomationEventList :: proc(fileName: cstring) -> AutomationEventList ---
	UnloadAutomationEventList :: proc(list: AutomationEventList) ---
	ExportAutomationEventList :: proc(list: AutomationEventList, fileName: cstring) -> bool ---
	SetAutomationEventList :: proc(list: ^AutomationEventList) ---
	SetAutomationEventBaseFrame :: proc(frame: i32) ---
	StartAutomationEventRecording :: proc() ---
	StopAutomationEventRecording :: proc() ---
	PlayAutomationEvent :: proc(event: AutomationEvent) ---
	// Input-related functions: keyboard
	IsKeyPressed :: proc(key: i32) -> bool ---
	IsKeyPressedRepeat :: proc(key: i32) -> bool ---
	IsKeyDown :: proc(key: i32) -> bool ---
	IsKeyReleased :: proc(key: i32) -> bool ---
	IsKeyUp :: proc(key: i32) -> bool ---
	GetKeyPressed :: proc() -> i32 ---
	GetCharPressed :: proc() -> i32 ---
	GetKeyName :: proc(key: i32) -> cstring ---
	SetExitKey :: proc(key: i32) ---
	// Input-related functions: gamepads
	IsGamepadAvailable :: proc(gamepad: i32) -> bool ---
	GetGamepadName :: proc(gamepad: i32) -> cstring ---
	IsGamepadButtonPressed :: proc(gamepad: i32, button: i32) -> bool ---
	IsGamepadButtonDown :: proc(gamepad: i32, button: i32) -> bool ---
	IsGamepadButtonReleased :: proc(gamepad: i32, button: i32) -> bool ---
	IsGamepadButtonUp :: proc(gamepad: i32, button: i32) -> bool ---
	GetGamepadButtonPressed :: proc() -> i32 ---
	GetGamepadAxisCount :: proc(gamepad: i32) -> i32 ---
	GetGamepadAxisMovement :: proc(gamepad: i32, axis: i32) -> f32 ---
	SetGamepadMappings :: proc(mappings: cstring) -> i32 ---
	SetGamepadVibration :: proc(gamepad: i32, leftMotor: f32, rightMotor: f32, duration: f32) ---
	// Input-related functions: mouse
	IsMouseButtonPressed :: proc(button: i32) -> bool ---
	IsMouseButtonDown :: proc(button: i32) -> bool ---
	IsMouseButtonReleased :: proc(button: i32) -> bool ---
	IsMouseButtonUp :: proc(button: i32) -> bool ---
	GetMouseX :: proc() -> i32 ---
	GetMouseY :: proc() -> i32 ---
	GetMousePosition :: proc() -> Vector2 ---
	GetMouseDelta :: proc() -> Vector2 ---
	SetMousePosition :: proc(x: i32, y: i32) ---
	SetMouseOffset :: proc(offsetX: i32, offsetY: i32) ---
	SetMouseScale :: proc(scaleX: f32, scaleY: f32) ---
	GetMouseWheelMove :: proc() -> f32 ---
	GetMouseWheelMoveV :: proc() -> Vector2 ---
	SetMouseCursor :: proc(cursor: i32) ---
	// Input-related functions: touch
	GetTouchX :: proc() -> i32 ---
	GetTouchY :: proc() -> i32 ---
	GetTouchPosition :: proc(index: i32) -> Vector2 ---
	GetTouchPointId :: proc(index: i32) -> i32 ---
	GetTouchPointCount :: proc() -> i32 ---
	//------------------------------------------------------------------------------------
	// Gestures and Touch Handling Functions (Module: rgestures)
	//------------------------------------------------------------------------------------
	SetGesturesEnabled :: proc(flags: u32) ---
	IsGestureDetected :: proc(gesture: u32) -> bool ---
	GetGestureDetected :: proc() -> i32 ---
	GetGestureHoldDuration :: proc() -> f32 ---
	GetGestureDragVector :: proc() -> Vector2 ---
	GetGestureDragAngle :: proc() -> f32 ---
	GetGesturePinchVector :: proc() -> Vector2 ---
	GetGesturePinchAngle :: proc() -> f32 ---
	//------------------------------------------------------------------------------------
	// Camera System Functions (Module: rcamera)
	//------------------------------------------------------------------------------------
	UpdateCamera :: proc(camera: ^Camera, mode: i32) ---
	UpdateCameraPro :: proc(camera: ^Camera, movement: Vector3, rotation: Vector3, zoom: f32) ---
	//------------------------------------------------------------------------------------
	// Basic Shapes Drawing Functions (Module: shapes)
	//------------------------------------------------------------------------------------
	// Set texture and rectangle to be used on shapes drawing
	// NOTE: It can be useful when using basic shapes and one single font,
	// defining a font char white rectangle would allow drawing everything in a single draw call
	SetShapesTexture :: proc(texture: Texture2D, source: Rectangle) ---
	GetShapesTexture :: proc() -> Texture2D ---
	GetShapesTextureRectangle :: proc() -> Rectangle ---
	// Basic shapes drawing functions
	DrawPixel :: proc(posX: i32, posY: i32, color: Color) ---
	DrawPixelV :: proc(position: Vector2, color: Color) ---
	DrawLine :: proc(startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, color: Color) ---
	DrawLineV :: proc(startPos: Vector2, endPos: Vector2, color: Color) ---
	DrawLineEx :: proc(startPos: Vector2, endPos: Vector2, thick: f32, color: Color) ---
	DrawLineStrip :: proc(points: ^Vector2, pointCount: i32, color: Color) ---
	DrawLineBezier :: proc(startPos: Vector2, endPos: Vector2, thick: f32, color: Color) ---
	DrawLineDashed :: proc(startPos: Vector2, endPos: Vector2, dashSize: i32, spaceSize: i32, color: Color) ---
	DrawCircle :: proc(centerX: i32, centerY: i32, radius: f32, color: Color) ---
	DrawCircleV :: proc(center: Vector2, radius: f32, color: Color) ---
	DrawCircleGradient :: proc(center: Vector2, radius: f32, inner: Color, outer: Color) ---
	DrawCircleSector :: proc(center: Vector2, radius: f32, startAngle: f32, endAngle: f32, segments: i32, color: Color) ---
	DrawCircleSectorLines :: proc(center: Vector2, radius: f32, startAngle: f32, endAngle: f32, segments: i32, color: Color) ---
	DrawCircleLines :: proc(centerX: i32, centerY: i32, radius: f32, color: Color) ---
	DrawCircleLinesV :: proc(center: Vector2, radius: f32, color: Color) ---
	DrawEllipse :: proc(centerX: i32, centerY: i32, radiusH: f32, radiusV: f32, color: Color) ---
	DrawEllipseV :: proc(center: Vector2, radiusH: f32, radiusV: f32, color: Color) ---
	DrawEllipseLines :: proc(centerX: i32, centerY: i32, radiusH: f32, radiusV: f32, color: Color) ---
	DrawEllipseLinesV :: proc(center: Vector2, radiusH: f32, radiusV: f32, color: Color) ---
	DrawRing :: proc(center: Vector2, innerRadius: f32, outerRadius: f32, startAngle: f32, endAngle: f32, segments: i32, color: Color) ---
	DrawRingLines :: proc(center: Vector2, innerRadius: f32, outerRadius: f32, startAngle: f32, endAngle: f32, segments: i32, color: Color) ---
	DrawRectangle :: proc(posX: i32, posY: i32, width: i32, height: i32, color: Color) ---
	DrawRectangleV :: proc(position: Vector2, size: Vector2, color: Color) ---
	DrawRectangleRec :: proc(rec: Rectangle, color: Color) ---
	DrawRectanglePro :: proc(rec: Rectangle, origin: Vector2, rotation: f32, color: Color) ---
	DrawRectangleGradientV :: proc(posX: i32, posY: i32, width: i32, height: i32, top: Color, bottom: Color) ---
	DrawRectangleGradientH :: proc(posX: i32, posY: i32, width: i32, height: i32, left: Color, right: Color) ---
	DrawRectangleGradientEx :: proc(rec: Rectangle, topLeft: Color, bottomLeft: Color, bottomRight: Color, topRight: Color) ---
	DrawRectangleLines :: proc(posX: i32, posY: i32, width: i32, height: i32, color: Color) ---
	DrawRectangleLinesEx :: proc(rec: Rectangle, lineThick: f32, color: Color) ---
	DrawRectangleRounded :: proc(rec: Rectangle, roundness: f32, segments: i32, color: Color) ---
	DrawRectangleRoundedLines :: proc(rec: Rectangle, roundness: f32, segments: i32, color: Color) ---
	DrawRectangleRoundedLinesEx :: proc(rec: Rectangle, roundness: f32, segments: i32, lineThick: f32, color: Color) ---
	DrawTriangle :: proc(v1: Vector2, v2: Vector2, v3: Vector2, color: Color) ---
	DrawTriangleLines :: proc(v1: Vector2, v2: Vector2, v3: Vector2, color: Color) ---
	DrawTriangleFan :: proc(points: ^Vector2, pointCount: i32, color: Color) ---
	DrawTriangleStrip :: proc(points: ^Vector2, pointCount: i32, color: Color) ---
	DrawPoly :: proc(center: Vector2, sides: i32, radius: f32, rotation: f32, color: Color) ---
	DrawPolyLines :: proc(center: Vector2, sides: i32, radius: f32, rotation: f32, color: Color) ---
	DrawPolyLinesEx :: proc(center: Vector2, sides: i32, radius: f32, rotation: f32, lineThick: f32, color: Color) ---
	// Splines drawing functions
	DrawSplineLinear :: proc(points: ^Vector2, pointCount: i32, thick: f32, color: Color) ---
	DrawSplineBasis :: proc(points: ^Vector2, pointCount: i32, thick: f32, color: Color) ---
	DrawSplineCatmullRom :: proc(points: ^Vector2, pointCount: i32, thick: f32, color: Color) ---
	DrawSplineBezierQuadratic :: proc(points: ^Vector2, pointCount: i32, thick: f32, color: Color) ---
	DrawSplineBezierCubic :: proc(points: ^Vector2, pointCount: i32, thick: f32, color: Color) ---
	DrawSplineSegmentLinear :: proc(p1: Vector2, p2: Vector2, thick: f32, color: Color) ---
	DrawSplineSegmentBasis :: proc(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, thick: f32, color: Color) ---
	DrawSplineSegmentCatmullRom :: proc(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, thick: f32, color: Color) ---
	DrawSplineSegmentBezierQuadratic :: proc(p1: Vector2, c2: Vector2, p3: Vector2, thick: f32, color: Color) ---
	DrawSplineSegmentBezierCubic :: proc(p1: Vector2, c2: Vector2, c3: Vector2, p4: Vector2, thick: f32, color: Color) ---
	// Spline segment point evaluation functions, for a given t [0.0f .. 1.0f]
	GetSplinePointLinear :: proc(startPos: Vector2, endPos: Vector2, t: f32) -> Vector2 ---
	GetSplinePointBasis :: proc(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, t: f32) -> Vector2 ---
	GetSplinePointCatmullRom :: proc(p1: Vector2, p2: Vector2, p3: Vector2, p4: Vector2, t: f32) -> Vector2 ---
	GetSplinePointBezierQuad :: proc(p1: Vector2, c2: Vector2, p3: Vector2, t: f32) -> Vector2 ---
	GetSplinePointBezierCubic :: proc(p1: Vector2, c2: Vector2, c3: Vector2, p4: Vector2, t: f32) -> Vector2 ---
	// Basic shapes collision detection functions
	CheckCollisionRecs :: proc(rec1: Rectangle, rec2: Rectangle) -> bool ---
	CheckCollisionCircles :: proc(center1: Vector2, radius1: f32, center2: Vector2, radius2: f32) -> bool ---
	CheckCollisionCircleRec :: proc(center: Vector2, radius: f32, rec: Rectangle) -> bool ---
	CheckCollisionCircleLine :: proc(center: Vector2, radius: f32, p1: Vector2, p2: Vector2) -> bool ---
	CheckCollisionPointRec :: proc(point: Vector2, rec: Rectangle) -> bool ---
	CheckCollisionPointCircle :: proc(point: Vector2, center: Vector2, radius: f32) -> bool ---
	CheckCollisionPointTriangle :: proc(point: Vector2, p1: Vector2, p2: Vector2, p3: Vector2) -> bool ---
	CheckCollisionPointLine :: proc(point: Vector2, p1: Vector2, p2: Vector2, threshold: i32) -> bool ---
	CheckCollisionPointPoly :: proc(point: Vector2, points: ^Vector2, pointCount: i32) -> bool ---
	CheckCollisionLines :: proc(startPos1: Vector2, endPos1: Vector2, startPos2: Vector2, endPos2: Vector2, collisionPoint: ^Vector2) -> bool ---
	GetCollisionRec :: proc(rec1: Rectangle, rec2: Rectangle) -> Rectangle ---
	// Image loading functions
	// NOTE: These functions do not require GPU access
	LoadImage :: proc(fileName: cstring) -> Image ---
	LoadImageRaw :: proc(fileName: cstring, width: i32, height: i32, format: i32, headerSize: i32) -> Image ---
	LoadImageAnim :: proc(fileName: cstring, frames: ^i32) -> Image ---
	LoadImageAnimFromMemory :: proc(fileType: cstring, fileData: ^u8, dataSize: i32, frames: ^i32) -> Image ---
	LoadImageFromMemory :: proc(fileType: cstring, fileData: ^u8, dataSize: i32) -> Image ---
	LoadImageFromTexture :: proc(texture: Texture2D) -> Image ---
	LoadImageFromScreen :: proc() -> Image ---
	IsImageValid :: proc(image: Image) -> bool ---
	UnloadImage :: proc(image: Image) ---
	ExportImage :: proc(image: Image, fileName: cstring) -> bool ---
	ExportImageToMemory :: proc(image: Image, fileType: cstring, fileSize: ^i32) -> ^u8 ---
	ExportImageAsCode :: proc(image: Image, fileName: cstring) -> bool ---
	// Image generation functions
	GenImageColor :: proc(width: i32, height: i32, color: Color) -> Image ---
	GenImageGradientLinear :: proc(width: i32, height: i32, direction: i32, start: Color, end: Color) -> Image ---
	GenImageGradientRadial :: proc(width: i32, height: i32, density: f32, inner: Color, outer: Color) -> Image ---
	GenImageGradientSquare :: proc(width: i32, height: i32, density: f32, inner: Color, outer: Color) -> Image ---
	GenImageChecked :: proc(width: i32, height: i32, checksX: i32, checksY: i32, col1: Color, col2: Color) -> Image ---
	GenImageWhiteNoise :: proc(width: i32, height: i32, factor: f32) -> Image ---
	GenImagePerlinNoise :: proc(width: i32, height: i32, offsetX: i32, offsetY: i32, scale: f32) -> Image ---
	GenImageCellular :: proc(width: i32, height: i32, tileSize: i32) -> Image ---
	GenImageText :: proc(width: i32, height: i32, text: cstring) -> Image ---
	// Image manipulation functions
	ImageCopy :: proc(image: Image) -> Image ---
	ImageFromImage :: proc(image: Image, rec: Rectangle) -> Image ---
	ImageFromChannel :: proc(image: Image, selectedChannel: i32) -> Image ---
	ImageText :: proc(text: cstring, fontSize: i32, color: Color) -> Image ---
	ImageTextEx :: proc(font: Font, text: cstring, fontSize: f32, spacing: f32, tint: Color) -> Image ---
	ImageFormat :: proc(image: ^Image, newFormat: i32) ---
	ImageToPOT :: proc(image: ^Image, fill: Color) ---
	ImageCrop :: proc(image: ^Image, crop: Rectangle) ---
	ImageAlphaCrop :: proc(image: ^Image, threshold: f32) ---
	ImageAlphaClear :: proc(image: ^Image, color: Color, threshold: f32) ---
	ImageAlphaMask :: proc(image: ^Image, alphaMask: Image) ---
	ImageAlphaPremultiply :: proc(image: ^Image) ---
	ImageBlurGaussian :: proc(image: ^Image, blurSize: i32) ---
	ImageKernelConvolution :: proc(image: ^Image, kernel: ^f32, kernelSize: i32) ---
	ImageResize :: proc(image: ^Image, newWidth: i32, newHeight: i32) ---
	ImageResizeNN :: proc(image: ^Image, newWidth: i32, newHeight: i32) ---
	ImageResizeCanvas :: proc(image: ^Image, newWidth: i32, newHeight: i32, offsetX: i32, offsetY: i32, fill: Color) ---
	ImageMipmaps :: proc(image: ^Image) ---
	ImageDither :: proc(image: ^Image, rBpp: i32, gBpp: i32, bBpp: i32, aBpp: i32) ---
	ImageFlipVertical :: proc(image: ^Image) ---
	ImageFlipHorizontal :: proc(image: ^Image) ---
	ImageRotate :: proc(image: ^Image, degrees: i32) ---
	ImageRotateCW :: proc(image: ^Image) ---
	ImageRotateCCW :: proc(image: ^Image) ---
	ImageColorTint :: proc(image: ^Image, color: Color) ---
	ImageColorInvert :: proc(image: ^Image) ---
	ImageColorGrayscale :: proc(image: ^Image) ---
	ImageColorContrast :: proc(image: ^Image, contrast: f32) ---
	ImageColorBrightness :: proc(image: ^Image, brightness: i32) ---
	ImageColorReplace :: proc(image: ^Image, color: Color, replace: Color) ---
	LoadImageColors :: proc(image: Image) -> ^Color ---
	LoadImagePalette :: proc(image: Image, maxPaletteSize: i32, colorCount: ^i32) -> ^Color ---
	UnloadImageColors :: proc(colors: ^Color) ---
	UnloadImagePalette :: proc(colors: ^Color) ---
	GetImageAlphaBorder :: proc(image: Image, threshold: f32) -> Rectangle ---
	GetImageColor :: proc(image: Image, x: i32, y: i32) -> Color ---
	// Image drawing functions
	// NOTE: Image software-rendering functions (CPU)
	ImageClearBackground :: proc(dst: ^Image, color: Color) ---
	ImageDrawPixel :: proc(dst: ^Image, posX: i32, posY: i32, color: Color) ---
	ImageDrawPixelV :: proc(dst: ^Image, position: Vector2, color: Color) ---
	ImageDrawLine :: proc(dst: ^Image, startPosX: i32, startPosY: i32, endPosX: i32, endPosY: i32, color: Color) ---
	ImageDrawLineV :: proc(dst: ^Image, start: Vector2, end: Vector2, color: Color) ---
	ImageDrawLineEx :: proc(dst: ^Image, start: Vector2, end: Vector2, thick: i32, color: Color) ---
	ImageDrawCircle :: proc(dst: ^Image, centerX: i32, centerY: i32, radius: i32, color: Color) ---
	ImageDrawCircleV :: proc(dst: ^Image, center: Vector2, radius: i32, color: Color) ---
	ImageDrawCircleLines :: proc(dst: ^Image, centerX: i32, centerY: i32, radius: i32, color: Color) ---
	ImageDrawCircleLinesV :: proc(dst: ^Image, center: Vector2, radius: i32, color: Color) ---
	ImageDrawRectangle :: proc(dst: ^Image, posX: i32, posY: i32, width: i32, height: i32, color: Color) ---
	ImageDrawRectangleV :: proc(dst: ^Image, position: Vector2, size: Vector2, color: Color) ---
	ImageDrawRectangleRec :: proc(dst: ^Image, rec: Rectangle, color: Color) ---
	ImageDrawRectangleLines :: proc(dst: ^Image, rec: Rectangle, thick: i32, color: Color) ---
	ImageDrawTriangle :: proc(dst: ^Image, v1: Vector2, v2: Vector2, v3: Vector2, color: Color) ---
	ImageDrawTriangleEx :: proc(dst: ^Image, v1: Vector2, v2: Vector2, v3: Vector2, c1: Color, c2: Color, c3: Color) ---
	ImageDrawTriangleLines :: proc(dst: ^Image, v1: Vector2, v2: Vector2, v3: Vector2, color: Color) ---
	ImageDrawTriangleFan :: proc(dst: ^Image, points: ^Vector2, pointCount: i32, color: Color) ---
	ImageDrawTriangleStrip :: proc(dst: ^Image, points: ^Vector2, pointCount: i32, color: Color) ---
	ImageDraw :: proc(dst: ^Image, src: Image, srcRec: Rectangle, dstRec: Rectangle, tint: Color) ---
	ImageDrawText :: proc(dst: ^Image, text: cstring, posX: i32, posY: i32, fontSize: i32, color: Color) ---
	ImageDrawTextEx :: proc(dst: ^Image, font: Font, text: cstring, position: Vector2, fontSize: f32, spacing: f32, tint: Color) ---
	// Texture loading functions
	// NOTE: These functions require GPU access
	LoadTexture :: proc(fileName: cstring) -> Texture2D ---
	LoadTextureFromImage :: proc(image: Image) -> Texture2D ---
	LoadTextureCubemap :: proc(image: Image, layout: i32) -> TextureCubemap ---
	LoadRenderTexture :: proc(width: i32, height: i32) -> RenderTexture2D ---
	IsTextureValid :: proc(texture: Texture2D) -> bool ---
	UnloadTexture :: proc(texture: Texture2D) ---
	IsRenderTextureValid :: proc(target: RenderTexture2D) -> bool ---
	UnloadRenderTexture :: proc(target: RenderTexture2D) ---
	UpdateTexture :: proc(texture: Texture2D, pixels: rawptr) ---
	UpdateTextureRec :: proc(texture: Texture2D, rec: Rectangle, pixels: rawptr) ---
	// Texture configuration functions
	GenTextureMipmaps :: proc(texture: ^Texture2D) ---
	SetTextureFilter :: proc(texture: Texture2D, filter: i32) ---
	SetTextureWrap :: proc(texture: Texture2D, wrap: i32) ---
	// Texture drawing functions
	DrawTexture :: proc(texture: Texture2D, posX: i32, posY: i32, tint: Color) ---
	DrawTextureV :: proc(texture: Texture2D, position: Vector2, tint: Color) ---
	DrawTextureEx :: proc(texture: Texture2D, position: Vector2, rotation: f32, scale: f32, tint: Color) ---
	DrawTextureRec :: proc(texture: Texture2D, source: Rectangle, position: Vector2, tint: Color) ---
	DrawTexturePro :: proc(texture: Texture2D, source: Rectangle, dest: Rectangle, origin: Vector2, rotation: f32, tint: Color) ---
	DrawTextureNPatch :: proc(texture: Texture2D, nPatchInfo: NPatchInfo, dest: Rectangle, origin: Vector2, rotation: f32, tint: Color) ---
	// Color/pixel related functions
	ColorIsEqual :: proc(col1: Color, col2: Color) -> bool ---
	Fade :: proc(color: Color, alpha: f32) -> Color ---
	ColorToInt :: proc(color: Color) -> i32 ---
	ColorNormalize :: proc(color: Color) -> Vector4 ---
	ColorFromNormalized :: proc(normalized: Vector4) -> Color ---
	ColorToHSV :: proc(color: Color) -> Vector3 ---
	ColorFromHSV :: proc(hue: f32, saturation: f32, value: f32) -> Color ---
	ColorTint :: proc(color: Color, tint: Color) -> Color ---
	ColorBrightness :: proc(color: Color, factor: f32) -> Color ---
	ColorContrast :: proc(color: Color, contrast: f32) -> Color ---
	ColorAlpha :: proc(color: Color, alpha: f32) -> Color ---
	ColorAlphaBlend :: proc(dst: Color, src: Color, tint: Color) -> Color ---
	ColorLerp :: proc(color1: Color, color2: Color, factor: f32) -> Color ---
	GetColor :: proc(hexValue: u32) -> Color ---
	GetPixelColor :: proc(srcPtr: rawptr, format: i32) -> Color ---
	SetPixelColor :: proc(dstPtr: rawptr, color: Color, format: i32) ---
	GetPixelDataSize :: proc(width: i32, height: i32, format: i32) -> i32 ---
	// Font loading/unloading functions
	GetFontDefault :: proc() -> Font ---
	LoadFont :: proc(fileName: cstring) -> Font ---
	LoadFontEx :: proc(fileName: cstring, fontSize: i32, codepoints: ^i32, codepointCount: i32) -> Font ---
	LoadFontFromImage :: proc(image: Image, key: Color, firstChar: i32) -> Font ---
	LoadFontFromMemory :: proc(fileType: cstring, fileData: ^u8, dataSize: i32, fontSize: i32, codepoints: ^i32, codepointCount: i32) -> Font ---
	IsFontValid :: proc(font: Font) -> bool ---
	LoadFontData :: proc(fileData: ^u8, dataSize: i32, fontSize: i32, codepoints: ^i32, codepointCount: i32, type: i32, glyphCount: ^i32) -> ^GlyphInfo ---
	GenImageFontAtlas :: proc(glyphs: ^GlyphInfo, glyphRecs: ^^Rectangle, glyphCount: i32, fontSize: i32, padding: i32, packMethod: i32) -> Image ---
	UnloadFontData :: proc(glyphs: ^GlyphInfo, glyphCount: i32) ---
	UnloadFont :: proc(font: Font) ---
	ExportFontAsCode :: proc(font: Font, fileName: cstring) -> bool ---
	// Text drawing functions
	DrawFPS :: proc(posX: i32, posY: i32) ---
	DrawText :: proc(text: cstring, posX: i32, posY: i32, fontSize: i32, color: Color) ---
	DrawTextEx :: proc(font: Font, text: cstring, position: Vector2, fontSize: f32, spacing: f32, tint: Color) ---
	DrawTextPro :: proc(font: Font, text: cstring, position: Vector2, origin: Vector2, rotation: f32, fontSize: f32, spacing: f32, tint: Color) ---
	DrawTextCodepoint :: proc(font: Font, codepoint: i32, position: Vector2, fontSize: f32, tint: Color) ---
	DrawTextCodepoints :: proc(font: Font, codepoints: ^i32, codepointCount: i32, position: Vector2, fontSize: f32, spacing: f32, tint: Color) ---
	// Text font info functions
	SetTextLineSpacing :: proc(spacing: i32) ---
	MeasureText :: proc(text: cstring, fontSize: i32) -> i32 ---
	MeasureTextEx :: proc(font: Font, text: cstring, fontSize: f32, spacing: f32) -> Vector2 ---
	MeasureTextCodepoints :: proc(font: Font, codepoints: ^i32, length: i32, fontSize: f32, spacing: f32) -> Vector2 ---
	GetGlyphIndex :: proc(font: Font, codepoint: i32) -> i32 ---
	GetGlyphInfo :: proc(font: Font, codepoint: i32) -> GlyphInfo ---
	GetGlyphAtlasRec :: proc(font: Font, codepoint: i32) -> Rectangle ---
	// Text codepoints management functions (unicode characters)
	LoadUTF8 :: proc(codepoints: ^i32, length: i32) -> ^u8 ---
	UnloadUTF8 :: proc(text: ^u8) ---
	LoadCodepoints :: proc(text: cstring, count: ^i32) -> ^i32 ---
	UnloadCodepoints :: proc(codepoints: ^i32) ---
	GetCodepointCount :: proc(text: cstring) -> i32 ---
	GetCodepoint :: proc(text: cstring, codepointSize: ^i32) -> i32 ---
	GetCodepointNext :: proc(text: cstring, codepointSize: ^i32) -> i32 ---
	GetCodepointPrevious :: proc(text: cstring, codepointSize: ^i32) -> i32 ---
	CodepointToUTF8 :: proc(codepoint: i32, utf8Size: ^i32) -> cstring ---
	// Text strings management functions (no UTF-8 strings, only byte chars)
	// WARNING 1: Most of these functions use internal static buffers[], it's recommended to store returned data on user-side for re-use
	// WARNING 2: Some functions allocate memory internally for the returned strings, those strings must be freed by user using MemFree()
	LoadTextLines :: proc(text: cstring, count: ^i32) -> ^^u8 ---
	UnloadTextLines :: proc(text: ^^u8, lineCount: i32) ---
	TextCopy :: proc(dst: ^u8, src: cstring) -> i32 ---
	TextIsEqual :: proc(text1: cstring, text2: cstring) -> bool ---
	TextLength :: proc(text: cstring) -> u32 ---
	TextFormat :: proc(text: cstring, #c_vararg _: ..any) -> cstring ---
	TextSubtext :: proc(text: cstring, position: i32, length: i32) -> cstring ---
	TextRemoveSpaces :: proc(text: cstring) -> cstring ---
	GetTextBetween :: proc(text: cstring, begin: cstring, end: cstring) -> ^u8 ---
	TextReplace :: proc(text: cstring, search: cstring, replacement: cstring) -> ^u8 ---
	TextReplaceAlloc :: proc(text: cstring, search: cstring, replacement: cstring) -> ^u8 ---
	TextReplaceBetween :: proc(text: cstring, begin: cstring, end: cstring, replacement: cstring) -> ^u8 ---
	TextReplaceBetweenAlloc :: proc(text: cstring, begin: cstring, end: cstring, replacement: cstring) -> ^u8 ---
	TextInsert :: proc(text: cstring, insert: cstring, position: i32) -> ^u8 ---
	TextInsertAlloc :: proc(text: cstring, insert: cstring, position: i32) -> ^u8 ---
	TextJoin :: proc(textList: ^^u8, count: i32, delimiter: cstring) -> ^u8 ---
	TextSplit :: proc(text: cstring, delimiter: u8, count: ^i32) -> ^^u8 ---
	TextAppend :: proc(text: ^u8, append: cstring, position: ^i32) ---
	TextFindIndex :: proc(text: cstring, search: cstring) -> i32 ---
	TextToUpper :: proc(text: cstring) -> ^u8 ---
	TextToLower :: proc(text: cstring) -> ^u8 ---
	TextToPascal :: proc(text: cstring) -> ^u8 ---
	TextToSnake :: proc(text: cstring) -> ^u8 ---
	TextToCamel :: proc(text: cstring) -> ^u8 ---
	TextToInteger :: proc(text: cstring) -> i32 ---
	TextToFloat :: proc(text: cstring) -> f32 ---
	// Basic geometric 3D shapes drawing functions
	DrawLine3D :: proc(startPos: Vector3, endPos: Vector3, color: Color) ---
	DrawPoint3D :: proc(position: Vector3, color: Color) ---
	DrawCircle3D :: proc(center: Vector3, radius: f32, rotationAxis: Vector3, rotationAngle: f32, color: Color) ---
	DrawTriangle3D :: proc(v1: Vector3, v2: Vector3, v3: Vector3, color: Color) ---
	DrawTriangleStrip3D :: proc(points: ^Vector3, pointCount: i32, color: Color) ---
	DrawCube :: proc(position: Vector3, width: f32, height: f32, length: f32, color: Color) ---
	DrawCubeV :: proc(position: Vector3, size: Vector3, color: Color) ---
	DrawCubeWires :: proc(position: Vector3, width: f32, height: f32, length: f32, color: Color) ---
	DrawCubeWiresV :: proc(position: Vector3, size: Vector3, color: Color) ---
	DrawSphere :: proc(centerPos: Vector3, radius: f32, color: Color) ---
	DrawSphereEx :: proc(centerPos: Vector3, radius: f32, rings: i32, slices: i32, color: Color) ---
	DrawSphereWires :: proc(centerPos: Vector3, radius: f32, rings: i32, slices: i32, color: Color) ---
	DrawCylinder :: proc(position: Vector3, radiusTop: f32, radiusBottom: f32, height: f32, slices: i32, color: Color) ---
	DrawCylinderEx :: proc(startPos: Vector3, endPos: Vector3, startRadius: f32, endRadius: f32, sides: i32, color: Color) ---
	DrawCylinderWires :: proc(position: Vector3, radiusTop: f32, radiusBottom: f32, height: f32, slices: i32, color: Color) ---
	DrawCylinderWiresEx :: proc(startPos: Vector3, endPos: Vector3, startRadius: f32, endRadius: f32, sides: i32, color: Color) ---
	DrawCapsule :: proc(startPos: Vector3, endPos: Vector3, radius: f32, slices: i32, rings: i32, color: Color) ---
	DrawCapsuleWires :: proc(startPos: Vector3, endPos: Vector3, radius: f32, slices: i32, rings: i32, color: Color) ---
	DrawPlane :: proc(centerPos: Vector3, size: Vector2, color: Color) ---
	DrawRay :: proc(ray: Ray, color: Color) ---
	DrawGrid :: proc(slices: i32, spacing: f32) ---
	// Model management functions
	LoadModel :: proc(fileName: cstring) -> Model ---
	LoadModelFromMesh :: proc(mesh: Mesh) -> Model ---
	IsModelValid :: proc(model: Model) -> bool ---
	UnloadModel :: proc(model: Model) ---
	GetModelBoundingBox :: proc(model: Model) -> BoundingBox ---
	// Model drawing functions
	DrawModel :: proc(model: Model, position: Vector3, scale: f32, tint: Color) ---
	DrawModelEx :: proc(model: Model, position: Vector3, rotationAxis: Vector3, rotationAngle: f32, scale: Vector3, tint: Color) ---
	DrawModelWires :: proc(model: Model, position: Vector3, scale: f32, tint: Color) ---
	DrawModelWiresEx :: proc(model: Model, position: Vector3, rotationAxis: Vector3, rotationAngle: f32, scale: Vector3, tint: Color) ---
	DrawBoundingBox :: proc(box: BoundingBox, color: Color) ---
	DrawBillboard :: proc(camera: Camera, texture: Texture2D, position: Vector3, scale: f32, tint: Color) ---
	DrawBillboardRec :: proc(camera: Camera, texture: Texture2D, source: Rectangle, position: Vector3, size: Vector2, tint: Color) ---
	DrawBillboardPro :: proc(camera: Camera, texture: Texture2D, source: Rectangle, position: Vector3, up: Vector3, size: Vector2, origin: Vector2, rotation: f32, tint: Color) ---
	// Mesh management functions
	UploadMesh :: proc(mesh: ^Mesh, dynamic_: bool) ---
	UpdateMeshBuffer :: proc(mesh: Mesh, index: i32, data: rawptr, dataSize: i32, offset: i32) ---
	UnloadMesh :: proc(mesh: Mesh) ---
	DrawMesh :: proc(mesh: Mesh, material: Material, transform: Matrix) ---
	DrawMeshInstanced :: proc(mesh: Mesh, material: Material, transforms: ^Matrix, instances: i32) ---
	GetMeshBoundingBox :: proc(mesh: Mesh) -> BoundingBox ---
	GenMeshTangents :: proc(mesh: ^Mesh) ---
	ExportMesh :: proc(mesh: Mesh, fileName: cstring) -> bool ---
	ExportMeshAsCode :: proc(mesh: Mesh, fileName: cstring) -> bool ---
	// Mesh generation functions
	GenMeshPoly :: proc(sides: i32, radius: f32) -> Mesh ---
	GenMeshPlane :: proc(width: f32, length: f32, resX: i32, resZ: i32) -> Mesh ---
	GenMeshCube :: proc(width: f32, height: f32, length: f32) -> Mesh ---
	GenMeshSphere :: proc(radius: f32, rings: i32, slices: i32) -> Mesh ---
	GenMeshHemiSphere :: proc(radius: f32, rings: i32, slices: i32) -> Mesh ---
	GenMeshCylinder :: proc(radius: f32, height: f32, slices: i32) -> Mesh ---
	GenMeshCone :: proc(radius: f32, height: f32, slices: i32) -> Mesh ---
	GenMeshTorus :: proc(radius: f32, size: f32, radSeg: i32, sides: i32) -> Mesh ---
	GenMeshKnot :: proc(radius: f32, size: f32, radSeg: i32, sides: i32) -> Mesh ---
	GenMeshHeightmap :: proc(heightmap: Image, size: Vector3) -> Mesh ---
	GenMeshCubicmap :: proc(cubicmap: Image, cubeSize: Vector3) -> Mesh ---
	// Material loading/unloading functions
	LoadMaterials :: proc(fileName: cstring, materialCount: ^i32) -> ^Material ---
	LoadMaterialDefault :: proc() -> Material ---
	IsMaterialValid :: proc(material: Material) -> bool ---
	UnloadMaterial :: proc(material: Material) ---
	SetMaterialTexture :: proc(material: ^Material, mapType: i32, texture: Texture2D) ---
	SetModelMeshMaterial :: proc(model: ^Model, meshId: i32, materialId: i32) ---
	// Model animations loading/unloading functions
	LoadModelAnimations :: proc(fileName: cstring, animCount: ^i32) -> ^ModelAnimation ---
	UpdateModelAnimation :: proc(model: Model, anim: ModelAnimation, frame: f32) ---
	UpdateModelAnimationEx :: proc(model: Model, animA: ModelAnimation, frameA: f32, animB: ModelAnimation, frameB: f32, blend: f32) ---
	UnloadModelAnimations :: proc(animations: ^ModelAnimation, animCount: i32) ---
	IsModelAnimationValid :: proc(model: Model, anim: ModelAnimation) -> bool ---
	// Collision detection functions
	CheckCollisionSpheres :: proc(center1: Vector3, radius1: f32, center2: Vector3, radius2: f32) -> bool ---
	CheckCollisionBoxes :: proc(box1: BoundingBox, box2: BoundingBox) -> bool ---
	CheckCollisionBoxSphere :: proc(box: BoundingBox, center: Vector3, radius: f32) -> bool ---
	GetRayCollisionSphere :: proc(ray: Ray, center: Vector3, radius: f32) -> RayCollision ---
	GetRayCollisionBox :: proc(ray: Ray, box: BoundingBox) -> RayCollision ---
	GetRayCollisionMesh :: proc(ray: Ray, mesh: Mesh, transform: Matrix) -> RayCollision ---
	GetRayCollisionTriangle :: proc(ray: Ray, p1: Vector3, p2: Vector3, p3: Vector3) -> RayCollision ---
	GetRayCollisionQuad :: proc(ray: Ray, p1: Vector3, p2: Vector3, p3: Vector3, p4: Vector3) -> RayCollision ---
	// Audio device management functions
	InitAudioDevice :: proc() ---
	CloseAudioDevice :: proc() ---
	IsAudioDeviceReady :: proc() -> bool ---
	SetMasterVolume :: proc(volume: f32) ---
	GetMasterVolume :: proc() -> f32 ---
	// Wave/Sound loading/unloading functions
	LoadWave :: proc(fileName: cstring) -> Wave ---
	LoadWaveFromMemory :: proc(fileType: cstring, fileData: ^u8, dataSize: i32) -> Wave ---
	IsWaveValid :: proc(wave: Wave) -> bool ---
	LoadSound :: proc(fileName: cstring) -> Sound ---
	LoadSoundFromWave :: proc(wave: Wave) -> Sound ---
	LoadSoundAlias :: proc(source: Sound) -> Sound ---
	IsSoundValid :: proc(sound: Sound) -> bool ---
	UpdateSound :: proc(sound: Sound, data: rawptr, sampleCount: i32) ---
	UnloadWave :: proc(wave: Wave) ---
	UnloadSound :: proc(sound: Sound) ---
	UnloadSoundAlias :: proc(alias: Sound) ---
	ExportWave :: proc(wave: Wave, fileName: cstring) -> bool ---
	ExportWaveAsCode :: proc(wave: Wave, fileName: cstring) -> bool ---
	// Wave/Sound management functions
	PlaySound :: proc(sound: Sound) ---
	StopSound :: proc(sound: Sound) ---
	PauseSound :: proc(sound: Sound) ---
	ResumeSound :: proc(sound: Sound) ---
	IsSoundPlaying :: proc(sound: Sound) -> bool ---
	SetSoundVolume :: proc(sound: Sound, volume: f32) ---
	SetSoundPitch :: proc(sound: Sound, pitch: f32) ---
	SetSoundPan :: proc(sound: Sound, pan: f32) ---
	WaveCopy :: proc(wave: Wave) -> Wave ---
	WaveCrop :: proc(wave: ^Wave, initFrame: i32, finalFrame: i32) ---
	WaveFormat :: proc(wave: ^Wave, sampleRate: i32, sampleSize: i32, channels: i32) ---
	LoadWaveSamples :: proc(wave: Wave) -> ^f32 ---
	UnloadWaveSamples :: proc(samples: ^f32) ---
	// Music management functions
	LoadMusicStream :: proc(fileName: cstring) -> Music ---
	LoadMusicStreamFromMemory :: proc(fileType: cstring, data: ^u8, dataSize: i32) -> Music ---
	IsMusicValid :: proc(music: Music) -> bool ---
	UnloadMusicStream :: proc(music: Music) ---
	PlayMusicStream :: proc(music: Music) ---
	IsMusicStreamPlaying :: proc(music: Music) -> bool ---
	UpdateMusicStream :: proc(music: Music) ---
	StopMusicStream :: proc(music: Music) ---
	PauseMusicStream :: proc(music: Music) ---
	ResumeMusicStream :: proc(music: Music) ---
	SeekMusicStream :: proc(music: Music, position: f32) ---
	SetMusicVolume :: proc(music: Music, volume: f32) ---
	SetMusicPitch :: proc(music: Music, pitch: f32) ---
	SetMusicPan :: proc(music: Music, pan: f32) ---
	GetMusicTimeLength :: proc(music: Music) -> f32 ---
	GetMusicTimePlayed :: proc(music: Music) -> f32 ---
	// AudioStream management functions
	LoadAudioStream :: proc(sampleRate: u32, sampleSize: u32, channels: u32) -> AudioStream ---
	IsAudioStreamValid :: proc(stream: AudioStream) -> bool ---
	UnloadAudioStream :: proc(stream: AudioStream) ---
	UpdateAudioStream :: proc(stream: AudioStream, data: rawptr, frameCount: i32) ---
	IsAudioStreamProcessed :: proc(stream: AudioStream) -> bool ---
	PlayAudioStream :: proc(stream: AudioStream) ---
	PauseAudioStream :: proc(stream: AudioStream) ---
	ResumeAudioStream :: proc(stream: AudioStream) ---
	IsAudioStreamPlaying :: proc(stream: AudioStream) -> bool ---
	StopAudioStream :: proc(stream: AudioStream) ---
	SetAudioStreamVolume :: proc(stream: AudioStream, volume: f32) ---
	SetAudioStreamPitch :: proc(stream: AudioStream, pitch: f32) ---
	SetAudioStreamPan :: proc(stream: AudioStream, pan: f32) ---
	SetAudioStreamBufferSizeDefault :: proc(size: i32) ---
	SetAudioStreamCallback :: proc(stream: AudioStream, callback: AudioCallback) ---
	AttachAudioStreamProcessor :: proc(stream: AudioStream, processor: AudioCallback) ---
	DetachAudioStreamProcessor :: proc(stream: AudioStream, processor: AudioCallback) ---
	AttachAudioMixedProcessor :: proc(processor: AudioCallback) ---
	DetachAudioMixedProcessor :: proc(processor: AudioCallback) ---
}
