#ifndef GODOT_RTMIDI_IN_H
#define GODOT_RTMIDI_IN_H

#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>
#include <godot_cpp/variant/packed_byte_array.hpp>
#include <godot_cpp/variant/dictionary.hpp>
#include <RtMidi.h>
#include <mutex>
#include <queue>

namespace godot {

class GodotRtMidiIn : public RefCounted {
    GDCLASS(GodotRtMidiIn, RefCounted)

private:
    ::RtMidiIn *midi_in = nullptr;
    std::mutex queue_mutex;

    struct MidiMessage {
        unsigned char status;
        unsigned char data1;
        unsigned char data2;
        double timestamp;
    };

    std::queue<MidiMessage> message_queue;
    bool port_open = false;

    static void midi_callback(double timestamp, std::vector<unsigned char>* message, void* userData);

protected:
    static void _bind_methods();

public:
    GodotRtMidiIn();
    ~GodotRtMidiIn();

    // Device management
    PackedStringArray get_port_names();
    int get_port_count();
    Error open_port(int port_number);
    Error open_virtual_port(const String &name);
    void close_port();
    bool is_port_open() const;

    // Configure message filtering
    void ignore_types(bool sysex, bool timing, bool active_sense);

    // Message polling (call from _process)
    bool has_message();
    Dictionary poll_message();
};

}

#endif // GODOT_RTMIDI_IN_H
