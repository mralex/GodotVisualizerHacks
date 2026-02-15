# RtMidi GDExtension for Godot

High-precision MIDI input extension for the Godot Visualizer, providing:
- MIDI clock sync (24 PPQ timing)
- Note-triggered visuals
- CC modulation of parameters

## Building

### Prerequisites

1. **godot-cpp** - Clone and build godot-cpp matching your Godot version:
   ```bash
   git clone --recursive https://github.com/godotengine/godot-cpp.git
   cd godot-cpp
   scons platform=<platform> target=template_debug
   scons platform=<platform> target=template_release
   ```

2. **SCons** - Python-based build system:
   ```bash
   pip install scons
   ```

3. **Platform SDK**:
   - macOS: Xcode Command Line Tools
   - Linux: GCC and ALSA dev libraries (`sudo apt install libasound2-dev`)
   - Windows: Visual Studio with C++ tools

### Build Commands

Set the path to godot-cpp:
```bash
export GODOT_CPP_PATH=/path/to/godot-cpp
```

#### macOS
```bash
cd addons/rtmidi
scons platform=macos target=template_debug
scons platform=macos target=template_release
```

#### Linux
```bash
cd addons/rtmidi
scons platform=linux target=template_debug
scons platform=linux target=template_release
```

#### Windows
```bash
cd addons/rtmidi
scons platform=windows target=template_debug
scons platform=windows target=template_release
```

## Usage

The extension provides a `GodotRtMidiIn` class with the following API:

```gdscript
var midi_in = GodotRtMidiIn.new()

# List available ports
var ports = midi_in.get_port_names()
print("Available MIDI ports: ", ports)

# Open a port
midi_in.open_port(0)

# Poll for messages (call in _process)
while midi_in.has_message():
    var msg = midi_in.poll_message()
    print("MIDI: status=%d data1=%d data2=%d" % [msg.status, msg.data1, msg.data2])

# Close port
midi_in.close_port()
```

## Fallback

If the GDExtension is not built/available, the `MidiController.gd` script will automatically fall back to Godot's built-in MIDI support (`OS.open_midi_inputs()`).

## Files

```
addons/rtmidi/
├── SConstruct                 # Build script
├── rtmidi.gdextension         # Extension definition
├── README.md                  # This file
├── src/
│   ├── register_types.cpp     # Extension registration
│   ├── register_types.h
│   ├── rtmidi_in.cpp          # GodotRtMidiIn wrapper
│   └── rtmidi_in.h
├── lib/rtmidi/
│   ├── RtMidi.h               # RtMidi library
│   └── RtMidi.cpp
└── bin/                       # Compiled libraries (after build)
```

## License

RtMidi is distributed under the MIT License.
See https://github.com/thestk/rtmidi for details.
