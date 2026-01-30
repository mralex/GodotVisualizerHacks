extends Node3D

## Audio-responsive 3D visualizer
## Analyzes FFT spectrum and drives visual elements

# Audio analysis
var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var audio_player: AudioStreamPlayer

# Frequency band data (smoothed)
var bass_energy: float = 0.0
var mid_energy: float = 0.0
var high_energy: float = 0.0
var total_energy: float = 0.0

# Smoothing factor (lower = smoother)
@export var smoothing: float = 0.2
@export var intensity: float = 1.5

# Visual elements
var bass_cubes: Array[MeshInstance3D] = []
var mid_rings: Array[MeshInstance3D] = []
var high_spheres: Array[MeshInstance3D] = []
var center_orb: MeshInstance3D
var background_sphere: MeshInstance3D
var inner_cubes: Array[MeshInstance3D] = []

# Materials
var bass_material: ShaderMaterial
var mid_material: ShaderMaterial
var high_material: ShaderMaterial
var orb_material: ShaderMaterial
var background_material: ShaderMaterial
var post_process_material: ShaderMaterial

# Post processing
var canvas_layer: CanvasLayer
var post_process_rect: ColorRect

# Animation time
var time: float = 0.0

func _ready() -> void:
	setup_audio()
	setup_materials()
	setup_background()
	setup_visuals()
	setup_post_processing()

func setup_audio() -> void:
	# Get the spectrum analyzer from the Record bus
	var bus_idx = AudioServer.get_bus_index("Record")
	if bus_idx == -1:
		push_error("Record bus not found! Creating one...")
		AudioServer.add_bus()
		bus_idx = AudioServer.bus_count - 1
		AudioServer.set_bus_name(bus_idx, "Record")

	# Check for existing spectrum analyzer effect
	var effect_idx = -1
	for i in range(AudioServer.get_bus_effect_count(bus_idx)):
		if AudioServer.get_bus_effect(bus_idx, i) is AudioEffectSpectrumAnalyzer:
			effect_idx = i
			break

	# Add spectrum analyzer if not present
	if effect_idx == -1:
		var analyzer = AudioEffectSpectrumAnalyzer.new()
		analyzer.buffer_length = 0.1
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_2048
		AudioServer.add_bus_effect(bus_idx, analyzer)
		effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1

	spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, effect_idx)

	# Create audio input stream
	audio_player = AudioStreamPlayer.new()
	audio_player.stream = AudioStreamMicrophone.new()
	audio_player.bus = "Record"
	add_child(audio_player)
	audio_player.play()

func setup_materials() -> void:
	# Bass material - deep pulsing glow
	bass_material = ShaderMaterial.new()
	bass_material.shader = preload("res://bass_shader.gdshader")

	# Mid material - metallic with color shift
	mid_material = ShaderMaterial.new()
	mid_material.shader = preload("res://mid_shader.gdshader")

	# High material - bright particles
	high_material = ShaderMaterial.new()
	high_material.shader = preload("res://high_shader.gdshader")

	# Center orb material
	orb_material = ShaderMaterial.new()
	orb_material.shader = preload("res://orb_shader.gdshader")

	# Background material
	background_material = ShaderMaterial.new()
	background_material.shader = preload("res://background_shader.gdshader")

	# Post process material
	post_process_material = ShaderMaterial.new()
	post_process_material.shader = preload("res://post_process.gdshader")

func setup_background() -> void:
	# Create large inverted sphere for background
	background_sphere = MeshInstance3D.new()
	var bg_mesh = SphereMesh.new()
	bg_mesh.radius = 50.0
	bg_mesh.height = 100.0
	bg_mesh.radial_segments = 64
	bg_mesh.rings = 32
	background_sphere.mesh = bg_mesh
	background_sphere.material_override = background_material
	add_child(background_sphere)

func setup_visuals() -> void:
	# Create bass cubes in a ring - more of them
	var bass_count = 12
	for i in range(bass_count):
		var cube = MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		cube.mesh.size = Vector3(0.5, 0.5, 0.5)
		cube.material_override = bass_material

		var angle = (float(i) / bass_count) * TAU
		cube.position = Vector3(cos(angle) * 3.0, 0, sin(angle) * 3.0)
		cube.rotation.y = angle

		add_child(cube)
		bass_cubes.append(cube)

	# Second ring of bass cubes (outer)
	for i in range(bass_count):
		var cube = MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		cube.mesh.size = Vector3(0.35, 0.35, 0.35)
		cube.material_override = bass_material

		var angle = (float(i) / bass_count) * TAU + (PI / bass_count)
		cube.position = Vector3(cos(angle) * 4.0, 0.3, sin(angle) * 4.0)
		cube.rotation.y = angle

		add_child(cube)
		bass_cubes.append(cube)

	# Inner rotating cubes
	var inner_count = 6
	for i in range(inner_count):
		var cube = MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		cube.mesh.size = Vector3(0.25, 0.25, 0.25)
		cube.material_override = bass_material

		var angle = (float(i) / inner_count) * TAU
		cube.position = Vector3(cos(angle) * 0.8, 0, sin(angle) * 0.8)

		add_child(cube)
		inner_cubes.append(cube)

	# Create mid-frequency rings/tori - more of them
	var mid_count = 10
	for i in range(mid_count):
		var torus = MeshInstance3D.new()
		var torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = 0.08 + (i % 3) * 0.04
		torus_mesh.outer_radius = 0.2 + (i % 3) * 0.08
		torus.mesh = torus_mesh
		torus.material_override = mid_material

		var angle = (float(i) / mid_count) * TAU + PI / 6
		var layer = float(i % 3) - 1.0
		torus.position = Vector3(cos(angle) * 1.8, layer * 0.5, sin(angle) * 1.8)

		add_child(torus)
		mid_rings.append(torus)

	# Create high-frequency spheres - lots more
	var high_count = 32
	for i in range(high_count):
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.06 + randf() * 0.04
		sphere_mesh.height = sphere_mesh.radius * 2
		sphere.mesh = sphere_mesh
		sphere.material_override = high_material

		# Distribute in multiple spirals
		var t = float(i) / high_count
		var spiral = i % 3
		var angle = t * TAU * 3 + spiral * TAU / 3
		var radius = 0.6 + t * 1.2
		var height = sin(t * PI * 3) * 1.2
		sphere.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)

		add_child(sphere)
		high_spheres.append(sphere)

	# Create center orb
	center_orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.4
	orb_mesh.height = 0.8
	center_orb.mesh = orb_mesh
	center_orb.material_override = orb_material
	add_child(center_orb)

func setup_post_processing() -> void:
	# Create canvas layer for post processing
	canvas_layer = CanvasLayer.new()
	canvas_layer.layer = 10
	add_child(canvas_layer)

	# Create full-screen color rect with shader
	post_process_rect = ColorRect.new()
	post_process_rect.anchors_preset = Control.PRESET_FULL_RECT
	post_process_rect.material = post_process_material
	canvas_layer.add_child(post_process_rect)

func _process(delta: float) -> void:
	time += delta

	analyze_spectrum()
	update_visuals(delta)
	update_shader_params()

func analyze_spectrum() -> void:
	if not spectrum_analyzer:
		return

	# Frequency ranges (in Hz)
	var bass_raw = get_frequency_range_energy(20.0, 250.0)
	var mid_raw = get_frequency_range_energy(250.0, 4000.0)
	var high_raw = get_frequency_range_energy(4000.0, 16000.0)

	# Smooth the values
	bass_energy = lerp(bass_energy, bass_raw * intensity, smoothing)
	mid_energy = lerp(mid_energy, mid_raw * intensity, smoothing)
	high_energy = lerp(high_energy, high_raw * intensity, smoothing)
	total_energy = (bass_energy + mid_energy + high_energy) / 3.0

func get_frequency_range_energy(from_hz: float, to_hz: float) -> float:
	var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var energy = (magnitude.x + magnitude.y) / 2.0
	energy = clamp(energy * 60.0, 0.0, 1.0)
	return energy

func update_visuals(delta: float) -> void:
	# Animate bass cubes
	for i in range(bass_cubes.size()):
		var cube = bass_cubes[i]
		var ring = 0 if i < 12 else 1
		var idx = i if i < 12 else i - 12
		var count = 12

		var base_scale = 0.4 + bass_energy * 2.0
		var pulse = sin(time * 5.0 + i * 0.4) * 0.15 * bass_energy
		var scale_mult = 1.0 if ring == 0 else 0.7
		cube.scale = Vector3.ONE * (base_scale + pulse) * scale_mult

		var base_radius = 3.0 if ring == 0 else 4.0
		var radius = base_radius + bass_energy * 0.5
		var angle = (float(idx) / count) * TAU
		if ring == 1:
			angle += PI / count

		# Rotation
		cube.rotation.y = angle + time * (0.5 + bass_energy) + bass_energy * sin(time * 2.0)
		cube.rotation.x = bass_energy * 0.5 + sin(time * 3.0 + i) * 0.2
		cube.rotation.z = cos(time * 2.0 + i * 0.5) * bass_energy * 0.3

		# Position with bounce
		var height = sin(time * 4.0 + i * 0.3) * bass_energy * 0.8
		if ring == 1:
			height += 0.3
		cube.position = Vector3(cos(angle + time * 0.2) * radius, height, sin(angle + time * 0.2) * radius)

	# Animate inner cubes
	for i in range(inner_cubes.size()):
		var cube = inner_cubes[i]
		var angle = (float(i) / inner_cubes.size()) * TAU + time * 3.0
		var radius = 0.7 + total_energy * 0.4

		cube.position = Vector3(cos(angle) * radius, sin(time * 5.0 + i) * total_energy * 0.5, sin(angle) * radius)
		cube.rotation = Vector3(time * 4.0, time * 3.0 + i, time * 2.0)
		cube.scale = Vector3.ONE * (0.2 + total_energy * 0.4)

	# Animate mid rings
	for i in range(mid_rings.size()):
		var ring = mid_rings[i]
		var angle = (float(i) / mid_rings.size()) * TAU + PI / 6

		# Wild rotation
		ring.rotation.x = time * 3.0 + i + mid_energy * 2.0
		ring.rotation.y = time * 2.0 + mid_energy * PI * 2.0
		ring.rotation.z = sin(time * 2.0 + i) * mid_energy

		var orbit_speed = 1.5 + mid_energy * 3.0
		var current_angle = angle + time * orbit_speed * 0.4
		var radius = 1.8 + mid_energy * 0.8 + sin(time * 2.0 + i) * 0.3
		var layer = float(i % 3) - 1.0
		var height = layer * (0.5 + mid_energy) + sin(current_angle * 3 + time * 2.0) * mid_energy

		ring.position = Vector3(cos(current_angle) * radius, height, sin(current_angle) * radius)
		ring.scale = Vector3.ONE * (0.8 + mid_energy * 1.2)

	# Animate high spheres
	for i in range(high_spheres.size()):
		var sphere = high_spheres[i]
		var t = float(i) / high_spheres.size()
		var spiral = i % 3

		# Fast chaotic motion
		var spiral_speed = 3.0 + high_energy * 5.0
		var angle = t * TAU * 3 + spiral * TAU / 3 + time * spiral_speed
		var base_radius = 0.6 + t * 1.2
		var radius = base_radius + high_energy * 0.6 + sin(time * 8.0 + i) * 0.2
		var height = sin(t * PI * 3 + time * 4.0) * (1.2 + high_energy * 0.8)

		sphere.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)

		# Pulsing scale
		var individual_pulse = sin(time * 12.0 + i * 1.2) * 0.4
		sphere.scale = Vector3.ONE * (0.4 + high_energy * 2.0 + individual_pulse * high_energy)

	# Animate center orb
	var orb_scale = 0.4 + total_energy * 1.2
	var orb_pulse = sin(time * 8.0) * 0.15 * total_energy
	center_orb.scale = Vector3.ONE * (orb_scale + orb_pulse)
	center_orb.rotation.y = time * 1.0
	center_orb.rotation.x = sin(time * 0.5) * 0.3 + total_energy * 0.2

	# Rotate background slowly
	background_sphere.rotation.y = time * 0.1
	background_sphere.rotation.x = sin(time * 0.05) * 0.1

func update_shader_params() -> void:
	if bass_material:
		bass_material.set_shader_parameter("energy", bass_energy)
		bass_material.set_shader_parameter("time", time)

	if mid_material:
		mid_material.set_shader_parameter("energy", mid_energy)
		mid_material.set_shader_parameter("time", time)

	if high_material:
		high_material.set_shader_parameter("energy", high_energy)
		high_material.set_shader_parameter("time", time)

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
