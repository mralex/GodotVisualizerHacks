class_name VisualizerGUI
extends Node

## Settings panel GUI for the visualizer

var gui_layer: CanvasLayer
var gui_panel: PanelContainer
var gui_visible: bool = false
var gui_sliders: Dictionary = {}
var audio_input_dropdown: OptionButton
var midi_port_dropdown: OptionButton
var midi_bpm_label: Label
var midi_activity_indicator: ColorRect

var audio_analyzer: AudioAnalyzer
var orbit_camera: Node
var hacker_overlay: HackerOverlay
var midi_controller: MidiController

# Defaults for camera
const DEFAULT_CAM_SPEED: float = 0.3
const DEFAULT_CAM_RADIUS: float = 6.0
const DEFAULT_CAM_HEIGHT: float = 3.0

func setup(parent: Node, p_audio_analyzer: AudioAnalyzer, p_orbit_camera: Node, p_hacker_overlay: HackerOverlay, p_midi_controller: MidiController = null) -> void:
	audio_analyzer = p_audio_analyzer
	orbit_camera = p_orbit_camera
	hacker_overlay = p_hacker_overlay
	midi_controller = p_midi_controller

	gui_layer = CanvasLayer.new()
	gui_layer.layer = 20
	parent.add_child(gui_layer)

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
	setup_audio_input(vbox)

	# MIDI section
	if midi_controller:
		vbox.add_child(HSeparator.new())
		setup_midi_section(vbox)

	# Separator
	vbox.add_child(HSeparator.new())

	# Audio sliders
	vbox.add_child(create_slider("smoothing", "Smoothing", audio_analyzer.smoothing, 0.01, 1.0, func(val): audio_analyzer.smoothing = val))
	vbox.add_child(create_slider("intensity", "Intensity", audio_analyzer.intensity, 0.1, 5.0, func(val): audio_analyzer.intensity = val))
	vbox.add_child(create_slider("loudness_mod", "Loudness Mod", audio_analyzer.loudness_modulation, 0.0, 2.0, func(val): audio_analyzer.loudness_modulation = val))

	vbox.add_child(HSeparator.new())

	# FFT Ranges
	var fft_label = Label.new()
	fft_label.text = "FFT RANGES (Hz)"
	fft_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(fft_label)

	vbox.add_child(create_slider("bass_min", "Bass Min", audio_analyzer.bass_min, 20.0, 200.0, func(val): audio_analyzer.bass_min = val))
	vbox.add_child(create_slider("bass_max", "Bass Max", audio_analyzer.bass_max, 100.0, 500.0, func(val): audio_analyzer.bass_max = val))
	vbox.add_child(create_slider("mid_min", "Mid Min", audio_analyzer.mid_min, 100.0, 1000.0, func(val): audio_analyzer.mid_min = val))
	vbox.add_child(create_slider("mid_max", "Mid Max", audio_analyzer.mid_max, 1000.0, 8000.0, func(val): audio_analyzer.mid_max = val))
	vbox.add_child(create_slider("high_min", "High Min", audio_analyzer.high_min, 2000.0, 8000.0, func(val): audio_analyzer.high_min = val))
	vbox.add_child(create_slider("high_max", "High Max", audio_analyzer.high_max, 8000.0, 20000.0, func(val): audio_analyzer.high_max = val))

	vbox.add_child(HSeparator.new())

	# Camera
	var cam_label = Label.new()
	cam_label.text = "CAMERA"
	cam_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(cam_label)

	if orbit_camera:
		vbox.add_child(create_slider("cam_speed", "Speed", orbit_camera.orbit_speed, 0.0, 1.0, func(val): orbit_camera.orbit_speed = val))
		vbox.add_child(create_slider("cam_radius", "Distance", orbit_camera.orbit_radius, 3.0, 15.0, func(val): orbit_camera.orbit_radius = val))
		vbox.add_child(create_slider("cam_height", "Height", orbit_camera.orbit_height, 0.0, 8.0, func(val): orbit_camera.orbit_height = val))

	vbox.add_child(HSeparator.new())

	# Overlay
	var overlay_label = Label.new()
	overlay_label.text = "OVERLAY"
	overlay_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(overlay_label)

	var hacker_hbox = HBoxContainer.new()
	hacker_hbox.add_theme_constant_override("separation", 10)

	var hacker_label = Label.new()
	hacker_label.text = "Hacker FX"
	hacker_label.custom_minimum_size.x = 80
	hacker_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	hacker_hbox.add_child(hacker_label)

	var hacker_check = CheckBox.new()
	hacker_check.button_pressed = hacker_overlay.enabled
	hacker_check.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	hacker_check.toggled.connect(func(toggled): hacker_overlay.enabled = toggled)
	hacker_hbox.add_child(hacker_check)

	vbox.add_child(hacker_hbox)

	vbox.add_child(HSeparator.new())

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

func setup_audio_input(vbox: VBoxContainer) -> void:
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


func setup_midi_section(vbox: VBoxContainer) -> void:
	var midi_label = Label.new()
	midi_label.text = "MIDI INPUT"
	midi_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	vbox.add_child(midi_label)

	# MIDI port selector
	var midi_hbox = HBoxContainer.new()
	midi_hbox.add_theme_constant_override("separation", 10)

	var port_label = Label.new()
	port_label.text = "MIDI Port"
	port_label.custom_minimum_size.x = 80
	port_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	midi_hbox.add_child(port_label)

	midi_port_dropdown = OptionButton.new()
	midi_port_dropdown.custom_minimum_size.x = 200
	var dropdown_style = StyleBoxFlat.new()
	dropdown_style.bg_color = Color(0.2, 0.2, 0.22)
	dropdown_style.set_corner_radius_all(3)
	dropdown_style.set_content_margin_all(5)
	midi_port_dropdown.add_theme_stylebox_override("normal", dropdown_style)
	midi_port_dropdown.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))

	_refresh_midi_ports()

	midi_port_dropdown.item_selected.connect(_on_midi_port_selected)
	midi_hbox.add_child(midi_port_dropdown)

	# Refresh button
	var refresh_btn = Button.new()
	refresh_btn.text = "↻"
	refresh_btn.tooltip_text = "Refresh MIDI ports"
	refresh_btn.pressed.connect(_refresh_midi_ports)
	var btn_style = StyleBoxFlat.new()
	btn_style.bg_color = Color(0.25, 0.25, 0.28)
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
	bpm_prefix.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_hbox.add_child(bpm_prefix)

	midi_bpm_label = Label.new()
	midi_bpm_label.text = "---"
	midi_bpm_label.custom_minimum_size.x = 60
	midi_bpm_label.add_theme_color_override("font_color", Color(0.9, 0.5, 0.2))
	status_hbox.add_child(midi_bpm_label)

	var activity_label = Label.new()
	activity_label.text = "Activity:"
	activity_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
	status_hbox.add_child(activity_label)

	midi_activity_indicator = ColorRect.new()
	midi_activity_indicator.custom_minimum_size = Vector2(12, 12)
	midi_activity_indicator.color = Color(0.3, 0.3, 0.3)
	status_hbox.add_child(midi_activity_indicator)

	vbox.add_child(status_hbox)

	# Connect to MIDI signals for activity indication
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

	# Select current port if one is open
	if midi_controller.midi_port >= 0:
		midi_port_dropdown.selected = midi_controller.midi_port + 1  # +1 for "(None)" entry


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
	# Update MIDI activity indicator
	if midi_activity_indicator:
		_activity_fade = maxf(0.0, _activity_fade - delta * 5.0)
		midi_activity_indicator.color = Color(0.2 + _activity_fade * 0.6, 0.8 * _activity_fade, 0.2, 1.0)

	# Update BPM display
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

	gui_sliders[key] = {"slider": slider, "label": value_label, "max": max_val}

	return hbox

func reset_to_defaults() -> void:
	audio_analyzer.reset_to_defaults()

	if orbit_camera:
		orbit_camera.orbit_speed = DEFAULT_CAM_SPEED
		orbit_camera.orbit_radius = DEFAULT_CAM_RADIUS
		orbit_camera.orbit_height = DEFAULT_CAM_HEIGHT

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

func toggle_visibility() -> void:
	gui_visible = !gui_visible
	gui_panel.visible = gui_visible
