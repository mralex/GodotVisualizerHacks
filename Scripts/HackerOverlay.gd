class_name HackerOverlay
extends Node

## 2D hacker-style overlay with scanlines and glitch effects

var hacker_layer: CanvasLayer
var hacker_container: Control
var glitch_rects: Array[ColorRect] = []
var hacker_material: ShaderMaterial
var enabled: bool = true

func setup(parent: Node) -> void:
	hacker_layer = CanvasLayer.new()
	hacker_layer.layer = 15
	parent.add_child(hacker_layer)

	hacker_container = Control.new()
	hacker_container.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var viewport_size = parent.get_viewport().get_visible_rect().size
	hacker_container.size = viewport_size
	hacker_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hacker_layer.add_child(hacker_container)

	setup_scanlines()
	setup_corner_brackets()
	setup_glitch_rects()

func setup_scanlines() -> void:
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

func setup_corner_brackets() -> void:
	var hacker_font = SystemFont.new()
	hacker_font.font_names = PackedStringArray(["Courier New", "Consolas", "monospace"])

	# Top left
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

func setup_glitch_rects() -> void:
	for i in range(5):
		var glitch_rect = ColorRect.new()
		glitch_rect.color = Color(0.0, 1.0, 0.3, 0.0)
		glitch_rect.size = Vector2(randi_range(100, 400), randi_range(2, 6))
		glitch_rect.position = Vector2(randf() * 1920, randf() * 1080)
		glitch_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hacker_container.add_child(glitch_rect)
		glitch_rects.append(glitch_rect)

func update(time: float, bass_energy: float) -> void:
	if not enabled:
		hacker_container.visible = false
		return
	hacker_container.visible = true

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
