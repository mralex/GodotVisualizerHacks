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

# FFT frequency ranges (Hz)
var bass_min: float = 20.0
var bass_max: float = 250.0
var mid_min: float = 250.0
var mid_max: float = 4000.0
var high_min: float = 4000.0
var high_max: float = 16000.0

# GUI
var gui_layer: CanvasLayer
var gui_panel: PanelContainer
var gui_visible: bool = false
var gui_sliders: Dictionary = {}

# Camera reference
var orbit_camera: Node

# Audio input
var audio_input_dropdown: OptionButton

# Defaults
const DEFAULT_SMOOTHING: float = 0.2
const DEFAULT_INTENSITY: float = 1.5
const DEFAULT_BASS_MIN: float = 20.0
const DEFAULT_BASS_MAX: float = 250.0
const DEFAULT_MID_MIN: float = 250.0
const DEFAULT_MID_MAX: float = 4000.0
const DEFAULT_HIGH_MIN: float = 4000.0
const DEFAULT_HIGH_MAX: float = 16000.0
const DEFAULT_CAM_SPEED: float = 0.3
const DEFAULT_CAM_RADIUS: float = 6.0
const DEFAULT_CAM_HEIGHT: float = 3.0

# Visual elements
var crystal_shapes: Array[MeshInstance3D] = []
var ribbons: Array[MeshInstance3D] = []
var particles: Array[MeshInstance3D] = []
var sparks: Array[MeshInstance3D] = []
var bg_shapes: Array[MeshInstance3D] = []
var center_form: MeshInstance3D
var background_sphere: MeshInstance3D
var orbit_rings: Array[MeshInstance3D] = []

# Materials
var bass_material: ShaderMaterial
var mid_material: ShaderMaterial
var high_material: ShaderMaterial
var ribbon_material: ShaderMaterial
var spark_material: ShaderMaterial
var bg_shape_material: ShaderMaterial
var orb_material: ShaderMaterial
var background_material: ShaderMaterial
var post_process_material: ShaderMaterial

# Post processing
var canvas_layer: CanvasLayer
var post_process_rect: ColorRect

# Hacker overlay
var hacker_layer: CanvasLayer
var hacker_container: Control
var glitch_rects: Array[ColorRect] = []
var hacker_material: ShaderMaterial
var hex_lines: Array[Label] = []
var hex_buffer: String = ""
var hex_offset: float = 0.0
var hacker_enabled: bool = true

# 3D hex display
var hex_viewport: SubViewport
var hex_plane: MeshInstance3D
var hex_plane_material: StandardMaterial3D
var hex_scroll_offset: float = 0.0

var time: float = 0.0

func _ready() -> void:
	setup_audio()
	setup_materials()
	setup_background()
	setup_background_shapes()
	setup_abstract_visuals()
	setup_post_processing()
	setup_hacker_overlay()

	# Get camera reference
	orbit_camera = get_parent().get_node("Camera3D")

	setup_gui()

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

	bg_shape_material = ShaderMaterial.new()
	bg_shape_material.shader = preload("res://background_shape_shader.gdshader")

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

func setup_background_shapes() -> void:
	# Distant floating slabs
	for i in range(8):
		var slab = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(1.5, 4.0), randf_range(0.1, 0.3), randf_range(1.0, 3.0))
		slab.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i))
		slab.material_override = mat

		var angle = float(i) / 8.0 * TAU + randf() * 0.5
		var dist = randf_range(12.0, 20.0)
		var height = randf_range(-4.0, 4.0)
		slab.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		slab.rotation = Vector3(randf() * 0.3, randf() * TAU, randf() * 0.2)

		add_child(slab)
		bg_shapes.append(slab)

	# Tall pillars/monoliths
	for i in range(6):
		var pillar = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(0.3, 0.8), randf_range(3.0, 8.0), randf_range(0.3, 0.8))
		pillar.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 10))
		pillar.material_override = mat

		var angle = float(i) / 6.0 * TAU + 0.3
		var dist = randf_range(10.0, 16.0)
		pillar.position = Vector3(cos(angle) * dist, randf_range(-2.0, 2.0), sin(angle) * dist)
		pillar.rotation = Vector3(randf() * 0.15, randf() * TAU, randf() * 0.15)

		add_child(pillar)
		bg_shapes.append(pillar)

	# Floating debris/fragments
	for i in range(15):
		var debris = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(0.2, 0.8), randf_range(0.2, 0.8), randf_range(0.2, 0.8))
		debris.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 20))
		debris.material_override = mat

		var angle = randf() * TAU
		var dist = randf_range(8.0, 18.0)
		var height = randf_range(-5.0, 5.0)
		debris.position = Vector3(cos(angle) * dist, height, sin(angle) * dist)
		debris.rotation = Vector3(randf() * TAU, randf() * TAU, randf() * TAU)

		add_child(debris)
		bg_shapes.append(debris)

	# Large distant planes
	for i in range(4):
		var plane_shape = MeshInstance3D.new()
		var box = BoxMesh.new()
		box.size = Vector3(randf_range(5.0, 10.0), randf_range(0.05, 0.1), randf_range(5.0, 10.0))
		plane_shape.mesh = box
		var mat = bg_shape_material.duplicate() as ShaderMaterial
		mat.set_shader_parameter("shape_id", float(i + 40))
		plane_shape.material_override = mat

		var angle = float(i) / 4.0 * TAU + 0.7
		var dist = randf_range(18.0, 28.0)
		plane_shape.position = Vector3(cos(angle) * dist, randf_range(-6.0, 6.0), sin(angle) * dist)
		plane_shape.rotation = Vector3(randf() * 0.4 - 0.2, randf() * TAU, randf() * 0.4 - 0.2)

		add_child(plane_shape)
		bg_shapes.append(plane_shape)

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

func setup_hacker_overlay() -> void:
	hacker_layer = CanvasLayer.new()
	hacker_layer.layer = 15
	add_child(hacker_layer)

	hacker_container = Control.new()
	hacker_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size = get_viewport().get_visible_rect().size
	hacker_container.size = viewport_size
	hacker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_layer.add_child(hacker_container)

	print("Viewport size: ", viewport_size, " hacker_container size: ", hacker_container.size)

	# Scanline overlay shader
	var scanline_rect = ColorRect.new()
	scanline_rect.anchors_preset = Control.PRESET_FULL_RECT
	scanline_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

	hacker_material = ShaderMaterial.new()
	hacker_material.shader = Shader.new()
	hacker_material.shader.code = """
shader_type canvas_item;

uniform float time = 0.0;
uniform float glitch_intensity = 0.0;
uniform float scanline_alpha = 0.15;

void fragment() {
	vec2 uv = UV;

	// Scanlines
	float scanline = sin(uv.y * 800.0) * 0.5 + 0.5;
	scanline = pow(scanline, 1.5) * scanline_alpha;

	// Horizontal glitch displacement
	float glitch_line = step(0.99 - glitch_intensity * 0.1, fract(sin(floor(uv.y * 50.0 + time * 20.0) * 91.3458) * 47453.5453));
	float displacement = (fract(sin(time * 100.0 + uv.y * 50.0) * 43758.5453) - 0.5) * glitch_intensity * glitch_line * 0.1;

	// Noise
	float noise = fract(sin(dot(uv + time * 0.1, vec2(12.9898, 78.233))) * 43758.5453);
	noise = noise * 0.03 * glitch_intensity;

	// Vignette
	float vignette = 1.0 - length(uv - 0.5) * 0.5;

	// Flicker
	float flicker = 1.0 - fract(sin(time * 15.0) * 43758.5453) * 0.02 * glitch_intensity;

	// CRT curvature hint (subtle color at edges)
	float edge_glow = smoothstep(0.4, 0.5, abs(uv.x - 0.5)) + smoothstep(0.4, 0.5, abs(uv.y - 0.5));
	vec3 edge_color = vec3(0.0, 0.3, 0.1) * edge_glow * 0.3;

	COLOR = vec4(edge_color + vec3(0.0, noise, noise * 0.5), scanline + noise);
}
"""
	scanline_rect.material = hacker_material
	hacker_container.add_child(scanline_rect)

	var screen_size = viewport_size  # Use the already-captured viewport size

	# Font for hacker elements
	var hacker_font = SystemFont.new()
	hacker_font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])

	# Initialize hex buffer with lots of data
	for i in range(500):
		hex_buffer += "0123456789ABCDEF"[randi() % 16]

	# Create 3D hex display using SubViewport
	setup_3d_hex_display(hacker_font)

	print("Hacker overlay setup complete. hex_lines count: ", hex_lines.size())

	# Corner brackets / frame elements - top left
	var tl1 = Label.new()
	tl1.add_theme_font_override("font", hacker_font)
	tl1.add_theme_font_size_override("font_size", 12)
	tl1.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	tl1.text = "╔══════════════"
	tl1.position = Vector2(10, 10)
	tl1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(tl1)

	var tl2 = Label.new()
	tl2.add_theme_font_override("font", hacker_font)
	tl2.add_theme_font_size_override("font_size", 12)
	tl2.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	tl2.text = "║ VISUALIZER"
	tl2.position = Vector2(10, 28)
	tl2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(tl2)

	# Top right
	var tr1 = Label.new()
	tr1.add_theme_font_override("font", hacker_font)
	tr1.add_theme_font_size_override("font_size", 12)
	tr1.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	tr1.text = "══════════════╗"
	tr1.anchor_left = 1.0
	tr1.anchor_right = 1.0
	tr1.offset_left = -160
	tr1.offset_top = 10
	tr1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(tr1)

	var tr2 = Label.new()
	tr2.add_theme_font_override("font", hacker_font)
	tr2.add_theme_font_size_override("font_size", 12)
	tr2.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	tr2.text = "AUDIO_SYS ║"
	tr2.anchor_left = 1.0
	tr2.anchor_right = 1.0
	tr2.offset_left = -110
	tr2.offset_top = 28
	tr2.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(tr2)

	# Bottom left
	var bl1 = Label.new()
	bl1.add_theme_font_override("font", hacker_font)
	bl1.add_theme_font_size_override("font_size", 12)
	bl1.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	bl1.text = "╚══════════════"
	bl1.anchor_top = 1.0
	bl1.anchor_bottom = 1.0
	bl1.offset_left = 10
	bl1.offset_top = -100
	bl1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(bl1)

	# Bottom right
	var br1 = Label.new()
	br1.add_theme_font_override("font", hacker_font)
	br1.add_theme_font_size_override("font_size", 12)
	br1.add_theme_color_override("font_color", Color(0.0, 0.9, 0.3, 0.5))
	br1.text = "══════════════╝"
	br1.anchor_left = 1.0
	br1.anchor_right = 1.0
	br1.anchor_top = 1.0
	br1.anchor_bottom = 1.0
	br1.offset_left = -160
	br1.offset_top = -100
	br1.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_container.add_child(br1)

	# Glitch rectangles (randomly appearing)
	for i in range(5):
		var glitch_rect = ColorRect.new()
		glitch_rect.color = Color(0.0, 1.0, 0.3, 0.0)
		glitch_rect.size = Vector2(randi_range(100, 400), randi_range(2, 6))
		glitch_rect.position = Vector2(randf() * 1920, randf() * 1080)
		glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hacker_container.add_child(glitch_rect)
		glitch_rects.append(glitch_rect)

func setup_3d_hex_display(font: Font) -> void:
	# Create SubViewport to render hex text
	hex_viewport = SubViewport.new()
	hex_viewport.size = Vector2i(1024, 512)  # Taller viewport for more lines
	hex_viewport.transparent_bg = true
	hex_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(hex_viewport)

	# Container for hex text inside viewport - no border, transparent
	var hex_container = PanelContainer.new()
	hex_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.02, 0.0, 0.4)
	panel_style.set_border_width_all(0)  # No border
	panel_style.set_content_margin_all(8)
	hex_container.add_theme_stylebox_override("panel", panel_style)
	hex_viewport.add_child(hex_container)

	var hex_vbox = VBoxContainer.new()
	hex_vbox.add_theme_constant_override("separation", 0)
	hex_container.add_child(hex_vbox)

	# Create 18 lines of hex text
	for row in range(18):
		var hex_line = Label.new()
		hex_line.add_theme_font_override("font", font)
		hex_line.add_theme_font_size_override("font_size", 14)
		# Gradient of greens, brighter in middle
		var brightness = 1.0 - abs(row - 9) * 0.05
		var hex_color = Color(0.0, brightness, brightness * 0.4, brightness * 0.9)
		hex_line.add_theme_color_override("font_color", hex_color)
		hex_line.text = "%04X: " % (row * 0x100) + "██ INIT ██"
		hex_line.clip_text = true
		hex_vbox.add_child(hex_line)
		hex_lines.append(hex_line)

	# Create 3D plane to display the viewport texture
	hex_plane = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(5, 4)  # Narrower to fit text
	plane_mesh.orientation = PlaneMesh.FACE_Z
	hex_plane.mesh = plane_mesh

	# Material with viewport texture - more transparent
	hex_plane_material = StandardMaterial3D.new()
	hex_plane_material.albedo_texture = hex_viewport.get_texture()
	hex_plane_material.albedo_color = Color(1, 1, 1, 0.6)  # More transparent
	hex_plane_material.emission_enabled = true
	hex_plane_material.emission = Color(0.0, 0.4, 0.15)
	hex_plane_material.emission_energy_multiplier = 0.5
	hex_plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hex_plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hex_plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hex_plane.material_override = hex_plane_material

	# Position the plane in 3D space - in front and below the visualizer
	hex_plane.position = Vector3(0, -1.0, 3.0)
	hex_plane.rotation_degrees = Vector3(-15, 0, 0)  # Tilt towards camera
	add_child(hex_plane)

	print("3D hex display created at ", hex_plane.position)

func update_hacker_overlay(delta: float) -> void:
	if not hacker_enabled:
		hacker_container.visible = false
		return
	hacker_container.visible = true

	if hex_lines.size() == 0:
		print("WARNING: hex_lines is empty!")
		return

	# Update shader
	hacker_material.set_shader_parameter("time", time)
	hacker_material.set_shader_parameter("glitch_intensity", bass_energy)

	# Animate glitch rectangles
	for rect in glitch_rects:
		if randf() < 0.02 + bass_energy * 0.1:
			rect.color.a = randf() * 0.3 * bass_energy
			rect.position = Vector2(randf() * 1920, randf() * 1080)
			rect.size.x = randi_range(50, 300)
		else:
			rect.color.a *= 0.9

	# Update hex display - continuous scrolling stream
	var scroll_speed = 150.0 + bass_energy * 400.0 + mid_energy * 200.0
	hex_offset += delta * scroll_speed

	# Inject new random chars and shift buffer rapidly
	while hex_offset >= 1.0:
		hex_offset -= 1.0
		var char_set = "0123456789ABCDEF"
		if bass_energy > 0.4 and randf() < 0.4:
			char_set = "████▓▓▒▒░░"
		elif mid_energy > 0.3 and randf() < 0.3:
			char_set = "<!@#$%^&*>{}[]|\\/"
		elif high_energy > 0.3 and randf() < 0.2:
			char_set = "◀▶▲▼●○■□"
		hex_buffer = hex_buffer.substr(1) + char_set[randi() % char_set.length()]

	# Vertical scroll - speed varies with audio
	var vert_scroll_speed = 20.0 + bass_energy * 40.0 + mid_energy * 20.0
	hex_scroll_offset += delta * vert_scroll_speed

	# Build each line with scrolling vertical offset
	var num_lines = hex_lines.size()
	for row in range(num_lines):
		# Virtual row shifts with scroll offset for vertical scrolling effect
		var virtual_row = (row + int(hex_scroll_offset)) % 256
		var line_offset = int(hex_offset * 5 + virtual_row * 37) % hex_buffer.length()
		var display_len = 48  # Shorter lines to fit in viewport

		var line_str = ""

		# Address prefix - scrolls with virtual row
		var addr_val = (virtual_row * 0x100) % 0xFFFF
		line_str += "%04X: " % addr_val

		# Hex content
		for i in range(display_len):
			var idx = (line_offset + i) % hex_buffer.length()
			line_str += hex_buffer[idx]
			if i % 4 == 3:
				line_str += " "
			if i % 16 == 15:
				line_str += "│"

		# Rotating status suffixes based on virtual row
		var status_type = virtual_row % 8
		if status_type == 0:
			line_str += " ◀ ACTIVE ▶"
		elif status_type == 1:
			line_str += " B:%0.2f" % bass_energy
		elif status_type == 2:
			line_str += " M:%0.2f" % mid_energy
		elif status_type == 3:
			line_str += " H:%0.2f" % high_energy
		elif status_type == 4:
			line_str += " PKT:%05d" % (virtual_row * 127 % 99999)
		elif status_type == 5:
			line_str += " ░ SCAN ░"
		elif status_type == 6:
			line_str += " MEM:%04X" % ((virtual_row * 0x137) % 0xFFFF)
		elif status_type == 7:
			line_str += " ▓ SYNC ▓"

		hex_lines[row].text = line_str

		# Glitch individual lines on bass hits
		if bass_energy > 0.6 and randf() < 0.06:
			var glitch_chars = "█▓▒░╔╗╚╝║═◄►"
			var glitch_line = ""
			for i in range(120):
				glitch_line += glitch_chars[randi() % glitch_chars.length()]
			hex_lines[row].text = glitch_line
			hex_lines[row].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		else:
			# Fade color back to gradient based on row position
			var brightness = 1.0 - abs(row - num_lines / 2.0) * (0.08 / (num_lines / 12.0))
			var target_color = Color(0.0, brightness, brightness * 0.4, brightness * 0.85)
			var current = hex_lines[row].get_theme_color("font_color")
			hex_lines[row].add_theme_color_override("font_color", current.lerp(target_color, delta * 6.0))

	# Animate 3D hex plane with more dynamic movement
	if hex_plane:
		# Floating motion - multiple sine waves for organic feel
		hex_plane.position.x = sin(time * 0.4) * 0.4 + cos(time * 0.7) * 0.2 + mid_energy * 0.3
		hex_plane.position.y = -1.0 + sin(time * 0.5) * 0.2 + cos(time * 0.3) * 0.15 + bass_energy * 0.3
		hex_plane.position.z = 3.0 + sin(time * 0.6) * 0.3 + high_energy * 0.2

		# More dramatic tilting based on audio
		hex_plane.rotation_degrees.x = -15 + sin(time * 0.35) * 6 + mid_energy * 10
		hex_plane.rotation_degrees.y = sin(time * 0.25) * 5 + cos(time * 0.45) * 4
		hex_plane.rotation_degrees.z = sin(time * 0.55) * 4 + bass_energy * 8

		# Emission glow pulses with bass
		if hex_plane_material:
			hex_plane_material.emission_energy_multiplier = 0.3 + bass_energy * 2.5 + high_energy * 0.8
			# Vary transparency slightly with audio
			var alpha = 0.45 + bass_energy * 0.25
			hex_plane_material.albedo_color = Color(1, 1, 1, alpha)

func setup_gui() -> void:
	gui_layer = CanvasLayer.new()
	gui_layer.layer = 20
	add_child(gui_layer)

	gui_panel = PanelContainer.new()
	gui_panel.position = Vector2(20, 20)
	gui_panel.visible = false
	gui_layer.add_child(gui_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.12, 0.9)
	style.border_color = Color(0.3, 0.3, 0.35)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(15)
	gui_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	gui_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "VISUALIZER SETTINGS"
	title.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	vbox.add_child(title)

	# Audio input selector
	var audio_hbox = HBoxContainer.new()
	audio_hbox.add_theme_constant_override("separation", 10)

	var audio_label = Label.new()
	audio_label.text = "Audio In"
	audio_label.custom_minimum_size.x = 80
	audio_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	audio_hbox.add_child(audio_label)

	audio_input_dropdown = OptionButton.new()
	audio_input_dropdown.custom_minimum_size.x = 200
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.2, 0.2, 0.22)
	dropdown_style.set_corner_radius_all(3)
	dropdown_style.set_content_margin_all(5)
	audio_input_dropdown.add_theme_stylebox_override("normal", dropdown_style)
	audio_input_dropdown.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	# Populate with available input devices
	var input_devices = AudioServer.get_input_device_list()
	var current_device = AudioServer.input_device
	var current_idx = 0
	for i in range(input_devices.size()):
		audio_input_dropdown.add_item(input_devices[i], i)
		if input_devices[i] == current_device:
			current_idx = i
	audio_input_dropdown.selected = current_idx

	audio_input_dropdown.item_selected.connect(func(idx):
		var devices = AudioServer.get_input_device_list()
		if idx < devices.size():
			AudioServer.input_device = devices[idx]
	)

	audio_hbox.add_child(audio_input_dropdown)
	vbox.add_child(audio_hbox)

	# Separator
	var sep0 = HSeparator.new()
	vbox.add_child(sep0)

	# Smoothing slider
	vbox.add_child(create_slider("smoothing", "Smoothing", smoothing, 0.01, 1.0, func(val): smoothing = val))

	# Intensity slider
	vbox.add_child(create_slider("intensity", "Intensity", intensity, 0.1, 5.0, func(val): intensity = val))

	# Separator
	var sep1 = HSeparator.new()
	vbox.add_child(sep1)

	# FFT Ranges label
	var fft_label = Label.new()
	fft_label.text = "FFT RANGES (Hz)"
	fft_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(fft_label)

	# Bass range
	vbox.add_child(create_slider("bass_min", "Bass Min", bass_min, 20.0, 200.0, func(val): bass_min = val))
	vbox.add_child(create_slider("bass_max", "Bass Max", bass_max, 100.0, 500.0, func(val): bass_max = val))

	# Mid range
	vbox.add_child(create_slider("mid_min", "Mid Min", mid_min, 100.0, 1000.0, func(val): mid_min = val))
	vbox.add_child(create_slider("mid_max", "Mid Max", mid_max, 1000.0, 8000.0, func(val): mid_max = val))

	# High range
	vbox.add_child(create_slider("high_min", "High Min", high_min, 2000.0, 8000.0, func(val): high_min = val))
	vbox.add_child(create_slider("high_max", "High Max", high_max, 8000.0, 20000.0, func(val): high_max = val))

	# Separator
	var sep2 = HSeparator.new()
	vbox.add_child(sep2)

	# Camera label
	var cam_label = Label.new()
	cam_label.text = "CAMERA"
	cam_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(cam_label)

	# Camera controls
	if orbit_camera:
		vbox.add_child(create_slider("cam_speed", "Speed", orbit_camera.orbit_speed, 0.0, 1.0, func(val): orbit_camera.orbit_speed = val))
		vbox.add_child(create_slider("cam_radius", "Distance", orbit_camera.orbit_radius, 3.0, 15.0, func(val): orbit_camera.orbit_radius = val))
		vbox.add_child(create_slider("cam_height", "Height", orbit_camera.orbit_height, 0.0, 8.0, func(val): orbit_camera.orbit_height = val))

	# Separator
	var sep3 = HSeparator.new()
	vbox.add_child(sep3)

	# Overlay label
	var overlay_label = Label.new()
	overlay_label.text = "OVERLAY"
	overlay_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(overlay_label)

	# Hacker overlay toggle
	var hacker_hbox = HBoxContainer.new()
	hacker_hbox.add_theme_constant_override("separation", 10)

	var hacker_label = Label.new()
	hacker_label.text = "Hacker FX"
	hacker_label.custom_minimum_size.x = 80
	hacker_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hacker_hbox.add_child(hacker_label)

	var hacker_check = CheckBox.new()
	hacker_check.button_pressed = hacker_enabled
	hacker_check.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	hacker_check.toggled.connect(func(toggled): hacker_enabled = toggled)
	hacker_hbox.add_child(hacker_check)

	vbox.add_child(hacker_hbox)

	# Separator
	var sep4 = HSeparator.new()
	vbox.add_child(sep4)

	# Reset button
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(reset_to_defaults)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.25, 0.28)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(8)
	reset_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.35, 0.35, 0.38)
	btn_hover.set_corner_radius_all(3)
	btn_hover.set_content_margin_all(8)
	reset_btn.add_theme_stylebox_override("hover", btn_hover)
	reset_btn.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	vbox.add_child(reset_btn)

	# Instructions
	var hint = Label.new()
	hint.text = "[Space] to toggle"
	hint.add_theme_color_override("font_color", Color(0.5, 0.5, 0.5))
	vbox.add_child(hint)

func create_slider(key: String, label_text: String, initial_value: float, min_val: float, max_val: float, callback: Callable) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hbox.add_child(label)

	var slider = HSlider.new()
	slider.min_value = min_val
	slider.max_value = max_val
	slider.value = initial_value
	slider.step = 0.01 if max_val <= 5.0 else 1.0
	slider.custom_minimum_size.x = 150
	hbox.add_child(slider)

	var value_label = Label.new()
	value_label.text = "%.2f" % initial_value if max_val <= 5.0 else "%.0f" % initial_value
	value_label.custom_minimum_size.x = 50
	value_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val):
		callback.call(val)
		value_label.text = "%.2f" % val if max_val <= 5.0 else "%.0f" % val
	)

	# Store reference for reset
	gui_sliders[key] = {"slider": slider, "label": value_label, "max": max_val}

	return hbox

func reset_to_defaults() -> void:
	smoothing = DEFAULT_SMOOTHING
	intensity = DEFAULT_INTENSITY
	bass_min = DEFAULT_BASS_MIN
	bass_max = DEFAULT_BASS_MAX
	mid_min = DEFAULT_MID_MIN
	mid_max = DEFAULT_MID_MAX
	high_min = DEFAULT_HIGH_MIN
	high_max = DEFAULT_HIGH_MAX

	# Reset camera
	if orbit_camera:
		orbit_camera.orbit_speed = DEFAULT_CAM_SPEED
		orbit_camera.orbit_radius = DEFAULT_CAM_RADIUS
		orbit_camera.orbit_height = DEFAULT_CAM_HEIGHT

	# Update sliders
	var defaults = {
		"smoothing": DEFAULT_SMOOTHING,
		"intensity": DEFAULT_INTENSITY,
		"bass_min": DEFAULT_BASS_MIN,
		"bass_max": DEFAULT_BASS_MAX,
		"mid_min": DEFAULT_MID_MIN,
		"mid_max": DEFAULT_MID_MAX,
		"high_min": DEFAULT_HIGH_MIN,
		"high_max": DEFAULT_HIGH_MAX,
		"cam_speed": DEFAULT_CAM_SPEED,
		"cam_radius": DEFAULT_CAM_RADIUS,
		"cam_height": DEFAULT_CAM_HEIGHT
	}

	for key in gui_sliders:
		var data = gui_sliders[key]
		if defaults.has(key):
			var val = defaults[key]
			data["slider"].value = val
			data["label"].text = "%.2f" % val if data["max"] <= 5.0 else "%.0f" % val

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		gui_visible = !gui_visible
		gui_panel.visible = gui_visible

func _process(delta: float) -> void:
	time += delta
	analyze_spectrum()
	update_abstract_visuals(delta)
	update_hacker_overlay(delta)
	update_shader_params()

func analyze_spectrum() -> void:
	if not spectrum_analyzer:
		return

	var bass_raw = get_frequency_range_energy(bass_min, bass_max)
	var mid_raw = get_frequency_range_energy(mid_min, mid_max)
	var high_raw = get_frequency_range_energy(high_min, high_max)

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

		# Each crystal has unique motion patterns
		var id = float(i)
		var phase = id * 0.7 + time

		# Wandering motion - always active, not just on bass
		var wander_x = sin(phase * 0.3 + id * 1.1) * 0.4 + cos(phase * 0.2 + id * 0.7) * 0.3
		var wander_y = sin(phase * 0.25 + id * 0.9) * 0.5 + cos(phase * 0.35 + id * 1.3) * 0.3
		var wander_z = cos(phase * 0.28 + id * 0.8) * 0.4 + sin(phase * 0.22 + id * 1.2) * 0.3

		# Slow orbit around center
		var golden_angle = PI * (3.0 - sqrt(5.0))
		var base_theta = golden_angle * i
		var orbit_speed = 0.15 + sin(id * 0.5) * 0.05  # Varying orbit speeds
		var theta = base_theta + time * orbit_speed

		# Base radius varies over time too
		var base_radius = 2.0 + sqrt(id) * 0.5
		var radius_wobble = sin(phase * 0.4) * 0.3
		var radius = base_radius + radius_wobble + bass_energy * 0.5

		# Height oscillates independently
		var base_height = sin(id * 0.5 + time * 0.2) * 1.2 + cos(id * 0.3 + time * 0.15) * 0.8

		crystal.position = Vector3(
			cos(theta) * radius + wander_x,
			base_height + wander_y + bass_energy * 0.3,
			sin(theta) * radius + wander_z
		)

		# Tumbling rotation - continuous
		crystal.rotation.x += delta * (0.4 + sin(id) * 0.2 + bass_energy * 1.5)
		crystal.rotation.y += delta * (0.3 + cos(id * 0.7) * 0.15 + bass_energy * 1.0)
		crystal.rotation.z += delta * (0.2 + sin(id * 1.3) * 0.1)

		# Scale pulse
		var scale_base = 0.5 + bass_energy * 0.6
		var scale_pulse = sin(time * 3.0 + i * 0.5) * 0.08
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

	# Animate background shapes (slow, subtle)
	for i in range(bg_shapes.size()):
		var shape = bg_shapes[i]
		var mat = shape.material_override as ShaderMaterial

		# Very slow rotation
		shape.rotation.x += delta * 0.02 * (1.0 + sin(float(i)) * 0.5)
		shape.rotation.y += delta * 0.03 * (1.0 + cos(float(i) * 0.7) * 0.5)

		# Subtle drift
		var drift = sin(time * 0.1 + float(i) * 0.3) * 0.1
		shape.position.y += drift * delta

		mat.set_shader_parameter("energy", total_energy)
		mat.set_shader_parameter("time", time)

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
