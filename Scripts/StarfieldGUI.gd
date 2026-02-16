class_name StarfieldGUI
extends Node

## Settings panel GUI for the starfield visualizer

var gui_layer: CanvasLayer
var gui_panel: PanelContainer
var gui_visible: bool = false
var gui_sliders: Dictionary = {}
var audio_input_dropdown: OptionButton
var midi_port_dropdown: OptionButton
var midi_bpm_label: Label
var midi_activity_indicator: ColorRect

var audio_analyzer: AudioAnalyzer
var flight_camera: Node
var starfield_effects: StarfieldEffects
var midi_controller: MidiController

# Defaults for flight camera
const DEFAULT_BASE_SPEED: float = 0.5
const DEFAULT_MAX_SPEED: float = 4.0
const DEFAULT_SWAY: float = 0.3
const DEFAULT_ROLL: float = 0.02

# Defaults for warp
const DEFAULT_WARP_THRESHOLD: float = 0.7
const DEFAULT_WARP_DECAY: float = 4.0

# Defaults for stars
const DEFAULT_STAR_SIZE: float = 1.0
const DEFAULT_TRAIL_STRENGTH: float = 0.6

func setup(parent: Node, p_audio_analyzer: AudioAnalyzer, p_flight_camera: Node, p_starfield_effects: StarfieldEffects, p_midi_controller: MidiController = null) -> void:
	audio_analyzer = p_audio_analyzer
	flight_camera = p_flight_camera
	starfield_effects = p_starfield_effects
	midi_controller = p_midi_controller

	gui_layer = CanvasLayer.new()
	gui_layer.layer = 20
	parent.add_child(gui_layer)

	gui_panel = PanelContainer.new()
	gui_panel.position = Vector2(20, 20)
	gui_panel.visible = false
	gui_layer.add_child(gui_panel)

	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.1, 0.9)
	style.border_color = Color(0.2, 0.25, 0.4)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(15)
	gui_panel.add_theme_stylebox_override("panel", style)

	var vbox = VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	gui_panel.add_child(vbox)

	# Title
	var title = Label.new()
	title.text = "STARFIELD SETTINGS"
	title.add_theme_color_override("font_color", Color(0.7, 0.8, 1.0))
	vbox.add_child(title)

	# Audio input selector
	_setup_audio_input(vbox)

	# MIDI section
	if midi_controller:
		vbox.add_child(HSeparator.new())
		_setup_midi_section(vbox)

	vbox.add_child(HSeparator.new())

	# Audio analysis sliders
	vbox.add_child(create_slider("smoothing", "Smoothing", audio_analyzer.smoothing, 0.01, 1.0, func(val): audio_analyzer.smoothing = val))
	vbox.add_child(create_slider("intensity", "Intensity", audio_analyzer.intensity, 0.1, 5.0, func(val): audio_analyzer.intensity = val))
	vbox.add_child(create_slider("loudness_mod", "Loudness Mod", audio_analyzer.loudness_modulation, 0.0, 2.0, func(val): audio_analyzer.loudness_modulation = val))

	vbox.add_child(HSeparator.new())

	# Flight camera
	var flight_label = Label.new()
	flight_label.text = "FLIGHT"
	flight_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(flight_label)

	vbox.add_child(create_slider("base_speed", "Base Speed", flight_camera.base_speed, 0.0, 5.0, func(val): flight_camera.base_speed = val))
	vbox.add_child(create_slider("max_speed", "Max Speed", flight_camera.max_speed, 1.0, 5.0, func(val): flight_camera.max_speed = val))
	vbox.add_child(create_slider("sway", "Sway", flight_camera.sway_amount, 0.0, 1.0, func(val): flight_camera.sway_amount = val))
	vbox.add_child(create_slider("roll", "Roll", flight_camera.roll_amount, 0.0, 0.1, func(val): flight_camera.roll_amount = val))

	vbox.add_child(HSeparator.new())

	# Warp
	var warp_label = Label.new()
	warp_label.text = "WARP"
	warp_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(warp_label)

	vbox.add_child(create_slider("warp_threshold", "Bass Thresh", starfield_effects.warp_bass_threshold, 0.1, 1.0, func(val): starfield_effects.warp_bass_threshold = val))
	vbox.add_child(create_slider("warp_decay", "Decay Rate", starfield_effects.warp_decay_rate, 1.0, 10.0, func(val): starfield_effects.warp_decay_rate = val))

	vbox.add_child(HSeparator.new())

	# Stars
	var stars_label = Label.new()
	stars_label.text = "STARS"
	stars_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(stars_label)

	vbox.add_child(create_slider("star_size", "Size", starfield_effects.star_size_multiplier, 0.1, 5.0, func(val): starfield_effects.star_size_multiplier = val))
	vbox.add_child(create_slider("trail_strength", "Trails", starfield_effects.trail_strength, 0.0, 1.0, func(val): starfield_effects.trail_strength = val))

	vbox.add_child(HSeparator.new())

	# FFT Ranges
	var fft_label = Label.new()
	fft_label.text = "FFT RANGES (Hz)"
	fft_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(fft_label)

	vbox.add_child(create_slider("bass_min", "Bass Min", audio_analyzer.bass_min, 20.0, 200.0, func(val): audio_analyzer.bass_min = val))
	vbox.add_child(create_slider("bass_max", "Bass Max", audio_analyzer.bass_max, 100.0, 500.0, func(val): audio_analyzer.bass_max = val))
	vbox.add_child(create_slider("mid_min", "Mid Min", audio_analyzer.mid_min, 100.0, 1000.0, func(val): audio_analyzer.mid_min = val))
	vbox.add_child(create_slider("mid_max", "Mid Max", audio_analyzer.mid_max, 1000.0, 8000.0, func(val): audio_analyzer.mid_max = val))
	vbox.add_child(create_slider("high_min", "High Min", audio_analyzer.high_min, 2000.0, 8000.0, func(val): audio_analyzer.high_min = val))
	vbox.add_child(create_slider("high_max", "High Max", audio_analyzer.high_max, 8000.0, 20000.0, func(val): audio_analyzer.high_max = val))

	vbox.add_child(HSeparator.new())

	# Reset button
	var reset_btn = Button.new()
	reset_btn.text = "Reset to Defaults"
	reset_btn.pressed.connect(reset_to_defaults)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.25)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(8)
	reset_btn.add_theme_stylebox_override("normal", btn_style)
	var btn_hover = StyleBoxFlat.new()
	btn_hover.bg_color = Color(0.25, 0.25, 0.38)
	btn_hover.set_corner_radius_all(3)
	btn_hover.set_content_margin_all(8)
	reset_btn.add_theme_stylebox_override("hover", btn_hover)
	reset_btn.add_theme_color_override("font_color", Color(0.5, 0.6, 1.0))
	vbox.add_child(reset_btn)

	# Instructions
	var hint = Label.new()
	hint.text = "[Space] to toggle"
	hint.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	vbox.add_child(hint)


func _setup_audio_input(vbox: VBoxContainer) -> void:
	var audio_hbox = HBoxContainer.new()
	audio_hbox.add_theme_constant_override("separation", 10)

	var audio_label = Label.new()
	audio_label.text = "Audio In"
	audio_label.custom_minimum_size.x = 80
	audio_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	audio_hbox.add_child(audio_label)

	audio_input_dropdown = OptionButton.new()
	audio_input_dropdown.custom_minimum_size.x = 200
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.12, 0.12, 0.18)
	dropdown_style.set_corner_radius_all(3)
	dropdown_style.set_content_margin_all(5)
	audio_input_dropdown.add_theme_stylebox_override("normal", dropdown_style)
	audio_input_dropdown.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

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


func _setup_midi_section(vbox: VBoxContainer) -> void:
	var midi_label = Label.new()
	midi_label.text = "MIDI INPUT"
	midi_label.add_theme_color_override("font_color", Color(0.6, 0.7, 0.9))
	vbox.add_child(midi_label)

	var midi_hbox = HBoxContainer.new()
	midi_hbox.add_theme_constant_override("separation", 10)

	var port_label = Label.new()
	port_label.text = "MIDI Port"
	port_label.custom_minimum_size.x = 80
	port_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	midi_hbox.add_child(port_label)

	midi_port_dropdown = OptionButton.new()
	midi_port_dropdown.custom_minimum_size.x = 200
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.12, 0.12, 0.18)
	dropdown_style.set_corner_radius_all(3)
	dropdown_style.set_content_margin_all(5)
	midi_port_dropdown.add_theme_stylebox_override("normal", dropdown_style)
	midi_port_dropdown.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	_refresh_midi_ports()

	midi_port_dropdown.item_selected.connect(_on_midi_port_selected)
	midi_hbox.add_child(midi_port_dropdown)

	var refresh_btn = Button.new()
	refresh_btn.text = "↻"
	refresh_btn.tooltip_text = "Refresh MIDI ports"
	refresh_btn.pressed.connect(_refresh_midi_ports)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.15, 0.15, 0.25)
	btn_style.set_corner_radius_all(3)
	btn_style.set_content_margin_all(4)
	refresh_btn.add_theme_stylebox_override("normal", btn_style)
	midi_hbox.add_child(refresh_btn)

	vbox.add_child(midi_hbox)

	# BPM and activity display
	var status_hbox = HBoxContainer.new()
	status_hbox.add_theme_constant_override("separation", 10)

	var bpm_prefix = Label.new()
	bpm_prefix.text = "BPM:"
	bpm_prefix.custom_minimum_size.x = 80
	bpm_prefix.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	status_hbox.add_child(bpm_prefix)

	midi_bpm_label = Label.new()
	midi_bpm_label.text = "---"
	midi_bpm_label.custom_minimum_size.x = 60
	midi_bpm_label.add_theme_color_override("font_color", Color(0.5, 0.6, 1.0))
	status_hbox.add_child(midi_bpm_label)

	var activity_label = Label.new()
	activity_label.text = "Activity:"
	activity_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
	status_hbox.add_child(activity_label)

	midi_activity_indicator = ColorRect.new()
	midi_activity_indicator.custom_minimum_size = Vector2(12, 12)
	midi_activity_indicator.color = Color(0.2, 0.2, 0.3)
	status_hbox.add_child(midi_activity_indicator)

	vbox.add_child(status_hbox)

	if midi_controller:
		midi_controller.clock_tick.connect(_on_midi_activity)
		midi_controller.note_triggered.connect(func(_n, _v): _on_midi_activity())
		midi_controller.cc_changed.connect(func(_c, _v): _on_midi_activity())


func _refresh_midi_ports() -> void:
	if not midi_port_dropdown or not midi_controller:
		return

	midi_port_dropdown.clear()
	midi_port_dropdown.add_item("(None)", -1)

	var ports := midi_controller.get_available_ports()
	for i in range(ports.size()):
		midi_port_dropdown.add_item(ports[i], i)

	if midi_controller.midi_port >= 0:
		midi_port_dropdown.selected = midi_controller.midi_port + 1


func _on_midi_port_selected(idx: int) -> void:
	if not midi_controller:
		return

	var port_id := midi_port_dropdown.get_item_id(idx)
	if port_id < 0:
		midi_controller.close_port()
		midi_bpm_label.text = "---"
	else:
		midi_controller.open_port(port_id)


var _activity_fade: float = 0.0

func _on_midi_activity() -> void:
	_activity_fade = 1.0


func _process(delta: float) -> void:
	if midi_activity_indicator:
		_activity_fade = maxf(0.0, _activity_fade - delta * 5.0)
		midi_activity_indicator.color = Color(0.1 + _activity_fade * 0.3, 0.2 + _activity_fade * 0.5, 0.8 * _activity_fade, 1.0)

	if midi_bpm_label and midi_controller and midi_controller.is_port_open():
		var bpm := midi_controller.get_bpm()
		if bpm > 0:
			midi_bpm_label.text = "%.1f" % bpm
		else:
			midi_bpm_label.text = "---"


func create_slider(key: String, label_text: String, initial_value: float, min_val: float, max_val: float, callback: Callable) -> HBoxContainer:
	var hbox = HBoxContainer.new()
	hbox.add_theme_constant_override("separation", 10)

	var label = Label.new()
	label.text = label_text
	label.custom_minimum_size.x = 80
	label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.7))
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
	value_label.add_theme_color_override("font_color", Color(0.5, 0.6, 1.0))
	hbox.add_child(value_label)

	slider.value_changed.connect(func(val):
		callback.call(val)
		value_label.text = "%.2f" % val if max_val <= 5.0 else "%.0f" % val
	)

	gui_sliders[key] = {"slider": slider, "label": value_label, "max": max_val}

	return hbox


func reset_to_defaults() -> void:
	audio_analyzer.reset_to_defaults()

	if flight_camera:
		flight_camera.base_speed = DEFAULT_BASE_SPEED
		flight_camera.max_speed = DEFAULT_MAX_SPEED
		flight_camera.sway_amount = DEFAULT_SWAY
		flight_camera.roll_amount = DEFAULT_ROLL

	if starfield_effects:
		starfield_effects.warp_bass_threshold = DEFAULT_WARP_THRESHOLD
		starfield_effects.warp_decay_rate = DEFAULT_WARP_DECAY
		starfield_effects.star_size_multiplier = DEFAULT_STAR_SIZE
		starfield_effects.trail_strength = DEFAULT_TRAIL_STRENGTH

	var defaults = {
		"smoothing": AudioAnalyzer.DEFAULT_SMOOTHING,
		"intensity": AudioAnalyzer.DEFAULT_INTENSITY,
		"loudness_mod": AudioAnalyzer.DEFAULT_LOUDNESS_MODULATION,
		"bass_min": AudioAnalyzer.DEFAULT_BASS_MIN,
		"bass_max": AudioAnalyzer.DEFAULT_BASS_MAX,
		"mid_min": AudioAnalyzer.DEFAULT_MID_MIN,
		"mid_max": AudioAnalyzer.DEFAULT_MID_MAX,
		"high_min": AudioAnalyzer.DEFAULT_HIGH_MIN,
		"high_max": AudioAnalyzer.DEFAULT_HIGH_MAX,
		"base_speed": DEFAULT_BASE_SPEED,
		"max_speed": DEFAULT_MAX_SPEED,
		"sway": DEFAULT_SWAY,
		"roll": DEFAULT_ROLL,
		"warp_threshold": DEFAULT_WARP_THRESHOLD,
		"warp_decay": DEFAULT_WARP_DECAY,
		"star_size": DEFAULT_STAR_SIZE,
		"trail_strength": DEFAULT_TRAIL_STRENGTH,
	}

	for key in gui_sliders:
		var data = gui_sliders[key]
		if defaults.has(key):
			var val = defaults[key]
			data["slider"].value = val
			data["label"].text = "%.2f" % val if data["max"] <= 5.0 else "%.0f" % val


func toggle_visibility() -> void:
	gui_visible = !gui_visible
	gui_panel.visible = gui_visible
