class_name MidiController
extends Node

## MIDI Controller for the visualizer
## Handles MIDI input from external devices for clock sync, note triggers, and CC modulation
## Uses RtMidi GDExtension for high-precision timing when available,
## falls back to Godot's built-in MIDI otherwise

signal beat(beat_number: int)
signal note_triggered(note: int, velocity: float)
signal cc_changed(control: int, value: float)
signal clock_tick()
signal transport_start()
signal transport_stop()

# Clock timing
const TICKS_PER_BEAT = 24
var clock_count: int = 0
var beat_count: int = 0
var is_playing: bool = false

# BPM calculation
var last_tick_time: float = 0.0
var tick_interval: float = 0.0
var tick_times: Array[float] = []
const TICK_AVERAGE_COUNT = 24  # Average over one beat for stable BPM

@export var midi_port: int = -1  # -1 = no port selected
@export var auto_connect: bool = false

# RtMidi extension (if available)
var midi_in = null
var using_rtmidi: bool = false

# Godot built-in MIDI fallback
var using_godot_midi: bool = false


func _ready() -> void:
	_try_init_rtmidi()

	if not using_rtmidi:
		_init_godot_midi()


func _try_init_rtmidi() -> void:
	# Try to use RtMidi GDExtension if available
	if ClassDB.class_exists("GodotRtMidiIn"):
		midi_in = ClassDB.instantiate("GodotRtMidiIn")
		if midi_in:
			using_rtmidi = true
			print("MidiController: Using RtMidi GDExtension")

			if auto_connect and midi_in.get_port_count() > 0:
				if midi_port >= 0:
					open_port(midi_port)
				else:
					# Auto-connect to first port
					open_port(0)
	else:
		print("MidiController: RtMidi GDExtension not available")


func _init_godot_midi() -> void:
	# Fall back to Godot's built-in MIDI
	OS.open_midi_inputs()
	using_godot_midi = true
	print("MidiController: Using Godot built-in MIDI")


func _process(_delta: float) -> void:
	if using_rtmidi and midi_in and midi_in.is_port_open():
		_poll_rtmidi_messages()
	# Godot MIDI is handled via _input()


func _poll_rtmidi_messages() -> void:
	while midi_in.has_message():
		var msg: Dictionary = midi_in.poll_message()
		if msg.is_empty():
			break
		_handle_midi_message(msg.status, msg.data1, msg.data2, msg.timestamp)


func _input(event: InputEvent) -> void:
	if not using_godot_midi:
		return

	if event is InputEventMIDI:
		var midi_event := event as InputEventMIDI
		var status := (midi_event.message << 4) | midi_event.channel
		_handle_midi_message(status, midi_event.pitch, midi_event.velocity,
			Time.get_ticks_msec() / 1000.0)


func _handle_midi_message(status: int, data1: int, data2: int, timestamp: float) -> void:
	var command := status >> 4
	var channel := status & 0x0F

	match command:
		0x9:  # Note On
			if data2 > 0:
				note_triggered.emit(data1, data2 / 127.0)
			else:
				# Note On with velocity 0 = Note Off
				note_triggered.emit(data1, 0.0)
		0x8:  # Note Off
			note_triggered.emit(data1, 0.0)
		0xB:  # Control Change
			cc_changed.emit(data1, data2 / 127.0)
		0xF:  # System messages
			match status:
				0xF8:  # Clock
					_handle_clock(timestamp)
				0xFA:  # Start
					is_playing = true
					clock_count = 0
					beat_count = 0
					tick_times.clear()
					transport_start.emit()
				0xFC:  # Stop
					is_playing = false
					transport_stop.emit()
				0xFB:  # Continue
					is_playing = true
					transport_start.emit()


func _handle_clock(timestamp: float) -> void:
	clock_tick.emit()

	if not is_playing:
		return

	# Calculate tick interval for BPM
	if last_tick_time > 0:
		var interval := timestamp - last_tick_time
		tick_times.append(interval)
		if tick_times.size() > TICK_AVERAGE_COUNT:
			tick_times.pop_front()

		# Average the tick intervals for stable BPM reading
		var sum := 0.0
		for t in tick_times:
			sum += t
		tick_interval = sum / tick_times.size()

	last_tick_time = timestamp

	clock_count += 1
	if clock_count >= TICKS_PER_BEAT:
		clock_count = 0
		beat_count += 1
		beat.emit(beat_count)


## Get the current BPM calculated from MIDI clock
func get_bpm() -> float:
	if tick_interval <= 0:
		return 0.0
	return 60.0 / (tick_interval * TICKS_PER_BEAT)


## Get the current beat position (beat + fractional position within beat)
func get_beat_position() -> float:
	return beat_count + (clock_count / float(TICKS_PER_BEAT))


## Get available MIDI input ports
func get_available_ports() -> PackedStringArray:
	if using_rtmidi and midi_in:
		return midi_in.get_port_names()
	elif using_godot_midi:
		return OS.get_connected_midi_inputs()
	return PackedStringArray()


## Get the number of available MIDI ports
func get_port_count() -> int:
	if using_rtmidi and midi_in:
		return midi_in.get_port_count()
	elif using_godot_midi:
		return OS.get_connected_midi_inputs().size()
	return 0


## Open a specific MIDI port by index
func open_port(port: int) -> Error:
	midi_port = port

	if using_rtmidi and midi_in:
		var result = midi_in.open_port(port)
		if result == OK:
			var ports = midi_in.get_port_names()
			if port < ports.size():
				print("MidiController: Opened port '", ports[port], "'")
		return result
	elif using_godot_midi:
		# Godot MIDI doesn't require explicit port opening
		# It receives from all connected devices
		var ports := OS.get_connected_midi_inputs()
		if port < ports.size():
			print("MidiController: Using Godot MIDI with port '", ports[port], "'")
		return OK

	return ERR_UNCONFIGURED


## Close the current MIDI port
func close_port() -> void:
	if using_rtmidi and midi_in:
		midi_in.close_port()

	midi_port = -1
	is_playing = false
	clock_count = 0
	beat_count = 0
	tick_times.clear()


## Check if a MIDI port is currently open
func is_port_open() -> bool:
	if using_rtmidi and midi_in:
		return midi_in.is_port_open()
	elif using_godot_midi:
		return OS.get_connected_midi_inputs().size() > 0
	return false


## Refresh the list of available MIDI devices
func refresh_devices() -> void:
	if using_godot_midi:
		OS.close_midi_inputs()
		OS.open_midi_inputs()
