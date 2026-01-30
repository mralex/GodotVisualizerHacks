extends Node3D

## Audio-responsive 3D visualizer with abstract shapes

# Audio analysis
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var audio_player: AudioStreamPlayer

# Frequency band data (smoothed)
var bass_energy: float = 0.0
var mid_energy: float = 0.0
var high_energy: float = 0.0
var total_energy: float = 0.0

@export var smoothing: float = 0.2
@export var intensity: float = 1.5

# Visual elements
var crystal_shapes: Array[MeshInstance3D] = []
var ribbons: Array[MeshInstance3D] = []
var particles: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var center_form: MeshInstance3D
var background_sphere: MeshInstance3D
var orbit_rings: Array[MeshInstance3D] = []

# Materials
var bass_material: ShaderMaterial
var mid_material: ShaderMaterial
var high_material: ShaderMaterial
var ribbon_material: ShaderMaterial
var spark_material: ShaderMaterial
var orb_material: ShaderMaterial
var background_material: ShaderMaterial
var post_process_material: ShaderMaterial

# Post processing
var canvas_layer: CanvasLayer
var post_process_rect: ColorRect

var time: float = 0.0

func _ready() -> void:
	setup_audio()
	setup_materials()
	setup_background()
	setup_abstract_visuals()
	setup_post_processing()

func setup_audio() -> void:
	var bus_idx = AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("Record bus not found! Creating one...")
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "Record")

	var effect_idx = -1
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectSpectrumAnalyzer:
			effect_idx = i
			break

	if effect_idx == -1:
		var analyzer = AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.1
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(bus_idx, analyzer)
		effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1

	spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, effect_idx)

	audio_player = AudioStreamPlayer.new()
	audio_player.stream = AudioStreamMicrophone.new()
	audio_player.bus = "Record"
	add_child(audio_player)
	audio_player.play()

func setup_materials() -> void:
	bass_material = ShaderMaterial.new()
	bass_material.shader = preload("res://abstract_bass_shader.gdshader")

	mid_material = ShaderMaterial.new()
	mid_material.shader = preload("res://abstract_mid_shader.gdshader")

	high_material = ShaderMaterial.new()
	high_material.shader = preload("res://abstract_high_shader.gdshader")

	ribbon_material = ShaderMaterial.new()
	ribbon_material.shader = preload("res://ribbon_shader.gdshader")

	spark_material = ShaderMaterial.new()
	spark_material.shader = preload("res://spark_shader.gdshader")

	orb_material = ShaderMaterial.new()
	orb_material.shader = preload("res://orb_shader.gdshader")

	background_material = ShaderMaterial.new()
	background_material.shader = preload("res://background_shader.gdshader")

	post_process_material = ShaderMaterial.new()
	post_process_material.shader = preload("res://post_process.gdshader")

func setup_background() -> void:
	background_sphere = MeshInstance3D.new()
	var bg_mesh = SphereMesh.new()
	bg_mesh.radius = 50.0
	bg_mesh.height = 100.0
	bg_mesh.radial_segments = 64
	bg_mesh.rings = 32
	background_sphere.mesh = bg_mesh
	background_sphere.material_override = background_material
	add_child(background_sphere)

func create_crystal_mesh() -> ArrayMesh:
	# Create an elongated octahedron / crystal shape
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	# Crystal points
	var top = Vector3(0, 1.5, 0)
	var bottom = Vector3(0, -1.5, 0)
	var points: Array[Vector3] = []
	var sides = 6
	for i in range(sides):
		var angle = float(i) / sides * TAU
		points.append(Vector3(cos(angle) * 0.4, 0, sin(angle) * 0.4))

	# Build triangles
	for i in range(sides):
		var next = (i + 1) % sides
		# Top faces
		vertices.append(top)
		vertices.append(points[i])
		vertices.append(points[next])
		# Bottom faces
		vertices.append(bottom)
		vertices.append(points[next])
		vertices.append(points[i])

	# Calculate normals
	for i in range(0, vertices.size(), 3):
		var v0 = vertices[i]
		var v1 = vertices[i + 1]
		var v2 = vertices[i + 2]
		var normal = (v1 - v0).cross(v2 - v0).normalized()
		normals.append(normal)
		normals.append(normal)
		normals.append(normal)
		uvs.append(Vector2(0.5, 0))
		uvs.append(Vector2(0, 1))
		uvs.append(Vector2(1, 1))

	for i in range(vertices.size()):
		indices.append(i)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_ribbon_mesh(length: float, width: float, segments: int) -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array()
	var normals = PackedVector3Array()
	var uvs = PackedVector2Array()
	var indices = PackedInt32Array()

	for i in range(segments + 1):
		var t = float(i) / segments
		var x = (t - 0.5) * length
		vertices.append(Vector3(x, 0, -width / 2))
		vertices.append(Vector3(x, 0, width / 2))
		normals.append(Vector3(0, 1, 0))
		normals.append(Vector3(0, 1, 0))
		uvs.append(Vector2(t, 0))
		uvs.append(Vector2(t, 1))

	for i in range(segments):
		var base = i * 2
		indices.append(base)
		indices.append(base + 1)
		indices.append(base + 2)
		indices.append(base + 1)
		indices.append(base + 3)
		indices.append(base + 2)

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func create_particle_quad() -> ArrayMesh:
	var mesh = ArrayMesh.new()
	var vertices = PackedVector3Array([
		Vector3(-0.5, -0.5, 0), Vector3(0.5, -0.5, 0),
		Vector3(0.5, 0.5, 0), Vector3(-0.5, 0.5, 0)
	])
	var normals = PackedVector3Array([
		Vector3(0, 0, 1), Vector3(0, 0, 1),
		Vector3(0, 0, 1), Vector3(0, 0, 1)
	])
	var uvs = PackedVector2Array([
		Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2(0, 0)
	])
	var indices = PackedInt32Array([0, 1, 2, 0, 2, 3])

	var arrays = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = indices

	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return mesh

func setup_abstract_visuals() -> void:
	var crystal_mesh = create_crystal_mesh()
	var ribbon_mesh = create_ribbon_mesh(4.0, 0.3, 32)
	var particle_mesh = create_particle_quad()

	# Floating crystals (bass) - arranged in organic clusters
	var crystal_count = 15
	for i in range(crystal_count):
		var crystal = MeshInstance3D.new()
		crystal.mesh = crystal_mesh
		var mat = bass_material.duplicate() as ShaderMaterial
		crystal.material_override = mat

		# Organic positioning
		var golden_angle = PI * (3.0 - sqrt(5.0))
		var theta = golden_angle * i
		var radius = 2.0 + sqrt(float(i)) * 0.5
		var height = sin(float(i) * 0.5) * 1.5

		crystal.position = Vector3(
			cos(theta) * radius,
			height,
			sin(theta) * radius
		)
		crystal.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		add_child(crystal)
		crystal_shapes.append(crystal)

	# Flowing ribbons (mid)
	var ribbon_count = 5
	for i in range(ribbon_count):
		var ribbon = MeshInstance3D.new()
		ribbon.mesh = ribbon_mesh
		var mat = ribbon_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("ribbon_id", float(i))
		ribbon.material_override = mat

		var angle = float(i) / ribbon_count * TAU
		ribbon.position = Vector3(cos(angle) * 1.2, 0, sin(angle) * 1.2)
		ribbon.rotation.y = angle + PI / 2

		add_child(ribbon)
		ribbons.append(ribbon)

	# Particle swarm (high)
	var particle_count = 40
	for i in range(particle_count):
		var particle = MeshInstance3D.new()
		particle.mesh = particle_mesh
		var mat = high_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("particle_id", float(i))
		particle.material_override = mat

		# Random spherical distribution
		var phi = randf() * TAU
		var costheta = randf() * 2.0 - 1.0
		var theta = acos(costheta)
		var r = 1.0 + randf() * 2.0

		particle.position = Vector3(
			r * sin(theta) * cos(phi),
			r * sin(theta) * sin(phi),
			r * cos(theta)
		)
		particle.scale = Vector3.ONE * (0.1 + randf() * 0.15)

		add_child(particle)
		particles.append(particle)

	# Orbit rings (geometric accents)
	for i in range(3):
		var ring = MeshInstance3D.new()
		var torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = 2.5 + i * 0.8
		torus_mesh.outer_radius = 2.55 + i * 0.8
		torus_mesh.rings = 64
		torus_mesh.ring_segments = 6
		ring.mesh = torus_mesh
		ring.material_override = mid_material.duplicate()

		ring.rotation.x = PI / 4 + i * 0.3
		ring.rotation.z = i * 0.5

		add_child(ring)
		orbit_rings.append(ring)

	# Sparking particles
	var spark_count = 20
	for i in range(spark_count):
		var spark = MeshInstance3D.new()
		spark.mesh = particle_mesh
		var mat = spark_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("spark_id", float(i))
		spark.material_override = mat

		# Random position in space
		spark.position = Vector3(
			(randf() - 0.5) * 6.0,
			(randf() - 0.5) * 4.0,
			(randf() - 0.5) * 6.0
		)
		spark.scale = Vector3.ONE * (0.08 + randf() * 0.1)

		add_child(spark)
		sparks.append(spark)

	# Center form - icosphere-like
	center_form = MeshInstance3D.new()
	var center_mesh = SphereMesh.new()
	center_mesh.radius = 0.4
	center_mesh.height = 0.8
	center_mesh.radial_segments = 8
	center_mesh.rings = 4
	center_form.mesh = center_mesh
	center_form.material_override = orb_material
	add_child(center_form)

func setup_post_processing() -> void:
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	post_process_rect = ColorRect.new()
	post_process_rect.anchors_preset = Control.PRESET_FULL_RECT
	post_process_rect.material = post_process_material
	canvas_layer.add_child(post_process_rect)

func _process(delta: float) -> void:
	time += delta
	analyze_spectrum()
	update_abstract_visuals(delta)
	update_shader_params()

func analyze_spectrum() -> void:
	if not spectrum_analyzer:
		return

	var bass_raw = get_frequency_range_energy(20.0, 250.0)
	var mid_raw = get_frequency_range_energy(250.0, 4000.0)
	var high_raw = get_frequency_range_energy(4000.0, 16000.0)

	bass_energy = lerp(bass_energy, bass_raw * intensity, smoothing)
	mid_energy = lerp(mid_energy, mid_raw * intensity, smoothing)
	high_energy = lerp(high_energy, high_raw * intensity, smoothing)
	total_energy = (bass_energy + mid_energy + high_energy) / 3.0

func get_frequency_range_energy(from_hz: float, to_hz: float) -> float:
	var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var energy = (magnitude.x + magnitude.y) / 2.0
	return clamp(energy * 60.0, 0.0, 1.0)

func update_abstract_visuals(delta: float) -> void:
	# Animate crystals
	for i in range(crystal_shapes.size()):
		var crystal = crystal_shapes[i]
		var mat = crystal.material_override as ShaderMaterial

		# Organic floating motion
		var phase = float(i) * 0.7 + time
		var float_y = sin(phase * 0.8) * 0.3 + cos(phase * 0.5) * 0.2
		var float_x = cos(phase * 0.6) * 0.15
		var float_z = sin(phase * 0.7) * 0.15

		var golden_angle = PI * (3.0 - sqrt(5.0))
		var theta = golden_angle * i + time * 0.2
		var base_radius = 2.0 + sqrt(float(i)) * 0.5 + bass_energy * 0.8
		var base_height = sin(float(i) * 0.5 + time * 0.3) * (1.5 + bass_energy)

		crystal.position = Vector3(
			cos(theta) * base_radius + float_x * bass_energy,
			base_height + float_y * bass_energy,
			sin(theta) * base_radius + float_z * bass_energy
		)

		# Tumbling rotation
		crystal.rotation.x += delta * (0.5 + bass_energy * 2.0)
		crystal.rotation.y += delta * (0.3 + bass_energy * 1.5)
		crystal.rotation.z += delta * 0.2

		# Scale pulse
		var scale_base = 0.6 + bass_energy * 0.8
		var scale_pulse = sin(time * 4.0 + i * 0.5) * 0.1 * bass_energy
		crystal.scale = Vector3.ONE * (scale_base + scale_pulse)

		mat.set_shader_parameter("energy", bass_energy)
		mat.set_shader_parameter("time", time)

	# Animate ribbons (slow, graceful movement)
	for i in range(ribbons.size()):
		var ribbon = ribbons[i]
		var mat = ribbon.material_override as ShaderMaterial

		var angle = float(i) / ribbons.size() * TAU + time * (0.15 + mid_energy * 0.2)
		var radius = 1.2 + mid_energy * 0.3
		ribbon.position = Vector3(cos(angle) * radius, sin(time * 0.5 + i) * mid_energy * 0.3, sin(angle) * radius)
		ribbon.rotation.y = angle + PI / 2
		ribbon.rotation.x = sin(time * 0.3 + i) * mid_energy * 0.3
		ribbon.rotation.z = cos(time * 0.2 + i) * mid_energy * 0.2

		ribbon.scale = Vector3.ONE * (0.8 + mid_energy * 0.3)

		mat.set_shader_parameter("energy", mid_energy)
		mat.set_shader_parameter("time", time)

	# Animate particles
	for i in range(particles.size()):
		var particle = particles[i]
		var mat = particle.material_override as ShaderMaterial

		# Swirling motion
		var phase = float(i) * 0.3 + time * (2.0 + high_energy * 3.0)
		var base_r = 1.0 + sin(float(i) * 0.5) * 0.5 + high_energy * 0.5
		var height_var = cos(phase * 0.5 + i * 0.2) * (1.0 + high_energy)

		particle.position = Vector3(
			cos(phase) * base_r,
			height_var,
			sin(phase) * base_r
		)

		# Billboard towards camera (simple Y-axis)
		particle.rotation.y = time * 0.5

		# Scale with energy
		var base_scale = 0.1 + sin(float(i) * 0.7) * 0.05
		var energy_scale = high_energy * 0.3
		particle.scale = Vector3.ONE * (base_scale + energy_scale)

		mat.set_shader_parameter("energy", high_energy)
		mat.set_shader_parameter("time", time)

	# Animate orbit rings
	for i in range(orbit_rings.size()):
		var ring = orbit_rings[i]
		ring.rotation.x += delta * (0.3 + mid_energy * 0.5) * (1.0 if i % 2 == 0 else -1.0)
		ring.rotation.y += delta * (0.2 + mid_energy * 0.3)
		ring.rotation.z += delta * 0.1 * (i + 1)

		var mat = ring.material_override as ShaderMaterial
		if mat:
			mat.set_shader_parameter("energy", mid_energy)
			mat.set_shader_parameter("time", time)

	# Animate sparks
	for i in range(sparks.size()):
		var spark = sparks[i]
		var mat = spark.material_override as ShaderMaterial

		# Slow drift with occasional jumps
		var drift_phase = time * 0.3 + float(i) * 0.5
		var base_x = sin(drift_phase * 0.7 + i) * 3.0
		var base_y = cos(drift_phase * 0.5 + i * 0.3) * 2.0
		var base_z = sin(drift_phase * 0.6 + i * 0.7) * 3.0

		spark.position = Vector3(base_x, base_y, base_z)

		# Scale flickers with total energy
		spark.scale = Vector3.ONE * (0.1 + total_energy * 0.15)

		mat.set_shader_parameter("energy", total_energy)
		mat.set_shader_parameter("time", time)

	# Center form
	var orb_scale = 0.4 + total_energy * 0.6
	var orb_pulse = sin(time * 6.0) * 0.1 * total_energy
	center_form.scale = Vector3.ONE * (orb_scale + orb_pulse)
	center_form.rotation.y = time * 0.8
	center_form.rotation.x = sin(time * 0.4) * 0.3

	# Background rotation
	background_sphere.rotation.y = time * 0.05
	background_sphere.rotation.x = sin(time * 0.03) * 0.05

func update_shader_params() -> void:
	if orb_material:
		orb_material.set_shader_parameter("bass", bass_energy)
		orb_material.set_shader_parameter("mid", mid_energy)
		orb_material.set_shader_parameter("high", high_energy)
		orb_material.set_shader_parameter("time", time)

	if background_material:
		background_material.set_shader_parameter("bass", bass_energy)
		background_material.set_shader_parameter("mid", mid_energy)
		background_material.set_shader_parameter("high", high_energy)
		background_material.set_shader_parameter("time", time)

	if post_process_material:
		post_process_material.set_shader_parameter("bass", bass_energy)
		post_process_material.set_shader_parameter("mid", mid_energy)
		post_process_material.set_shader_parameter("high", high_energy)
		post_process_material.set_shader_parameter("time", time)
