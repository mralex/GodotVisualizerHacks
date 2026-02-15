extends Node3D

## Audio-responsive 3D visualizer - Main orchestrator

var audio_analyzer: AudioAnalyzer
var visualizer_effects: VisualizerEffects
var hacker_overlay: HackerOverlay
var hex_display: HexDisplay3D
var visualizer_gui: VisualizerGUI
var midi_controller: MidiController

var orbit_camera: Node
var time: float = 0.0

# MIDI CC mappings (CC number -> parameter)
var cc_intensity: int = 1      # Mod wheel
var cc_smoothing: int = 74     # Filter cutoff
var cc_loudness: int = 71      # Resonance

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

	# Setup MIDI controller
	midi_controller = MidiController.new()
	add_child(midi_controller)
	midi_controller.beat.connect(_on_midi_beat)
	midi_controller.note_triggered.connect(_on_midi_note)
	midi_controller.cc_changed.connect(_on_midi_cc)
	midi_controller.transport_start.connect(_on_midi_transport_start)
	midi_controller.transport_stop.connect(_on_midi_transport_stop)

	# Setup GUI last (needs references to other components)
	visualizer_gui = VisualizerGUI.new()
	add_child(visualizer_gui)
	visualizer_gui.setup(self, audio_analyzer, orbit_camera, hacker_overlay, midi_controller)

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


## MIDI signal handlers

func _on_midi_beat(beat_number: int) -> void:
	# Trigger beat pulse on all visuals
	visualizer_effects.trigger_beat_pulse()


func _on_midi_note(note: int, velocity: float) -> void:
	# Map MIDI notes to visual triggers by octave
	var octave := note / 12
	var note_in_octave := note % 12

	if velocity > 0:
		if octave < 3:
			# Low notes trigger bass visuals
			visualizer_effects.trigger_bass(velocity)
		elif octave < 5:
			# Mid notes trigger mid visuals
			visualizer_effects.trigger_mid(velocity)
		else:
			# High notes trigger high visuals
			visualizer_effects.trigger_high(velocity)


func _on_midi_cc(control: int, value: float) -> void:
	# Map CCs to visualizer parameters
	if control == cc_intensity:
		audio_analyzer.intensity = remap(value, 0.0, 1.0, 0.5, 3.0)
	elif control == cc_smoothing:
		audio_analyzer.smoothing = remap(value, 0.0, 1.0, 0.01, 0.5)
	elif control == cc_loudness:
		audio_analyzer.loudness_modulation = remap(value, 0.0, 1.0, 0.0, 2.0)


func _on_midi_transport_start() -> void:
	# Could be used to reset visuals or sync animations
	pass


func _on_midi_transport_stop() -> void:
	# Could be used to freeze or fade visuals
	pass
