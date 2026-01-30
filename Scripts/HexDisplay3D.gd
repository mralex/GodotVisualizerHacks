class_name HexDisplay3D
extends Node

## 3D floating hex display panel rendered via SubViewport

var hex_viewport: SubViewport
var hex_plane: MeshInstance3D
var hex_plane_material: StandardMaterial3D
var hex_lines: Array[Label] = []
var hex_buffer: String = ""
var hex_offset: float = 0.0
var hex_scroll_offset: float = 0.0

func setup(parent: Node) -> void:
	# Initialize hex buffer
	for i in range(500):
		hex_buffer += "0123456789ABCDEF"[randi() % 16]

	var font = SystemFont.new()
	font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])

	# Create SubViewport
	hex_viewport = SubViewport.new()
	hex_viewport.size = Vector2i(1024, 512)
	hex_viewport.transparent_bg = true
	hex_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(hex_viewport)

	# Container for hex text
	var hex_container = PanelContainer.new()
	hex_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var panel_style = StyleBoxFlat.new()
	panel_style.bg_color = Color(0.0, 0.02, 0.0, 0.4)
	panel_style.set_border_width_all(0)
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
		var brightness = 1.0 - abs(row - 9) * 0.05
		var hex_color = Color(0.0, brightness, brightness * 0.4, brightness * 0.9)
		hex_line.add_theme_color_override("font_color", hex_color)
		hex_line.text = "%04X: " % (row * 0x100) + "██ INIT ██"
		hex_line.clip_text = true
		hex_vbox.add_child(hex_line)
		hex_lines.append(hex_line)

	# Create 3D plane
	hex_plane = MeshInstance3D.new()
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = Vector2(5, 4)
	plane_mesh.orientation = PlaneMesh.FACE_Z
	hex_plane.mesh = plane_mesh

	# Material with viewport texture
	hex_plane_material = StandardMaterial3D.new()
	hex_plane_material.albedo_texture = hex_viewport.get_texture()
	hex_plane_material.albedo_color = Color(1, 1, 1, 0.6)
	hex_plane_material.emission_enabled = true
	hex_plane_material.emission = Color(0.0, 0.4, 0.15)
	hex_plane_material.emission_energy_multiplier = 0.5
	hex_plane_material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	hex_plane_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	hex_plane_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	hex_plane.material_override = hex_plane_material

	hex_plane.position = Vector3(0, -1.0, 3.0)
	hex_plane.rotation_degrees = Vector3(-15, 0, 0)
	parent.add_child(hex_plane)

func update(delta: float, time: float, bass_energy: float, mid_energy: float, high_energy: float) -> void:
	if hex_lines.size() == 0:
		return

	# Horizontal scroll
	var scroll_speed = 150.0 + bass_energy * 400.0 + mid_energy * 200.0
	hex_offset += delta * scroll_speed

	# Inject new random chars
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

	# Vertical scroll
	var vert_scroll_speed = 20.0 + bass_energy * 40.0 + mid_energy * 20.0
	hex_scroll_offset += delta * vert_scroll_speed

	# Build each line
	var num_lines = hex_lines.size()
	for row in range(num_lines):
		var virtual_row = (row + int(hex_scroll_offset)) % 256
		var line_offset = int(hex_offset * 5 + virtual_row * 37) % hex_buffer.length()
		var display_len = 48

		var line_str = ""
		var addr_val = (virtual_row * 0x100) % 0xFFFF
		line_str += "%04X: " % addr_val

		for i in range(display_len):
			var idx = (line_offset + i) % hex_buffer.length()
			line_str += hex_buffer[idx]
			if i % 4 == 3:
				line_str += " "
			if i % 16 == 15:
				line_str += "│"

		# Status suffixes
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

		# Glitch on bass hits
		if bass_energy > 0.6 and randf() < 0.06:
			var glitch_chars = "█▓▒░╔╗╚╝║═◄►"
			var glitch_line = ""
			for i in range(120):
				glitch_line += glitch_chars[randi() % glitch_chars.length()]
			hex_lines[row].text = glitch_line
			hex_lines[row].add_theme_color_override("font_color", Color(1.0, 1.0, 1.0, 0.9))
		else:
			var brightness = 1.0 - abs(row - num_lines / 2.0) * (0.08 / (num_lines / 12.0))
			var target_color = Color(0.0, brightness, brightness * 0.4, brightness * 0.85)
			var current = hex_lines[row].get_theme_color("font_color")
			hex_lines[row].add_theme_color_override("font_color", current.lerp(target_color, delta * 6.0))

	# Animate 3D plane
	if hex_plane:
		hex_plane.position.x = sin(time * 0.4) * 0.4 + cos(time * 0.7) * 0.2 + mid_energy * 0.3
		hex_plane.position.y = -1.0 + sin(time * 0.5) * 0.2 + cos(time * 0.3) * 0.15 + bass_energy * 0.3
		hex_plane.position.z = 3.0 + sin(time * 0.6) * 0.3 + high_energy * 0.2

		hex_plane.rotation_degrees.x = -15 + sin(time * 0.35) * 6 + mid_energy * 10
		hex_plane.rotation_degrees.y = sin(time * 0.25) * 5 + cos(time * 0.45) * 4
		hex_plane.rotation_degrees.z = sin(time * 0.55) * 4 + bass_energy * 8

		if hex_plane_material:
			hex_plane_material.emission_energy_multiplier = 0.3 + bass_energy * 2.5 + high_energy * 0.8
			var alpha = 0.45 + bass_energy * 0.25
			hex_plane_material.albedo_color = Color(1, 1, 1, alpha)
