extends Node3D

## Audio-responsive 3D visualizer - Main orchestrator

var audio_analyzer: AudioAnalyzer
var visualizer_effects: VisualizerEffects
var hacker_overlay: HackerOverlay
var hex_display: HexDisplay3D
var visualizer_gui: VisualizerGUI

var orbit_camera: Node
var time: float = 0.0

func _ready() -> void:
	# Create components
	audio_analyzer = AudioAnalyzer.new()
	add_child(audio_analyzer)

	visualizer_effects = VisualizerEffects.new()
	add_child(visualizer_effects)
	visualizer_effects.setup(self)

	hacker_overlay = HackerOverlay.new()
	add_child(hacker_overlay)
	hacker_overlay.setup(self)

	hex_display = HexDisplay3D.new()
	add_child(hex_display)
	hex_display.setup(self)

	# Get camera reference
	orbit_camera = get_parent().get_node("Camera3D")

	# Setup GUI last (needs references to other components)
	visualizer_gui = VisualizerGUI.new()
	add_child(visualizer_gui)
	visualizer_gui.setup(self, audio_analyzer, orbit_camera, hacker_overlay)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		visualizer_gui.toggle_visibility()

func _process(delta: float) -> void:
	time += delta

	# Analyze audio
	audio_analyzer.analyze()

	var bass = audio_analyzer.bass_energy
	var mid = audio_analyzer.mid_energy
	var high = audio_analyzer.high_energy
	var total = audio_analyzer.total_energy

	# Update all components
	visualizer_effects.update(delta, time, bass, mid, high, total)
	visualizer_effects.update_shader_params(time, bass, mid, high)

	hacker_overlay.update(time, bass)

	hex_display.update(delta, time, bass, mid, high)
