class_name AudioAnalyzer
extends Node

## Handles audio input and FFT spectrum analysis

signal energy_updated(bass: float, mid: float, high: float, total: float)

var spectrum_analyzer: AudioEffectSpectrumAnalyzerInstance
var audio_player: AudioStreamPlayer

# Frequency band data (smoothed)
var bass_energy: float = 0.0
var mid_energy: float = 0.0
var high_energy: float = 0.0
var total_energy: float = 0.0
var loudness: float = 0.0

@export var smoothing: float = 0.2
@export var intensity: float = 1.5
@export var loudness_modulation: float = 0.0  # How much loudness affects intensity

# FFT frequency ranges (Hz)
var bass_min: float = 20.0
var bass_max: float = 250.0
var mid_min: float = 250.0
var mid_max: float = 4000.0
var high_min: float = 4000.0
var high_max: float = 16000.0

# Defaults
const DEFAULT_SMOOTHING: float = 0.2
const DEFAULT_INTENSITY: float = 1.5
const DEFAULT_LOUDNESS_MODULATION: float = 0.0
const DEFAULT_BASS_MIN: float = 20.0
const DEFAULT_BASS_MAX: float = 250.0
const DEFAULT_MID_MIN: float = 250.0
const DEFAULT_MID_MAX: float = 4000.0
const DEFAULT_HIGH_MIN: float = 4000.0
const DEFAULT_HIGH_MAX: float = 16000.0

func _ready() -> void:
	setup_audio()

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
		analyzer.fft_size = AudioEffectSpectrumAnalyzer.FFT_SIZE_256
		AudioServer.add_bus_effect(bus_idx, analyzer)
		effect_idx = AudioServer.get_bus_effect_count(bus_idx) - 1

	spectrum_analyzer = AudioServer.get_bus_effect_instance(bus_idx, effect_idx)

	audio_player = AudioStreamPlayer.new()
	audio_player.stream = AudioStreamMicrophone.new()
	audio_player.bus = "Record"
	add_child(audio_player)
	audio_player.play()

func analyze() -> void:
	if not spectrum_analyzer:
		return

	var bass_raw = get_frequency_range_energy(bass_min, bass_max)
	var mid_raw = get_frequency_range_energy(mid_min, mid_max)
	var high_raw = get_frequency_range_energy(high_min, high_max)

	# Simple loudness: RMS of raw energies
	var raw_loudness = sqrt((bass_raw * bass_raw + mid_raw * mid_raw + high_raw * high_raw) / 3.0)
	loudness = lerp(loudness, raw_loudness, smoothing)

	# Apply loudness modulation to intensity (additive on top of base)
	var effective_intensity = intensity + loudness * loudness_modulation

	bass_energy = lerp(bass_energy, bass_raw * effective_intensity, smoothing)
	mid_energy = lerp(mid_energy, mid_raw * effective_intensity, smoothing)
	high_energy = lerp(high_energy, high_raw * effective_intensity, smoothing)
	total_energy = (bass_energy + mid_energy + high_energy) / 3.0

	energy_updated.emit(bass_energy, mid_energy, high_energy, total_energy)

func get_frequency_range_energy(from_hz: float, to_hz: float) -> float:
	var magnitude = spectrum_analyzer.get_magnitude_for_frequency_range(from_hz, to_hz)
	var energy = (magnitude.x + magnitude.y) / 2.0
	return clamp(energy * 60.0, 0.0, 1.0)

func reset_to_defaults() -> void:
	smoothing = DEFAULT_SMOOTHING
	intensity = DEFAULT_INTENSITY
	loudness_modulation = DEFAULT_LOUDNESS_MODULATION
	bass_min = DEFAULT_BASS_MIN
	bass_max = DEFAULT_BASS_MAX
	mid_min = DEFAULT_MID_MIN
	mid_max = DEFAULT_MID_MAX
	high_min = DEFAULT_HIGH_MIN
	high_max = DEFAULT_HIGH_MAX
