class_name StarfieldEffects
extends Node

const STAR_COUNT: int = 4000
const CYLINDER_RADIUS: float = 40.0
const CYLINDER_DEPTH: float = 120.0
const RECYCLE_Z: float = 2.0
const HERO_STAR_CHANCE: float = 0.05
var warp_decay_rate: float = 4.0
var warp_bass_threshold: float = 0.7
var star_size_multiplier: float = 1.0
var trail_strength: float = 0.6

var multi_mesh_instance: MultiMeshInstance3D
var multi_mesh: MultiMesh
var star_material: ShaderMaterial
var post_process_material: ShaderMaterial
var post_process_rect: ColorRect
var warp_intensity: float = 0.0

# Nebulae
const NEBULA_COUNT: int = 6
var nebula_meshes: Array[MeshInstance3D] = []
var nebula_materials: Array[ShaderMaterial] = []
var nebula_z_positions: PackedFloat32Array

# Per-star Z positions (relative to camera)
var star_z_positions: PackedFloat32Array

func setup(parent: Node) -> void:
	_setup_star_material()
	_setup_multi_mesh(parent)
	_init_star_positions()
	_setup_nebulae(parent)
	_setup_post_processing(parent)

func update(delta: float, time: float, bass: float, mid: float, high: float, total: float, speed: float) -> void:
	# Warp trigger and decay
	if bass > warp_bass_threshold:
		warp_intensity = maxf(warp_intensity, bass)
	warp_intensity = maxf(0.0, warp_intensity - warp_decay_rate * delta)

	# Update star shader uniforms
	var speed_ratio = clampf((speed - 0.5) / 3.5, 0.0, 1.0)
	star_material.set_shader_parameter("total_energy", total)
	star_material.set_shader_parameter("high", high)
	star_material.set_shader_parameter("warp_intensity", warp_intensity)
	star_material.set_shader_parameter("size_multiplier", star_size_multiplier)
	star_material.set_shader_parameter("trail_strength", trail_strength)
	star_material.set_shader_parameter("speed_ratio", speed_ratio)
	star_material.set_shader_parameter("time", time)

	# Advance stars toward camera and recycle
	for i in STAR_COUNT:
		star_z_positions[i] -= speed * delta

		if star_z_positions[i] < -RECYCLE_Z:
			# Recycle to far end
			star_z_positions[i] += CYLINDER_DEPTH
			_randomize_star_xy(i)

		# Update transform
		var t = multi_mesh.get_instance_transform(i)
		t.origin.z = -star_z_positions[i]
		multi_mesh.set_instance_transform(i, t)

	# Update nebulae
	for i in NEBULA_COUNT:
		nebula_z_positions[i] -= speed * delta * 0.3  # Nebulae move slower (parallax)
		if nebula_z_positions[i] < -20.0:
			nebula_z_positions[i] += CYLINDER_DEPTH * 1.5
			_randomize_nebula_xy(i)
		nebula_meshes[i].position.z = -nebula_z_positions[i]
		nebula_materials[i].set_shader_parameter("mid", mid)
		nebula_materials[i].set_shader_parameter("total_energy", total)
		nebula_materials[i].set_shader_parameter("time", time)

	# Update post-processing
	post_process_material.set_shader_parameter("bass", bass)
	post_process_material.set_shader_parameter("mid", mid)
	post_process_material.set_shader_parameter("high", high)
	post_process_material.set_shader_parameter("warp_intensity", warp_intensity)
	post_process_material.set_shader_parameter("time", time)

func trigger_beat_pulse() -> void:
	warp_intensity = 1.0

func trigger_bass(_velocity: float = 1.0) -> void:
	warp_intensity = maxf(warp_intensity, 0.8)

func _setup_star_material() -> void:
	var shader = load("res://Shaders/starfield_shader.gdshader")
	star_material = ShaderMaterial.new()
	star_material.shader = shader

func _setup_multi_mesh(parent: Node) -> void:
	# Create a small quad mesh for each star
	var quad = QuadMesh.new()
	quad.size = Vector2(1.0, 1.0)

	multi_mesh = MultiMesh.new()
	multi_mesh.transform_format = MultiMesh.TRANSFORM_3D
	multi_mesh.use_custom_data = true
	multi_mesh.instance_count = STAR_COUNT
	multi_mesh.mesh = quad

	multi_mesh_instance = MultiMeshInstance3D.new()
	multi_mesh_instance.multimesh = multi_mesh
	multi_mesh_instance.material_override = star_material
	parent.add_child(multi_mesh_instance)

func _init_star_positions() -> void:
	star_z_positions = PackedFloat32Array()
	star_z_positions.resize(STAR_COUNT)

	for i in STAR_COUNT:
		# Z distributed along cylinder depth
		star_z_positions[i] = randf() * CYLINDER_DEPTH

		# XY: sqrt(randf()) for uniform disk coverage
		var angle = randf() * TAU
		var radius = sqrt(randf()) * CYLINDER_RADIUS
		var x = cos(angle) * radius
		var y = sin(angle) * radius

		var t = Transform3D()
		t.origin = Vector3(x, y, -star_z_positions[i])
		multi_mesh.set_instance_transform(i, t)

		# INSTANCE_CUSTOM: (star_id, brightness, twinkle_phase, size)
		var star_id = float(i) / float(STAR_COUNT)
		var is_hero = randf() < HERO_STAR_CHANCE
		var brightness = randf_range(0.3, 1.0) if not is_hero else randf_range(0.8, 1.0)
		var twinkle_phase = randf()
		var size = randf_range(0.08, 0.2) if not is_hero else randf_range(0.25, 0.5)

		multi_mesh.set_instance_custom_data(i, Color(star_id, brightness, twinkle_phase, size))

func _randomize_star_xy(i: int) -> void:
	var angle = randf() * TAU
	var radius = sqrt(randf()) * CYLINDER_RADIUS
	var t = multi_mesh.get_instance_transform(i)
	t.origin.x = cos(angle) * radius
	t.origin.y = sin(angle) * radius
	multi_mesh.set_instance_transform(i, t)

func _setup_nebulae(parent: Node) -> void:
	var nebula_shader = load("res://Shaders/nebula_shader.gdshader")
	nebula_z_positions = PackedFloat32Array()
	nebula_z_positions.resize(NEBULA_COUNT)

	for i in NEBULA_COUNT:
		var mat = ShaderMaterial.new()
		mat.shader = nebula_shader
		mat.set_shader_parameter("nebula_id", float(i))

		var quad = QuadMesh.new()
		# Large quads for background nebulae
		var neb_size = randf_range(20.0, 40.0)
		quad.size = Vector2(neb_size, neb_size)

		var mesh_inst = MeshInstance3D.new()
		mesh_inst.mesh = quad
		mesh_inst.material_override = mat

		# Distribute in a wide ring, far from center
		var angle = randf() * TAU
		var radius = randf_range(15.0, 35.0)
		nebula_z_positions[i] = randf() * CYLINDER_DEPTH * 1.5
		mesh_inst.position = Vector3(cos(angle) * radius, sin(angle) * radius, -nebula_z_positions[i])

		parent.add_child(mesh_inst)
		nebula_meshes.append(mesh_inst)
		nebula_materials.append(mat)

func _randomize_nebula_xy(i: int) -> void:
	var angle = randf() * TAU
	var radius = randf_range(15.0, 35.0)
	nebula_meshes[i].position.x = cos(angle) * radius
	nebula_meshes[i].position.y = sin(angle) * radius

func _setup_post_processing(parent: Node) -> void:
	var shader = load("res://Shaders/starfield_post_process.gdshader")
	post_process_material = ShaderMaterial.new()
	post_process_material.shader = shader

	var canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	parent.add_child(canvas_layer)

	post_process_rect = ColorRect.new()
	post_process_rect.anchors_preset = Control.PRESET_FULL_RECT
	post_process_rect.material = post_process_material
	canvas_layer.add_child(post_process_rect)
