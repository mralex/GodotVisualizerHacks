extends Node3D

## Starfield fly-through visualizer - Scene orchestrator

var audio_analyzer: AudioAnalyzer
var starfield_effects: StarfieldEffects
var midi_controller: MidiController
var starfield_gui: StarfieldGUI
var flight_camera: Node

var time: float = 0.0

# MIDI CC mappings (same as main visualizer)
var cc_intensity: int = 1      # Mod wheel
var cc_smoothing: int = 74     # Filter cutoff
var cc_loudness: int = 71      # Resonance

func _ready() -> void:
	# Create audio analyzer
	audio_analyzer = AudioAnalyzer.new()
	add_child(audio_analyzer)

	# Create starfield effects
	starfield_effects = StarfieldEffects.new()
	add_child(starfield_effects)
	starfield_effects.setup(self)

	# Get camera reference
	flight_camera = get_parent().get_node("Camera3D")

	# Setup MIDI controller
	midi_controller = MidiController.new()
	add_child(midi_controller)
	midi_controller.beat.connect(_on_midi_beat)
	midi_controller.note_triggered.connect(_on_midi_note)
	midi_controller.cc_changed.connect(_on_midi_cc)

	# Setup GUI last (needs references to other components)
	starfield_gui = StarfieldGUI.new()
	add_child(starfield_gui)
	starfield_gui.setup(self, audio_analyzer, flight_camera, starfield_effects, midi_controller)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		starfield_gui.toggle_visibility()

func _process(delta: float) -> void:
	time += delta

	# Analyze audio
	audio_analyzer.analyze()

	var bass = audio_analyzer.bass_energy
	var mid = audio_analyzer.mid_energy
	var high = audio_analyzer.high_energy
	var total = audio_analyzer.total_energy

	# Set camera flight speed from bass
	flight_camera.set_target_speed(bass)

	# Update starfield with all energy values + current speed
	var speed = flight_camera.current_speed
	starfield_effects.update(delta, time, bass, mid, high, total, speed)


## MIDI signal handlers

func _on_midi_beat(_beat_number: int) -> void:
	starfield_effects.trigger_beat_pulse()

func _on_midi_note(note: int, velocity: float) -> void:
	var octave := note / 12
	if velocity > 0:
		if octave < 3:
			# Low notes trigger bass/warp
			starfield_effects.trigger_bass(velocity)

func _on_midi_cc(control: int, value: float) -> void:
	if control == cc_intensity:
		audio_analyzer.intensity = remap(value, 0.0, 1.0, 0.5, 3.0)
	elif control == cc_smoothing:
		audio_analyzer.smoothing = remap(value, 0.0, 1.0, 0.01, 0.5)
	elif control == cc_loudness:
		audio_analyzer.loudness_modulation = remap(value, 0.0, 1.0, 0.0, 2.0)
