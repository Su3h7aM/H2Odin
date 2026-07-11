package cgltf

foreign import lib "system:cgltf"

cgltf_size :: uint

cgltf_ssize :: i64

cgltf_float :: f32

cgltf_int :: i32

cgltf_uint :: u32

cgltf_bool :: i32

cgltf_file_type :: enum u32 {
	file_type_invalid,
	file_type_gltf,
	file_type_glb,
	file_type_max_enum,
}

cgltf_result :: enum u32 {
	result_success,
	result_data_too_short,
	result_unknown_format,
	result_invalid_json,
	result_invalid_gltf,
	result_invalid_options,
	result_file_not_found,
	result_io_error,
	result_out_of_memory,
	result_legacy_gltf,
	result_max_enum,
}

cgltf_memory_options :: struct {
	alloc_func: proc "c" (_: rawptr, _: cgltf_size) -> rawptr,
	free_func: proc "c" (_: rawptr, _: rawptr),
	user_data: rawptr,
}

cgltf_file_options :: struct {
	read: proc "c" (_: ^cgltf_memory_options, _: ^cgltf_file_options, _: cstring, _: ^cgltf_size, _: ^rawptr) -> cgltf_result,
	release: proc "c" (_: ^cgltf_memory_options, _: ^cgltf_file_options, _: rawptr),
	user_data: rawptr,
}

cgltf_options :: struct {
	/* invalid == auto detect */
	type: cgltf_file_type,
	/* 0 == auto */
	json_token_count: cgltf_size,
	memory: cgltf_memory_options,
	file: cgltf_file_options,
}

cgltf_buffer_view_type :: enum u32 {
	buffer_view_type_invalid,
	buffer_view_type_indices,
	buffer_view_type_vertices,
	buffer_view_type_max_enum,
}

cgltf_attribute_type :: enum u32 {
	attribute_type_invalid,
	attribute_type_position,
	attribute_type_normal,
	attribute_type_tangent,
	attribute_type_texcoord,
	attribute_type_color,
	attribute_type_joints,
	attribute_type_weights,
	attribute_type_custom,
	attribute_type_max_enum,
}

cgltf_component_type :: enum u32 {
	component_type_invalid,
	/* BYTE */
	component_type_r_8,
	/* UNSIGNED_BYTE */
	component_type_r_8u,
	/* SHORT */
	component_type_r_16,
	/* UNSIGNED_SHORT */
	component_type_r_16u,
	/* UNSIGNED_INT */
	component_type_r_32u,
	/* FLOAT */
	component_type_r_32f,
	component_type_max_enum,
}

cgltf_type :: enum u32 {
	type_invalid,
	type_scalar,
	type_vec2,
	type_vec3,
	type_vec4,
	type_mat2,
	type_mat3,
	type_mat4,
	type_max_enum,
}

cgltf_primitive_type :: enum u32 {
	primitive_type_invalid,
	primitive_type_points,
	primitive_type_lines,
	primitive_type_line_loop,
	primitive_type_line_strip,
	primitive_type_triangles,
	primitive_type_triangle_strip,
	primitive_type_triangle_fan,
	primitive_type_max_enum,
}

cgltf_alpha_mode :: enum u32 {
	alpha_mode_opaque,
	alpha_mode_mask,
	alpha_mode_blend,
	alpha_mode_max_enum,
}

cgltf_animation_path_type :: enum u32 {
	animation_path_type_invalid,
	animation_path_type_translation,
	animation_path_type_rotation,
	animation_path_type_scale,
	animation_path_type_weights,
	animation_path_type_max_enum,
}

cgltf_interpolation_type :: enum u32 {
	interpolation_type_linear,
	interpolation_type_step,
	interpolation_type_cubic_spline,
	interpolation_type_max_enum,
}

cgltf_camera_type :: enum u32 {
	camera_type_invalid,
	camera_type_perspective,
	camera_type_orthographic,
	camera_type_max_enum,
}

cgltf_light_type :: enum u32 {
	light_type_invalid,
	light_type_directional,
	light_type_point,
	light_type_spot,
	light_type_max_enum,
}

cgltf_data_free_method :: enum u32 {
	data_free_method_none,
	data_free_method_file_release,
	data_free_method_memory_free,
	data_free_method_max_enum,
}

cgltf_extras :: struct {
	/* this field is deprecated and will be removed in the future; use data instead */
	start_offset: cgltf_size,
	/* this field is deprecated and will be removed in the future; use data instead */
	end_offset: cgltf_size,
	data: ^u8,
}

cgltf_extension :: struct {
	name: ^u8,
	data: ^u8,
}

cgltf_buffer :: struct {
	name: ^u8,
	size: cgltf_size,
	uri: ^u8,
	/* loaded by cgltf_load_buffers */
	data: rawptr,
	data_free_method: cgltf_data_free_method,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_meshopt_compression_mode :: enum u32 {
	meshopt_compression_mode_invalid,
	meshopt_compression_mode_attributes,
	meshopt_compression_mode_triangles,
	meshopt_compression_mode_indices,
	meshopt_compression_mode_max_enum,
}

cgltf_meshopt_compression_filter :: enum u32 {
	meshopt_compression_filter_none,
	meshopt_compression_filter_octahedral,
	meshopt_compression_filter_quaternion,
	meshopt_compression_filter_exponential,
	meshopt_compression_filter_max_enum,
}

cgltf_meshopt_compression :: struct {
	buffer: ^cgltf_buffer,
	offset: cgltf_size,
	size: cgltf_size,
	stride: cgltf_size,
	count: cgltf_size,
	mode: cgltf_meshopt_compression_mode,
	filter: cgltf_meshopt_compression_filter,
}

cgltf_buffer_view :: struct {
	name: ^u8,
	buffer: ^cgltf_buffer,
	offset: cgltf_size,
	size: cgltf_size,
	/* 0 == automatically determined by accessor */
	stride: cgltf_size,
	type: cgltf_buffer_view_type,
	/* overrides buffer->data if present, filled by extensions */
	data: rawptr,
	has_meshopt_compression: cgltf_bool,
	meshopt_compression: cgltf_meshopt_compression,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_accessor_sparse :: struct {
	count: cgltf_size,
	indices_buffer_view: ^cgltf_buffer_view,
	indices_byte_offset: cgltf_size,
	indices_component_type: cgltf_component_type,
	values_buffer_view: ^cgltf_buffer_view,
	values_byte_offset: cgltf_size,
}

cgltf_accessor :: struct {
	name: ^u8,
	component_type: cgltf_component_type,
	normalized: cgltf_bool,
	type: cgltf_type,
	offset: cgltf_size,
	count: cgltf_size,
	stride: cgltf_size,
	buffer_view: ^cgltf_buffer_view,
	has_min: cgltf_bool,
	min: [16]cgltf_float,
	has_max: cgltf_bool,
	max: [16]cgltf_float,
	is_sparse: cgltf_bool,
	sparse: cgltf_accessor_sparse,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_attribute :: struct {
	name: ^u8,
	type: cgltf_attribute_type,
	index: cgltf_int,
	data: ^cgltf_accessor,
}

cgltf_image :: struct {
	name: ^u8,
	uri: ^u8,
	buffer_view: ^cgltf_buffer_view,
	mime_type: ^u8,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_sampler :: struct {
	name: ^u8,
	mag_filter: cgltf_int,
	min_filter: cgltf_int,
	wrap_s: cgltf_int,
	wrap_t: cgltf_int,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_texture :: struct {
	name: ^u8,
	image: ^cgltf_image,
	sampler: ^cgltf_sampler,
	has_basisu: cgltf_bool,
	basisu_image: ^cgltf_image,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_texture_transform :: struct {
	offset: [2]cgltf_float,
	rotation: cgltf_float,
	scale: [2]cgltf_float,
	has_texcoord: cgltf_bool,
	texcoord: cgltf_int,
}

cgltf_texture_view :: struct {
	texture: ^cgltf_texture,
	texcoord: cgltf_int,
	/* equivalent to strength for occlusion_texture */
	scale: cgltf_float,
	has_transform: cgltf_bool,
	transform: cgltf_texture_transform,
}

cgltf_pbr_metallic_roughness :: struct {
	base_color_texture: cgltf_texture_view,
	metallic_roughness_texture: cgltf_texture_view,
	base_color_factor: [4]cgltf_float,
	metallic_factor: cgltf_float,
	roughness_factor: cgltf_float,
}

cgltf_pbr_specular_glossiness :: struct {
	diffuse_texture: cgltf_texture_view,
	specular_glossiness_texture: cgltf_texture_view,
	diffuse_factor: [4]cgltf_float,
	specular_factor: [3]cgltf_float,
	glossiness_factor: cgltf_float,
}

cgltf_clearcoat :: struct {
	clearcoat_texture: cgltf_texture_view,
	clearcoat_roughness_texture: cgltf_texture_view,
	clearcoat_normal_texture: cgltf_texture_view,
	clearcoat_factor: cgltf_float,
	clearcoat_roughness_factor: cgltf_float,
}

cgltf_transmission :: struct {
	transmission_texture: cgltf_texture_view,
	transmission_factor: cgltf_float,
}

cgltf_ior :: struct {
	ior: cgltf_float,
}

cgltf_specular :: struct {
	specular_texture: cgltf_texture_view,
	specular_color_texture: cgltf_texture_view,
	specular_color_factor: [3]cgltf_float,
	specular_factor: cgltf_float,
}

cgltf_volume :: struct {
	thickness_texture: cgltf_texture_view,
	thickness_factor: cgltf_float,
	attenuation_color: [3]cgltf_float,
	attenuation_distance: cgltf_float,
}

cgltf_sheen :: struct {
	sheen_color_texture: cgltf_texture_view,
	sheen_color_factor: [3]cgltf_float,
	sheen_roughness_texture: cgltf_texture_view,
	sheen_roughness_factor: cgltf_float,
}

cgltf_emissive_strength :: struct {
	emissive_strength: cgltf_float,
}

cgltf_iridescence :: struct {
	iridescence_factor: cgltf_float,
	iridescence_texture: cgltf_texture_view,
	iridescence_ior: cgltf_float,
	iridescence_thickness_min: cgltf_float,
	iridescence_thickness_max: cgltf_float,
	iridescence_thickness_texture: cgltf_texture_view,
}

cgltf_anisotropy :: struct {
	anisotropy_strength: cgltf_float,
	anisotropy_rotation: cgltf_float,
	anisotropy_texture: cgltf_texture_view,
}

cgltf_dispersion :: struct {
	dispersion: cgltf_float,
}

cgltf_material :: struct {
	name: ^u8,
	has_pbr_metallic_roughness: cgltf_bool,
	has_pbr_specular_glossiness: cgltf_bool,
	has_clearcoat: cgltf_bool,
	has_transmission: cgltf_bool,
	has_volume: cgltf_bool,
	has_ior: cgltf_bool,
	has_specular: cgltf_bool,
	has_sheen: cgltf_bool,
	has_emissive_strength: cgltf_bool,
	has_iridescence: cgltf_bool,
	has_anisotropy: cgltf_bool,
	has_dispersion: cgltf_bool,
	pbr_metallic_roughness: cgltf_pbr_metallic_roughness,
	pbr_specular_glossiness: cgltf_pbr_specular_glossiness,
	clearcoat: cgltf_clearcoat,
	ior: cgltf_ior,
	specular: cgltf_specular,
	sheen: cgltf_sheen,
	transmission: cgltf_transmission,
	volume: cgltf_volume,
	emissive_strength: cgltf_emissive_strength,
	iridescence: cgltf_iridescence,
	anisotropy: cgltf_anisotropy,
	dispersion: cgltf_dispersion,
	normal_texture: cgltf_texture_view,
	occlusion_texture: cgltf_texture_view,
	emissive_texture: cgltf_texture_view,
	emissive_factor: [3]cgltf_float,
	alpha_mode: cgltf_alpha_mode,
	alpha_cutoff: cgltf_float,
	double_sided: cgltf_bool,
	unlit: cgltf_bool,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_material_mapping :: struct {
	variant: cgltf_size,
	material: ^cgltf_material,
	extras: cgltf_extras,
}

cgltf_morph_target :: struct {
	attributes: ^cgltf_attribute,
	attributes_count: cgltf_size,
}

cgltf_draco_mesh_compression :: struct {
	buffer_view: ^cgltf_buffer_view,
	attributes: ^cgltf_attribute,
	attributes_count: cgltf_size,
}

cgltf_mesh_gpu_instancing :: struct {
	attributes: ^cgltf_attribute,
	attributes_count: cgltf_size,
}

cgltf_primitive :: struct {
	type: cgltf_primitive_type,
	indices: ^cgltf_accessor,
	material: ^cgltf_material,
	attributes: ^cgltf_attribute,
	attributes_count: cgltf_size,
	targets: ^cgltf_morph_target,
	targets_count: cgltf_size,
	extras: cgltf_extras,
	has_draco_mesh_compression: cgltf_bool,
	draco_mesh_compression: cgltf_draco_mesh_compression,
	mappings: ^cgltf_material_mapping,
	mappings_count: cgltf_size,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_mesh :: struct {
	name: ^u8,
	primitives: ^cgltf_primitive,
	primitives_count: cgltf_size,
	weights: ^cgltf_float,
	weights_count: cgltf_size,
	target_names: ^^u8,
	target_names_count: cgltf_size,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_node :: struct {
	name: ^u8,
	parent: ^cgltf_node,
	children: ^^cgltf_node,
	children_count: cgltf_size,
	skin: ^cgltf_skin,
	mesh: ^cgltf_mesh,
	camera: ^cgltf_camera,
	light: ^cgltf_light,
	weights: ^cgltf_float,
	weights_count: cgltf_size,
	has_translation: cgltf_bool,
	has_rotation: cgltf_bool,
	has_scale: cgltf_bool,
	has_matrix: cgltf_bool,
	translation: [3]cgltf_float,
	rotation: [4]cgltf_float,
	scale: [3]cgltf_float,
	matrix_: [16]cgltf_float,
	extras: cgltf_extras,
	has_mesh_gpu_instancing: cgltf_bool,
	mesh_gpu_instancing: cgltf_mesh_gpu_instancing,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_skin :: struct {
	name: ^u8,
	joints: ^^cgltf_node,
	joints_count: cgltf_size,
	skeleton: ^cgltf_node,
	inverse_bind_matrices: ^cgltf_accessor,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_camera_perspective :: struct {
	has_aspect_ratio: cgltf_bool,
	aspect_ratio: cgltf_float,
	yfov: cgltf_float,
	has_zfar: cgltf_bool,
	zfar: cgltf_float,
	znear: cgltf_float,
	extras: cgltf_extras,
}

cgltf_camera_orthographic :: struct {
	xmag: cgltf_float,
	ymag: cgltf_float,
	zfar: cgltf_float,
	znear: cgltf_float,
	extras: cgltf_extras,
}

cgltf_camera :: struct {
	name: ^u8,
	type: cgltf_camera_type,
	data: struct #raw_union {
		perspective: cgltf_camera_perspective,
		orthographic: cgltf_camera_orthographic,
	},
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_light :: struct {
	name: ^u8,
	color: [3]cgltf_float,
	intensity: cgltf_float,
	type: cgltf_light_type,
	range: cgltf_float,
	spot_inner_cone_angle: cgltf_float,
	spot_outer_cone_angle: cgltf_float,
	extras: cgltf_extras,
}

cgltf_scene :: struct {
	name: ^u8,
	nodes: ^^cgltf_node,
	nodes_count: cgltf_size,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_animation_sampler :: struct {
	input: ^cgltf_accessor,
	output: ^cgltf_accessor,
	interpolation: cgltf_interpolation_type,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_animation_channel :: struct {
	sampler: ^cgltf_animation_sampler,
	target_node: ^cgltf_node,
	target_path: cgltf_animation_path_type,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_animation :: struct {
	name: ^u8,
	samplers: ^cgltf_animation_sampler,
	samplers_count: cgltf_size,
	channels: ^cgltf_animation_channel,
	channels_count: cgltf_size,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_material_variant :: struct {
	name: ^u8,
	extras: cgltf_extras,
}

cgltf_asset :: struct {
	copyright: ^u8,
	generator: ^u8,
	version: ^u8,
	min_version: ^u8,
	extras: cgltf_extras,
	extensions_count: cgltf_size,
	extensions: ^cgltf_extension,
}

cgltf_data :: struct {
	file_type: cgltf_file_type,
	file_data: rawptr,
	asset: cgltf_asset,
	meshes: ^cgltf_mesh,
	meshes_count: cgltf_size,
	materials: ^cgltf_material,
	materials_count: cgltf_size,
	accessors: ^cgltf_accessor,
	accessors_count: cgltf_size,
	buffer_views: ^cgltf_buffer_view,
	buffer_views_count: cgltf_size,
	buffers: ^cgltf_buffer,
	buffers_count: cgltf_size,
	images: ^cgltf_image,
	images_count: cgltf_size,
	textures: ^cgltf_texture,
	textures_count: cgltf_size,
	samplers: ^cgltf_sampler,
	samplers_count: cgltf_size,
	skins: ^cgltf_skin,
	skins_count: cgltf_size,
	cameras: ^cgltf_camera,
	cameras_count: cgltf_size,
	lights: ^cgltf_light,
	lights_count: cgltf_size,
	nodes: ^cgltf_node,
	nodes_count: cgltf_size,
	scenes: ^cgltf_scene,
	scenes_count: cgltf_size,
	scene: ^cgltf_scene,
	animations: ^cgltf_animation,
	animations_count: cgltf_size,
	variants: ^cgltf_material_variant,
	variants_count: cgltf_size,
	extras: cgltf_extras,
	data_extensions_count: cgltf_size,
	data_extensions: ^cgltf_extension,
	extensions_used: ^^u8,
	extensions_used_count: cgltf_size,
	extensions_required: ^^u8,
	extensions_required_count: cgltf_size,
	json: cstring,
	json_size: cgltf_size,
	bin: rawptr,
	bin_size: cgltf_size,
	memory: cgltf_memory_options,
	file: cgltf_file_options,
}

@(link_prefix = "cgltf_")
foreign lib {
	parse :: proc(options: ^cgltf_options, data: rawptr, size: cgltf_size, out_data: ^^cgltf_data) -> cgltf_result ---
	parse_file :: proc(options: ^cgltf_options, path: cstring, out_data: ^^cgltf_data) -> cgltf_result ---
	load_buffers :: proc(options: ^cgltf_options, data: ^cgltf_data, gltf_path: cstring) -> cgltf_result ---
	load_buffer_base64 :: proc(options: ^cgltf_options, size: cgltf_size, base64: cstring, out_data: ^rawptr) -> cgltf_result ---
	decode_string :: proc(string: ^u8) -> cgltf_size ---
	decode_uri :: proc(uri: ^u8) -> cgltf_size ---
	validate :: proc(data: ^cgltf_data) -> cgltf_result ---
	free :: proc(data: ^cgltf_data) ---
	node_transform_local :: proc(node: ^cgltf_node, out_matrix: ^cgltf_float) ---
	node_transform_world :: proc(node: ^cgltf_node, out_matrix: ^cgltf_float) ---
	buffer_view_data :: proc(view: ^cgltf_buffer_view) -> ^u8 ---
	accessor_read_float :: proc(accessor: ^cgltf_accessor, index: cgltf_size, out: ^cgltf_float, element_size: cgltf_size) -> cgltf_bool ---
	accessor_read_uint :: proc(accessor: ^cgltf_accessor, index: cgltf_size, out: ^cgltf_uint, element_size: cgltf_size) -> cgltf_bool ---
	accessor_read_index :: proc(accessor: ^cgltf_accessor, index: cgltf_size) -> cgltf_size ---
	num_components :: proc(type: cgltf_type) -> cgltf_size ---
	component_size :: proc(component_type: cgltf_component_type) -> cgltf_size ---
	calc_size :: proc(type: cgltf_type, component_type: cgltf_component_type) -> cgltf_size ---
	accessor_unpack_floats :: proc(accessor: ^cgltf_accessor, out: ^cgltf_float, float_count: cgltf_size) -> cgltf_size ---
	accessor_unpack_indices :: proc(accessor: ^cgltf_accessor, out: rawptr, out_component_size: cgltf_size, index_count: cgltf_size) -> cgltf_size ---
	/* this function is deprecated and will be removed in the future; use cgltf_extras::data instead */
	copy_extras_json :: proc(data: ^cgltf_data, extras: ^cgltf_extras, dest: ^u8, dest_size: ^cgltf_size) -> cgltf_result ---
	mesh_index :: proc(data: ^cgltf_data, object: ^cgltf_mesh) -> cgltf_size ---
	material_index :: proc(data: ^cgltf_data, object: ^cgltf_material) -> cgltf_size ---
	accessor_index :: proc(data: ^cgltf_data, object: ^cgltf_accessor) -> cgltf_size ---
	buffer_view_index :: proc(data: ^cgltf_data, object: ^cgltf_buffer_view) -> cgltf_size ---
	buffer_index :: proc(data: ^cgltf_data, object: ^cgltf_buffer) -> cgltf_size ---
	image_index :: proc(data: ^cgltf_data, object: ^cgltf_image) -> cgltf_size ---
	texture_index :: proc(data: ^cgltf_data, object: ^cgltf_texture) -> cgltf_size ---
	sampler_index :: proc(data: ^cgltf_data, object: ^cgltf_sampler) -> cgltf_size ---
	skin_index :: proc(data: ^cgltf_data, object: ^cgltf_skin) -> cgltf_size ---
	camera_index :: proc(data: ^cgltf_data, object: ^cgltf_camera) -> cgltf_size ---
	light_index :: proc(data: ^cgltf_data, object: ^cgltf_light) -> cgltf_size ---
	node_index :: proc(data: ^cgltf_data, object: ^cgltf_node) -> cgltf_size ---
	scene_index :: proc(data: ^cgltf_data, object: ^cgltf_scene) -> cgltf_size ---
	animation_index :: proc(data: ^cgltf_data, object: ^cgltf_animation) -> cgltf_size ---
	animation_sampler_index :: proc(animation: ^cgltf_animation, object: ^cgltf_animation_sampler) -> cgltf_size ---
	animation_channel_index :: proc(animation: ^cgltf_animation, object: ^cgltf_animation_channel) -> cgltf_size ---
}
