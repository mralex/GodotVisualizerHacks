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
@export var smoothing: float = 0.15

# Visual elements
var bass_cubes: Array[MeshInstance3D] = []
var mid_rings: Array[MeshInstance3D] = []
var high_spheres: Array[MeshInstance3D] = []
var center_orb: MeshInstance3D

# Materials
var bass_material: ShaderMaterial
var mid_material: ShaderMaterial
var high_material: ShaderMaterial
var orb_material: ShaderMaterial

# Animation time
var time: float = 0.0

func _ready() -> void:
	setup_audio()
	setup_materials()
	setup_visuals()

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

func setup_visuals() -> void:
	# Create bass cubes in a ring
	var bass_count = 8
	for i in range(bass_count):
		var cube = MeshInstance3D.new()
		cube.mesh = BoxMesh.new()
		cube.mesh.size = Vector3(0.4, 0.4, 0.4)
		cube.material_override = bass_material

		var angle = (float(i) / bass_count) * TAU
		cube.position = Vector3(cos(angle) * 2.5, 0, sin(angle) * 2.5)
		cube.rotation.y = angle

		add_child(cube)
		bass_cubes.append(cube)

	# Create mid-frequency rings/tori
	var mid_count = 6
	for i in range(mid_count):
		var torus = MeshInstance3D.new()
		var torus_mesh = TorusMesh.new()
		torus_mesh.inner_radius = 0.1
		torus_mesh.outer_radius = 0.25
		torus.mesh = torus_mesh
		torus.material_override = mid_material

		var angle = (float(i) / mid_count) * TAU + PI / 6
		torus.position = Vector3(cos(angle) * 1.5, 0.5 * sin(angle * 2), sin(angle) * 1.5)

		add_child(torus)
		mid_rings.append(torus)

	# Create high-frequency spheres
	var high_count = 16
	for i in range(high_count):
		var sphere = MeshInstance3D.new()
		var sphere_mesh = SphereMesh.new()
		sphere_mesh.radius = 0.08
		sphere_mesh.height = 0.16
		sphere.mesh = sphere_mesh
		sphere.material_override = high_material

		# Distribute in a spiral pattern
		var t = float(i) / high_count
		var angle = t * TAU * 2
		var radius = 0.8 + t * 0.5
		var height = sin(t * PI * 2) * 0.8
		sphere.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)

		add_child(sphere)
		high_spheres.append(sphere)

	# Create center orb
	center_orb = MeshInstance3D.new()
	var orb_mesh = SphereMesh.new()
	orb_mesh.radius = 0.5
	orb_mesh.height = 1.0
	center_orb.mesh = orb_mesh
	center_orb.material_override = orb_material
	add_child(center_orb)

func _process(delta: float) -> void:
	time += delta

	analyze_spectrum()
	update_visuals(delta)
	update_shader_params()

func analyze_spectrum() -> void:
	if not spectrum_analyzer:
		return

	# Frequency ranges (in Hz)
	# Bass: 20-250 Hz
	# Mids: 250-4000 Hz
	# Highs: 4000-20000 Hz

	var bass_raw = get_frequency_range_energy(20.0, 250.0)
	var mid_raw = get_frequency_range_energy(250.0, 4000.0)
	var high_raw = get_frequency_range_energy(4000.0, 16000.0)

	# Smooth the values
	bass_energy = lerp(bass_energy, bass_raw, smoothing)
	mid_energy = lerp(mid_energy, mid_raw, smoothing)
	high_energy = lerp(high_energy, high_raw, smoothing)
	total_energy = (bass_energy + mid_energy + high_energy) / 3.0

func get_frequency_range_energy(from_hz: float, to_hz: float) -> float:
	var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	# Convert to decibels and normalize
	var energy = (magnitude.x + magnitude.y) / 2.0
	# Scale and clamp
	energy = clamp(energy * 50.0, 0.0, 1.0)
	return energy

func update_visuals(delta: float) -> void:
	# Animate bass cubes
	for i in range(bass_cubes.size()):
		var cube = bass_cubes[i]
		var base_scale = 0.5 + bass_energy * 1.5
		var pulse = sin(time * 4.0 + i * 0.5) * 0.1 * bass_energy
		cube.scale = Vector3.ONE * (base_scale + pulse)

		# Rotate towards center based on bass
		var angle = (float(i) / bass_cubes.size()) * TAU
		cube.rotation.y = angle + time * 0.5 + bass_energy * 0.5
		cube.rotation.x = bass_energy * 0.3

		# Move up/down with bass
		var base_pos = Vector3(cos(angle) * 2.5, 0, sin(angle) * 2.5)
		cube.position = base_pos + Vector3(0, bass_energy * 0.5, 0)

	# Animate mid rings
	for i in range(mid_rings.size()):
		var ring = mid_rings[i]
		var angle = (float(i) / mid_rings.size()) * TAU + PI / 6

		# Orbit and tilt based on mids
		ring.rotation.x = time * 2.0 + i
		ring.rotation.y = time * 1.5 + mid_energy * PI

		var orbit_speed = 1.0 + mid_energy * 2.0
		var current_angle = angle + time * orbit_speed * 0.3
		var radius = 1.5 + mid_energy * 0.5
		var height = sin(current_angle * 2 + time) * (0.5 + mid_energy)
		ring.position = Vector3(cos(current_angle) * radius, height, sin(current_angle) * radius)

		# Scale with mids
		ring.scale = Vector3.ONE * (0.8 + mid_energy * 0.8)

	# Animate high spheres
	for i in range(high_spheres.size()):
		var sphere = high_spheres[i]
		var t = float(i) / high_spheres.size()

		# Spiral motion affected by highs
		var spiral_speed = 2.0 + high_energy * 3.0
		var angle = t * TAU * 2 + time * spiral_speed
		var radius = 0.8 + t * 0.5 + high_energy * 0.3
		var height = sin(t * PI * 2 + time * 3.0) * (0.8 + high_energy)

		sphere.position = Vector3(cos(angle) * radius, height, sin(angle) * radius)

		# Scale based on highs with individual variation
		var individual_pulse = sin(time * 8.0 + i * 0.8) * 0.3
		sphere.scale = Vector3.ONE * (0.5 + high_energy * 1.5 + individual_pulse * high_energy)

	# Animate center orb
	var orb_scale = 0.5 + total_energy * 0.8
	var orb_pulse = sin(time * 6.0) * 0.1 * total_energy
	center_orb.scale = Vector3.ONE * (orb_scale + orb_pulse)
	center_orb.rotation.y = time * 0.5
	center_orb.rotation.x = sin(time * 0.3) * 0.2

func update_shader_params() -> void:
	# Update shader uniforms with audio data
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
