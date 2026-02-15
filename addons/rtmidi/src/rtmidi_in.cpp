#include "rtmidi_in.h"
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

using namespace godot;

void GodotRtMidiIn::_bind_methods() {
    // Device management
    ClassDB::bind_method(D_METHOD("get_port_names"), &GodotRtMidiIn::get_port_names);
    ClassDB::bind_method(D_METHOD("get_port_count"), &GodotRtMidiIn::get_port_count);
    ClassDB::bind_method(D_METHOD("open_port", "port_number"), &GodotRtMidiIn::open_port);
    ClassDB::bind_method(D_METHOD("open_virtual_port", "name"), &GodotRtMidiIn::open_virtual_port);
    ClassDB::bind_method(D_METHOD("close_port"), &GodotRtMidiIn::close_port);
    ClassDB::bind_method(D_METHOD("is_port_open"), &GodotRtMidiIn::is_port_open);

    // Message filtering
    ClassDB::bind_method(D_METHOD("ignore_types", "sysex", "timing", "active_sense"), &GodotRtMidiIn::ignore_types);

    // Message polling
    ClassDB::bind_method(D_METHOD("has_message"), &GodotRtMidiIn::has_message);
    ClassDB::bind_method(D_METHOD("poll_message"), &GodotRtMidiIn::poll_message);
}

void GodotRtMidiIn::midi_callback(double timestamp, std::vector<unsigned char>* message, void* userData) {
    GodotRtMidiIn* self = static_cast<GodotRtMidiIn*>(userData);
    if (!self || message->empty()) return;

    MidiMessage msg;
    msg.timestamp = timestamp;
    msg.status = (*message)[0];
    msg.data1 = message->size() > 1 ? (*message)[1] : 0;
    msg.data2 = message->size() > 2 ? (*message)[2] : 0;

    std::lock_guard<std::mutex> lock(self->queue_mutex);
    self->message_queue.push(msg);
}

GodotRtMidiIn::GodotRtMidiIn() {
    midi_in = new RtMidiIn(RtMidi::UNSPECIFIED, "Godot Visualizer");
    if (midi_in) {
        // Don't ignore timing messages (needed for MIDI clock)
        midi_in->ignoreTypes(true, false, true);
        midi_in->setCallback(&GodotRtMidiIn::midi_callback, this);
    }
}

GodotRtMidiIn::~GodotRtMidiIn() {
    if (midi_in) {
        close_port();
        delete midi_in;
        midi_in = nullptr;
    }
}

PackedStringArray GodotRtMidiIn::get_port_names() {
    PackedStringArray names;
    if (!midi_in) return names;

    unsigned int count = midi_in->getPortCount();
    for (unsigned int i = 0; i < count; i++) {
        names.push_back(String(midi_in->getPortName(i).c_str()));
    }

    return names;
}

int GodotRtMidiIn::get_port_count() {
    if (!midi_in) return 0;
    return midi_in->getPortCount();
}

Error GodotRtMidiIn::open_port(int port_number) {
    if (!midi_in) return ERR_UNCONFIGURED;

    if (port_open) {
        midi_in->closePort();
    }

    // Validate port number
    if (port_number < 0 || (unsigned int)port_number >= midi_in->getPortCount()) {
        UtilityFunctions::printerr("RtMidi Error: Invalid port number");
        port_open = false;
        return ERR_CANT_OPEN;
    }

    midi_in->openPort(port_number, "Godot MIDI In");
    port_open = midi_in->isPortOpen();

    if (!port_open) {
        UtilityFunctions::printerr("RtMidi Error: Failed to open port");
        return ERR_CANT_OPEN;
    }

    return OK;
}

Error GodotRtMidiIn::open_virtual_port(const String &name) {
    if (!midi_in) return ERR_UNCONFIGURED;

    if (port_open) {
        midi_in->closePort();
    }

    midi_in->openVirtualPort(name.utf8().get_data());
    port_open = midi_in->isPortOpen();

    if (!port_open) {
        UtilityFunctions::printerr("RtMidi Error: Failed to open virtual port");
        return ERR_CANT_OPEN;
    }

    return OK;
}

void GodotRtMidiIn::close_port() {
    if (!midi_in) return;

    midi_in->closePort();
    port_open = false;

    // Clear message queue
    std::lock_guard<std::mutex> lock(queue_mutex);
    while (!message_queue.empty()) {
        message_queue.pop();
    }
}

bool GodotRtMidiIn::is_port_open() const {
    return port_open && midi_in != nullptr;
}

void GodotRtMidiIn::ignore_types(bool sysex, bool timing, bool active_sense) {
    if (!midi_in) return;
    midi_in->ignoreTypes(sysex, timing, active_sense);
}

bool GodotRtMidiIn::has_message() {
    std::lock_guard<std::mutex> lock(queue_mutex);
    return !message_queue.empty();
}

Dictionary GodotRtMidiIn::poll_message() {
    Dictionary result;

    std::lock_guard<std::mutex> lock(queue_mutex);
    if (message_queue.empty()) {
        return result;
    }

    MidiMessage msg = message_queue.front();
    message_queue.pop();

    result["status"] = msg.status;
    result["data1"] = msg.data1;
    result["data2"] = msg.data2;
    result["timestamp"] = msg.timestamp;

    return result;
}
