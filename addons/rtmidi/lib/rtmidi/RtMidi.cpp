/**********************************************************************/
/*! \class RtMidi
    \brief An abstract base class for realtime MIDI input/output.

    This class implements some common functionality for the realtime
    MIDI input/output subclasses RtMidiIn and RtMidiOut.

    RtMidi GitHub site: https://github.com/thestk/rtmidi
    RtMidi WWW site: http://www.music.mcgill.ca/~gary/rtmidi/

    RtMidi: realtime MIDI i/o C++ classes
    Copyright (c) 2003-2023 Gary P. Scavone

    Permission is hereby granted, free of charge, to any person
    obtaining a copy of this software and associated documentation files
    (the "Software"), to deal in the Software without restriction,
    including without limitation the rights to use, copy, modify, merge,
    publish, distribute, sublicense, and/or sell copies of the Software,
    and to permit persons to whom the Software is furnished to do so,
    subject to the following conditions:

    The above copyright notice and this permission notice shall be
    included in all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
    EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
    MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
    IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR
    ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF
    CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION
    WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
*/
/**********************************************************************/

#include "RtMidi.h"
#include <sstream>
#include <cstring>

#if defined(__MACOSX_CORE__)
  #include <CoreMIDI/CoreMIDI.h>
  #include <CoreAudio/HostTime.h>
  #include <CoreServices/CoreServices.h>
#endif

#if defined(__LINUX_ALSA__)
  #include <alsa/asoundlib.h>
#endif

#if defined(__WINDOWS_MM__)
  #include <windows.h>
  #include <mmsystem.h>
#endif

// **************************************************************** //
//
// MidiApi class definitions.
//
// **************************************************************** //

class MidiApi
{
public:
  MidiApi();
  virtual ~MidiApi();

  virtual RtMidi::Api getCurrentApi() = 0;
  virtual void openPort(unsigned int portNumber, const std::string &portName) = 0;
  virtual void openVirtualPort(const std::string &portName) = 0;
  virtual void closePort() = 0;
  virtual void setClientName(const std::string &clientName) = 0;
  virtual void setPortName(const std::string &portName) = 0;
  virtual unsigned int getPortCount() = 0;
  virtual std::string getPortName(unsigned int portNumber) = 0;

  bool isPortOpen() const { return connected_; }
  void setErrorCallback(RtMidiErrorCallback errorCallback, void *userData);

  void error(RtMidiError::Type type, std::string errorString);

protected:
  bool connected_;
  std::string errorString_;
  RtMidiErrorCallback errorCallback_;
  void *errorCallbackUserData_;
};

MidiApi::MidiApi()
  : connected_(false), errorCallback_(nullptr), errorCallbackUserData_(nullptr)
{
}

MidiApi::~MidiApi()
{
}

void MidiApi::setErrorCallback(RtMidiErrorCallback errorCallback, void *userData)
{
  errorCallback_ = errorCallback;
  errorCallbackUserData_ = userData;
}

void MidiApi::error(RtMidiError::Type type, std::string errorString)
{
  if (errorCallback_) {
    errorCallback_(type, errorString, errorCallbackUserData_);
    return;
  }

  if (type == RtMidiError::WARNING) {
    std::cerr << '\n' << errorString << "\n\n";
  }
  else if (type == RtMidiError::DEBUG_WARNING) {
#if defined(__RTMIDI_DEBUG__)
    std::cerr << '\n' << errorString << "\n\n";
#endif
  }
  else {
    std::cerr << '\n' << errorString << "\n\n";
    // Note: exceptions disabled for Godot GDExtension compatibility
    // Errors are logged but not thrown
  }
}

// **************************************************************** //
//
// MidiInApi and MidiOutApi subclass prototypes.
//
// **************************************************************** //

class MidiInApi : public MidiApi
{
public:
  MidiInApi(unsigned int queueSizeLimit);
  virtual ~MidiInApi();
  void setCallback(RtMidiCallback callback, void *userData);
  void cancelCallback();
  virtual void ignoreTypes(bool midiSysex, bool midiTime, bool midiSense);
  double getMessage(std::vector<unsigned char> *message);

  struct MidiMessage {
    std::vector<unsigned char> bytes;
    double timeStamp;
  };

  struct MidiQueue {
    unsigned int front;
    unsigned int back;
    unsigned int ringSize;
    MidiMessage *ring;

    MidiQueue() : front(0), back(0), ringSize(0), ring(nullptr) {}
  };

  MidiQueue inputQueue_;
  RtMidiCallback userCallback_;
  void *userCallbackData_;
  bool ignoreFlags_[3];
};

MidiInApi::MidiInApi(unsigned int queueSizeLimit)
  : MidiApi(), userCallback_(nullptr), userCallbackData_(nullptr)
{
  inputQueue_.ringSize = queueSizeLimit;
  if (inputQueue_.ringSize > 0)
    inputQueue_.ring = new MidiMessage[inputQueue_.ringSize];

  ignoreFlags_[0] = true;  // sysex
  ignoreFlags_[1] = true;  // timing
  ignoreFlags_[2] = true;  // sense
}

MidiInApi::~MidiInApi()
{
  delete[] inputQueue_.ring;
}

void MidiInApi::setCallback(RtMidiCallback callback, void *userData)
{
  if (userCallback_) {
    errorString_ = "MidiInApi::setCallback: a callback function is already set!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }
  userCallback_ = callback;
  userCallbackData_ = userData;
}

void MidiInApi::cancelCallback()
{
  if (!userCallback_) {
    errorString_ = "MidiInApi::cancelCallback: no callback function was set!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }
  userCallback_ = nullptr;
  userCallbackData_ = nullptr;
}

void MidiInApi::ignoreTypes(bool midiSysex, bool midiTime, bool midiSense)
{
  ignoreFlags_[0] = midiSysex;
  ignoreFlags_[1] = midiTime;
  ignoreFlags_[2] = midiSense;
}

double MidiInApi::getMessage(std::vector<unsigned char> *message)
{
  message->clear();

  if (inputQueue_.front == inputQueue_.back)
    return 0.0;

  unsigned int idx = inputQueue_.front;
  *message = inputQueue_.ring[idx].bytes;
  double timeStamp = inputQueue_.ring[idx].timeStamp;
  inputQueue_.front = (inputQueue_.front + 1) % inputQueue_.ringSize;

  return timeStamp;
}

class MidiOutApi : public MidiApi
{
public:
  MidiOutApi();
  virtual ~MidiOutApi();
  virtual void sendMessage(const unsigned char *message, size_t size) = 0;
};

MidiOutApi::MidiOutApi() : MidiApi()
{
}

MidiOutApi::~MidiOutApi()
{
}

// **************************************************************** //
//
// RtMidi definitions.
//
// **************************************************************** //

std::string RtMidi::getVersion() throw()
{
  return std::string(RTMIDI_VERSION);
}

void RtMidi::getCompiledApi(std::vector<RtMidi::Api> &apis) throw()
{
  apis = RtMidi::getCompiledApi();
}

std::vector<RtMidi::Api> RtMidi::getCompiledApi() throw()
{
  std::vector<RtMidi::Api> apis;
#if defined(__MACOSX_CORE__)
  apis.push_back(MACOSX_CORE);
#endif
#if defined(__LINUX_ALSA__)
  apis.push_back(LINUX_ALSA);
#endif
#if defined(__WINDOWS_MM__)
  apis.push_back(WINDOWS_MM);
#endif
  return apis;
}

std::string RtMidi::getApiName(RtMidi::Api api)
{
  switch (api) {
    case MACOSX_CORE:  return "core";
    case LINUX_ALSA:   return "alsa";
    case UNIX_JACK:    return "jack";
    case WINDOWS_MM:   return "winmm";
    case RTMIDI_DUMMY: return "dummy";
    default:           return "";
  }
}

std::string RtMidi::getApiDisplayName(RtMidi::Api api)
{
  switch (api) {
    case MACOSX_CORE:  return "CoreMIDI";
    case LINUX_ALSA:   return "ALSA";
    case UNIX_JACK:    return "JACK";
    case WINDOWS_MM:   return "Windows MultiMedia";
    case RTMIDI_DUMMY: return "Dummy";
    default:           return "Unknown";
  }
}

RtMidi::Api RtMidi::getCompiledApiByName(const std::string &name)
{
  for (auto api : getCompiledApi()) {
    if (name == getApiName(api))
      return api;
  }
  return UNSPECIFIED;
}

RtMidi::RtMidi()
  : rtapi_(nullptr)
{
}

RtMidi::~RtMidi()
{
}

void RtMidi::setErrorCallback(RtMidiErrorCallback errorCallback, void *userData)
{
  if (rtapi_)
    rtapi_->setErrorCallback(errorCallback, userData);
}

void RtMidi::setClientName(const std::string &clientName)
{
  if (rtapi_)
    rtapi_->setClientName(clientName);
}

void RtMidi::setPortName(const std::string &portName)
{
  if (rtapi_)
    rtapi_->setPortName(portName);
}

// **************************************************************** //
//
// Platform-specific class implementations
//
// **************************************************************** //

#if defined(__MACOSX_CORE__)

// CoreMIDI implementation

class MidiInCore : public MidiInApi
{
public:
  MidiInCore(const std::string &clientName, unsigned int queueSizeLimit);
  ~MidiInCore();
  RtMidi::Api getCurrentApi() override { return RtMidi::MACOSX_CORE; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;

private:
  MIDIClientRef client_;
  MIDIPortRef port_;
  MIDIEndpointRef endpoint_;
  static void midiInputCallback(const MIDIPacketList *list, void *procRef, void *srcRef);
};

MidiInCore::MidiInCore(const std::string &clientName, unsigned int queueSizeLimit)
  : MidiInApi(queueSizeLimit), client_(0), port_(0), endpoint_(0)
{
  CFStringRef name = CFStringCreateWithCString(nullptr, clientName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDIClientCreate(name, nullptr, nullptr, &client_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiInCore::MidiInCore: error creating MIDI client.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
  }
}

MidiInCore::~MidiInCore()
{
  closePort();
  if (client_) MIDIClientDispose(client_);
}

void MidiInCore::openPort(unsigned int portNumber, const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiInCore::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  unsigned int nSrc = MIDIGetNumberOfSources();
  if (nSrc < 1) {
    errorString_ = "MidiInCore::openPort: no MIDI input sources found!";
    error(RtMidiError::NO_DEVICES_FOUND, errorString_);
    return;
  }

  if (portNumber >= nSrc) {
    errorString_ = "MidiInCore::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  MIDIEndpointRef src = MIDIGetSource(portNumber);
  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDIInputPortCreate(client_, name, midiInputCallback, (void *)this, &port_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiInCore::openPort: error creating MIDI input port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  result = MIDIPortConnectSource(port_, src, nullptr);
  if (result != noErr) {
    MIDIPortDispose(port_);
    port_ = 0;
    errorString_ = "MidiInCore::openPort: error connecting to MIDI source.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiInCore::openVirtualPort(const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiInCore::openVirtualPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDIDestinationCreate(client_, name, midiInputCallback, (void *)this, &endpoint_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiInCore::openVirtualPort: error creating virtual MIDI destination.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiInCore::closePort()
{
  if (port_) {
    MIDIPortDispose(port_);
    port_ = 0;
  }
  if (endpoint_) {
    MIDIEndpointDispose(endpoint_);
    endpoint_ = 0;
  }
  connected_ = false;
}

void MidiInCore::setClientName(const std::string &)
{
  // Not supported after client creation on CoreMIDI
}

void MidiInCore::setPortName(const std::string &portName)
{
  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  if (endpoint_) {
    MIDIObjectSetStringProperty(endpoint_, kMIDIPropertyName, name);
  }
  CFRelease(name);
}

unsigned int MidiInCore::getPortCount()
{
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  return MIDIGetNumberOfSources();
}

std::string MidiInCore::getPortName(unsigned int portNumber)
{
  CFStringRef nameRef;
  MIDIEndpointRef portRef;
  char name[256];
  std::string stringName;

  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  if (portNumber >= MIDIGetNumberOfSources()) {
    errorString_ = "MidiInCore::getPortName: invalid port number!";
    error(RtMidiError::WARNING, errorString_);
    return stringName;
  }

  portRef = MIDIGetSource(portNumber);
  MIDIObjectGetStringProperty(portRef, kMIDIPropertyName, &nameRef);
  CFStringGetCString(nameRef, name, sizeof(name), kCFStringEncodingUTF8);
  CFRelease(nameRef);

  return std::string(name);
}

void MidiInCore::midiInputCallback(const MIDIPacketList *list, void *procRef, void * /*srcRef*/)
{
  MidiInCore *data = static_cast<MidiInCore *>(procRef);
  const MIDIPacket *packet = &list->packet[0];

  for (unsigned int i = 0; i < list->numPackets; ++i) {
    // Get timestamp in seconds
    double timeStamp = 0.0;
    if (packet->timeStamp != 0) {
      timeStamp = AudioConvertHostTimeToNanos(packet->timeStamp) / 1000000000.0;
    }

    unsigned int nBytes = packet->length;
    if (nBytes == 0) {
      packet = MIDIPacketNext(packet);
      continue;
    }

    // Handle running status and filtering
    unsigned char status = packet->data[0];

    // Filter based on message type
    if (status < 0x80) {
      packet = MIDIPacketNext(packet);
      continue;
    }

    // System messages
    if (status >= 0xF0) {
      // Sysex
      if (status == 0xF0 && data->ignoreFlags_[0]) {
        packet = MIDIPacketNext(packet);
        continue;
      }
      // Timing
      if (status == 0xF8 && data->ignoreFlags_[1]) {
        packet = MIDIPacketNext(packet);
        continue;
      }
      // Sense
      if (status == 0xFE && data->ignoreFlags_[2]) {
        packet = MIDIPacketNext(packet);
        continue;
      }
    }

    // Create message
    std::vector<unsigned char> message;
    message.assign(packet->data, packet->data + nBytes);

    if (data->userCallback_) {
      data->userCallback_(timeStamp, &message, data->userCallbackData_);
    } else {
      // Queue message
      if (data->inputQueue_.ringSize > 0) {
        unsigned int idx = data->inputQueue_.back;
        data->inputQueue_.ring[idx].bytes = message;
        data->inputQueue_.ring[idx].timeStamp = timeStamp;
        data->inputQueue_.back = (data->inputQueue_.back + 1) % data->inputQueue_.ringSize;
        if (data->inputQueue_.back == data->inputQueue_.front) {
          data->inputQueue_.front = (data->inputQueue_.front + 1) % data->inputQueue_.ringSize;
        }
      }
    }

    packet = MIDIPacketNext(packet);
  }
}

// CoreMIDI Output

class MidiOutCore : public MidiOutApi
{
public:
  MidiOutCore(const std::string &clientName);
  ~MidiOutCore();
  RtMidi::Api getCurrentApi() override { return RtMidi::MACOSX_CORE; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;
  void sendMessage(const unsigned char *message, size_t size) override;

private:
  MIDIClientRef client_;
  MIDIPortRef port_;
  MIDIEndpointRef endpoint_;
  MIDIEndpointRef destination_;
};

MidiOutCore::MidiOutCore(const std::string &clientName)
  : MidiOutApi(), client_(0), port_(0), endpoint_(0), destination_(0)
{
  CFStringRef name = CFStringCreateWithCString(nullptr, clientName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDIClientCreate(name, nullptr, nullptr, &client_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiOutCore::MidiOutCore: error creating MIDI client.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
  }
}

MidiOutCore::~MidiOutCore()
{
  closePort();
  if (client_) MIDIClientDispose(client_);
}

void MidiOutCore::openPort(unsigned int portNumber, const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiOutCore::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  unsigned int nDest = MIDIGetNumberOfDestinations();
  if (nDest < 1) {
    errorString_ = "MidiOutCore::openPort: no MIDI output destinations found!";
    error(RtMidiError::NO_DEVICES_FOUND, errorString_);
    return;
  }

  if (portNumber >= nDest) {
    errorString_ = "MidiOutCore::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  destination_ = MIDIGetDestination(portNumber);
  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDIOutputPortCreate(client_, name, &port_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiOutCore::openPort: error creating MIDI output port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiOutCore::openVirtualPort(const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiOutCore::openVirtualPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  OSStatus result = MIDISourceCreate(client_, name, &endpoint_);
  CFRelease(name);

  if (result != noErr) {
    errorString_ = "MidiOutCore::openVirtualPort: error creating virtual MIDI source.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiOutCore::closePort()
{
  if (port_) {
    MIDIPortDispose(port_);
    port_ = 0;
  }
  if (endpoint_) {
    MIDIEndpointDispose(endpoint_);
    endpoint_ = 0;
  }
  destination_ = 0;
  connected_ = false;
}

void MidiOutCore::setClientName(const std::string &)
{
  // Not supported after client creation on CoreMIDI
}

void MidiOutCore::setPortName(const std::string &portName)
{
  CFStringRef name = CFStringCreateWithCString(nullptr, portName.c_str(), kCFStringEncodingUTF8);
  if (endpoint_) {
    MIDIObjectSetStringProperty(endpoint_, kMIDIPropertyName, name);
  }
  CFRelease(name);
}

unsigned int MidiOutCore::getPortCount()
{
  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  return MIDIGetNumberOfDestinations();
}

std::string MidiOutCore::getPortName(unsigned int portNumber)
{
  CFStringRef nameRef;
  MIDIEndpointRef portRef;
  char name[256];
  std::string stringName;

  CFRunLoopRunInMode(kCFRunLoopDefaultMode, 0, false);
  if (portNumber >= MIDIGetNumberOfDestinations()) {
    errorString_ = "MidiOutCore::getPortName: invalid port number!";
    error(RtMidiError::WARNING, errorString_);
    return stringName;
  }

  portRef = MIDIGetDestination(portNumber);
  MIDIObjectGetStringProperty(portRef, kMIDIPropertyName, &nameRef);
  CFStringGetCString(nameRef, name, sizeof(name), kCFStringEncodingUTF8);
  CFRelease(nameRef);

  return std::string(name);
}

void MidiOutCore::sendMessage(const unsigned char *message, size_t size)
{
  if (!connected_) {
    errorString_ = "MidiOutCore::sendMessage: no open port!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  MIDIPacketList packetList;
  MIDIPacket *packet = MIDIPacketListInit(&packetList);
  packet = MIDIPacketListAdd(&packetList, sizeof(packetList), packet, 0, size, message);

  if (endpoint_) {
    MIDIReceived(endpoint_, &packetList);
  } else {
    MIDISend(port_, destination_, &packetList);
  }
}

#endif // __MACOSX_CORE__

#if defined(__LINUX_ALSA__)

// ALSA implementation

class MidiInAlsa : public MidiInApi
{
public:
  MidiInAlsa(const std::string &clientName, unsigned int queueSizeLimit);
  ~MidiInAlsa();
  RtMidi::Api getCurrentApi() override { return RtMidi::LINUX_ALSA; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;

private:
  snd_seq_t *seq_;
  int portNum_;
  pthread_t thread_;
  bool threadRunning_;
  static void *alsaMidiHandler(void *ptr);
};

MidiInAlsa::MidiInAlsa(const std::string &clientName, unsigned int queueSizeLimit)
  : MidiInApi(queueSizeLimit), seq_(nullptr), portNum_(-1), threadRunning_(false)
{
  if (snd_seq_open(&seq_, "default", SND_SEQ_OPEN_DUPLEX, SND_SEQ_NONBLOCK) < 0) {
    errorString_ = "MidiInAlsa::MidiInAlsa: error creating ALSA sequencer client.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }
  snd_seq_set_client_name(seq_, clientName.c_str());
}

MidiInAlsa::~MidiInAlsa()
{
  closePort();
  if (seq_) snd_seq_close(seq_);
}

unsigned int MidiInAlsa::getPortCount()
{
  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_READ) && (caps & SND_SEQ_PORT_CAP_SUBS_READ))
        count++;
    }
  }
  return count;
}

std::string MidiInAlsa::getPortName(unsigned int portNumber)
{
  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_READ) && (caps & SND_SEQ_PORT_CAP_SUBS_READ)) {
        if (count == portNumber) {
          std::ostringstream os;
          os << snd_seq_client_info_get_name(cinfo) << ":" << snd_seq_port_info_get_name(pinfo);
          return os.str();
        }
        count++;
      }
    }
  }
  return "";
}

void *MidiInAlsa::alsaMidiHandler(void *ptr)
{
  MidiInAlsa *data = static_cast<MidiInAlsa *>(ptr);
  snd_seq_event_t *ev;
  double time;

  while (data->threadRunning_) {
    if (snd_seq_event_input(data->seq_, &ev) >= 0) {
      std::vector<unsigned char> message;
      time = 0.0;

      switch (ev->type) {
        case SND_SEQ_EVENT_NOTEON:
          message.push_back(0x90 | ev->data.note.channel);
          message.push_back(ev->data.note.note);
          message.push_back(ev->data.note.velocity);
          break;
        case SND_SEQ_EVENT_NOTEOFF:
          message.push_back(0x80 | ev->data.note.channel);
          message.push_back(ev->data.note.note);
          message.push_back(ev->data.note.velocity);
          break;
        case SND_SEQ_EVENT_CONTROLLER:
          message.push_back(0xB0 | ev->data.control.channel);
          message.push_back(ev->data.control.param);
          message.push_back(ev->data.control.value);
          break;
        case SND_SEQ_EVENT_CLOCK:
          message.push_back(0xF8);
          break;
        case SND_SEQ_EVENT_START:
          message.push_back(0xFA);
          break;
        case SND_SEQ_EVENT_CONTINUE:
          message.push_back(0xFB);
          break;
        case SND_SEQ_EVENT_STOP:
          message.push_back(0xFC);
          break;
        default:
          break;
      }

      if (!message.empty()) {
        if (data->userCallback_) {
          data->userCallback_(time, &message, data->userCallbackData_);
        } else if (data->inputQueue_.ringSize > 0) {
          unsigned int idx = data->inputQueue_.back;
          data->inputQueue_.ring[idx].bytes = message;
          data->inputQueue_.ring[idx].timeStamp = time;
          data->inputQueue_.back = (data->inputQueue_.back + 1) % data->inputQueue_.ringSize;
          if (data->inputQueue_.back == data->inputQueue_.front) {
            data->inputQueue_.front = (data->inputQueue_.front + 1) % data->inputQueue_.ringSize;
          }
        }
      }
      snd_seq_free_event(ev);
    }
  }
  return nullptr;
}

void MidiInAlsa::openPort(unsigned int portNumber, const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiInAlsa::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  unsigned int nSrc = getPortCount();
  if (nSrc < 1) {
    errorString_ = "MidiInAlsa::openPort: no MIDI input sources found!";
    error(RtMidiError::NO_DEVICES_FOUND, errorString_);
    return;
  }

  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  int srcClient = -1, srcPort = -1;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_READ) && (caps & SND_SEQ_PORT_CAP_SUBS_READ)) {
        if (count == portNumber) {
          srcClient = snd_seq_port_info_get_client(pinfo);
          srcPort = snd_seq_port_info_get_port(pinfo);
          break;
        }
        count++;
      }
    }
    if (srcClient >= 0) break;
  }

  if (srcClient < 0) {
    errorString_ = "MidiInAlsa::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  portNum_ = snd_seq_create_simple_port(seq_, portName.c_str(),
    SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE,
    SND_SEQ_PORT_TYPE_MIDI_GENERIC | SND_SEQ_PORT_TYPE_APPLICATION);

  if (portNum_ < 0) {
    errorString_ = "MidiInAlsa::openPort: error creating port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  snd_seq_connect_from(seq_, portNum_, srcClient, srcPort);

  threadRunning_ = true;
  pthread_create(&thread_, nullptr, alsaMidiHandler, this);

  connected_ = true;
}

void MidiInAlsa::openVirtualPort(const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiInAlsa::openVirtualPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  portNum_ = snd_seq_create_simple_port(seq_, portName.c_str(),
    SND_SEQ_PORT_CAP_WRITE | SND_SEQ_PORT_CAP_SUBS_WRITE,
    SND_SEQ_PORT_TYPE_MIDI_GENERIC | SND_SEQ_PORT_TYPE_APPLICATION);

  if (portNum_ < 0) {
    errorString_ = "MidiInAlsa::openVirtualPort: error creating port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  threadRunning_ = true;
  pthread_create(&thread_, nullptr, alsaMidiHandler, this);

  connected_ = true;
}

void MidiInAlsa::closePort()
{
  if (threadRunning_) {
    threadRunning_ = false;
    pthread_join(thread_, nullptr);
  }
  if (portNum_ >= 0) {
    snd_seq_delete_port(seq_, portNum_);
    portNum_ = -1;
  }
  connected_ = false;
}

void MidiInAlsa::setClientName(const std::string &clientName)
{
  snd_seq_set_client_name(seq_, clientName.c_str());
}

void MidiInAlsa::setPortName(const std::string &portName)
{
  if (portNum_ >= 0) {
    snd_seq_port_info_t *pinfo;
    snd_seq_port_info_alloca(&pinfo);
    snd_seq_get_port_info(seq_, portNum_, pinfo);
    snd_seq_port_info_set_name(pinfo, portName.c_str());
    snd_seq_set_port_info(seq_, portNum_, pinfo);
  }
}

// ALSA Output

class MidiOutAlsa : public MidiOutApi
{
public:
  MidiOutAlsa(const std::string &clientName);
  ~MidiOutAlsa();
  RtMidi::Api getCurrentApi() override { return RtMidi::LINUX_ALSA; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;
  void sendMessage(const unsigned char *message, size_t size) override;

private:
  snd_seq_t *seq_;
  int portNum_;
  int destClient_;
  int destPort_;
};

MidiOutAlsa::MidiOutAlsa(const std::string &clientName)
  : MidiOutApi(), seq_(nullptr), portNum_(-1), destClient_(-1), destPort_(-1)
{
  if (snd_seq_open(&seq_, "default", SND_SEQ_OPEN_OUTPUT, 0) < 0) {
    errorString_ = "MidiOutAlsa::MidiOutAlsa: error creating ALSA sequencer client.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }
  snd_seq_set_client_name(seq_, clientName.c_str());
}

MidiOutAlsa::~MidiOutAlsa()
{
  closePort();
  if (seq_) snd_seq_close(seq_);
}

unsigned int MidiOutAlsa::getPortCount()
{
  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_WRITE) && (caps & SND_SEQ_PORT_CAP_SUBS_WRITE))
        count++;
    }
  }
  return count;
}

std::string MidiOutAlsa::getPortName(unsigned int portNumber)
{
  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_WRITE) && (caps & SND_SEQ_PORT_CAP_SUBS_WRITE)) {
        if (count == portNumber) {
          std::ostringstream os;
          os << snd_seq_client_info_get_name(cinfo) << ":" << snd_seq_port_info_get_name(pinfo);
          return os.str();
        }
        count++;
      }
    }
  }
  return "";
}

void MidiOutAlsa::openPort(unsigned int portNumber, const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiOutAlsa::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  snd_seq_port_info_t *pinfo;
  snd_seq_client_info_t *cinfo;
  snd_seq_port_info_alloca(&pinfo);
  snd_seq_client_info_alloca(&cinfo);

  unsigned int count = 0;
  snd_seq_client_info_set_client(cinfo, -1);
  while (snd_seq_query_next_client(seq_, cinfo) >= 0) {
    int client = snd_seq_client_info_get_client(cinfo);
    if (client == snd_seq_client_id(seq_)) continue;
    snd_seq_port_info_set_client(pinfo, client);
    snd_seq_port_info_set_port(pinfo, -1);
    while (snd_seq_query_next_port(seq_, pinfo) >= 0) {
      unsigned int caps = snd_seq_port_info_get_capability(pinfo);
      if ((caps & SND_SEQ_PORT_CAP_WRITE) && (caps & SND_SEQ_PORT_CAP_SUBS_WRITE)) {
        if (count == portNumber) {
          destClient_ = snd_seq_port_info_get_client(pinfo);
          destPort_ = snd_seq_port_info_get_port(pinfo);
          break;
        }
        count++;
      }
    }
    if (destClient_ >= 0) break;
  }

  if (destClient_ < 0) {
    errorString_ = "MidiOutAlsa::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  portNum_ = snd_seq_create_simple_port(seq_, portName.c_str(),
    SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ,
    SND_SEQ_PORT_TYPE_MIDI_GENERIC | SND_SEQ_PORT_TYPE_APPLICATION);

  if (portNum_ < 0) {
    errorString_ = "MidiOutAlsa::openPort: error creating port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  snd_seq_connect_to(seq_, portNum_, destClient_, destPort_);
  connected_ = true;
}

void MidiOutAlsa::openVirtualPort(const std::string &portName)
{
  if (connected_) {
    errorString_ = "MidiOutAlsa::openVirtualPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  portNum_ = snd_seq_create_simple_port(seq_, portName.c_str(),
    SND_SEQ_PORT_CAP_READ | SND_SEQ_PORT_CAP_SUBS_READ,
    SND_SEQ_PORT_TYPE_MIDI_GENERIC | SND_SEQ_PORT_TYPE_APPLICATION);

  if (portNum_ < 0) {
    errorString_ = "MidiOutAlsa::openVirtualPort: error creating port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiOutAlsa::closePort()
{
  if (portNum_ >= 0) {
    snd_seq_delete_port(seq_, portNum_);
    portNum_ = -1;
  }
  destClient_ = -1;
  destPort_ = -1;
  connected_ = false;
}

void MidiOutAlsa::setClientName(const std::string &clientName)
{
  snd_seq_set_client_name(seq_, clientName.c_str());
}

void MidiOutAlsa::setPortName(const std::string &portName)
{
  if (portNum_ >= 0) {
    snd_seq_port_info_t *pinfo;
    snd_seq_port_info_alloca(&pinfo);
    snd_seq_get_port_info(seq_, portNum_, pinfo);
    snd_seq_port_info_set_name(pinfo, portName.c_str());
    snd_seq_set_port_info(seq_, portNum_, pinfo);
  }
}

void MidiOutAlsa::sendMessage(const unsigned char *message, size_t size)
{
  if (!connected_) {
    errorString_ = "MidiOutAlsa::sendMessage: no open port!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  snd_seq_event_t ev;
  snd_seq_ev_clear(&ev);
  snd_seq_ev_set_source(&ev, portNum_);
  snd_seq_ev_set_subs(&ev);
  snd_seq_ev_set_direct(&ev);

  unsigned char status = message[0];
  unsigned char type = status >> 4;
  unsigned char channel = status & 0x0F;

  switch (type) {
    case 0x8:  // Note Off
      snd_seq_ev_set_noteoff(&ev, channel, message[1], message[2]);
      break;
    case 0x9:  // Note On
      snd_seq_ev_set_noteon(&ev, channel, message[1], message[2]);
      break;
    case 0xB:  // Control Change
      snd_seq_ev_set_controller(&ev, channel, message[1], message[2]);
      break;
    case 0xF:  // System
      if (status == 0xF8) {
        ev.type = SND_SEQ_EVENT_CLOCK;
      } else if (status == 0xFA) {
        ev.type = SND_SEQ_EVENT_START;
      } else if (status == 0xFB) {
        ev.type = SND_SEQ_EVENT_CONTINUE;
      } else if (status == 0xFC) {
        ev.type = SND_SEQ_EVENT_STOP;
      }
      break;
    default:
      return;
  }

  snd_seq_event_output(seq_, &ev);
  snd_seq_drain_output(seq_);
}

#endif // __LINUX_ALSA__

#if defined(__WINDOWS_MM__)

// Windows Multimedia implementation

class MidiInWinMM : public MidiInApi
{
public:
  MidiInWinMM(const std::string &clientName, unsigned int queueSizeLimit);
  ~MidiInWinMM();
  RtMidi::Api getCurrentApi() override { return RtMidi::WINDOWS_MM; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;

private:
  HMIDIIN inHandle_;
  static void CALLBACK midiInputCallback(HMIDIIN hMidiIn, UINT wMsg, DWORD_PTR dwInstance,
                                          DWORD_PTR dwParam1, DWORD_PTR dwParam2);
};

MidiInWinMM::MidiInWinMM(const std::string & /*clientName*/, unsigned int queueSizeLimit)
  : MidiInApi(queueSizeLimit), inHandle_(nullptr)
{
}

MidiInWinMM::~MidiInWinMM()
{
  closePort();
}

unsigned int MidiInWinMM::getPortCount()
{
  return midiInGetNumDevs();
}

std::string MidiInWinMM::getPortName(unsigned int portNumber)
{
  MIDIINCAPS caps;
  if (midiInGetDevCaps(portNumber, &caps, sizeof(MIDIINCAPS)) == MMSYSERR_NOERROR) {
    return std::string(caps.szPname);
  }
  return "";
}

void CALLBACK MidiInWinMM::midiInputCallback(HMIDIIN /*hMidiIn*/, UINT wMsg,
                                              DWORD_PTR dwInstance, DWORD_PTR dwParam1,
                                              DWORD_PTR /*dwParam2*/)
{
  MidiInWinMM *data = reinterpret_cast<MidiInWinMM *>(dwInstance);

  if (wMsg == MIM_DATA) {
    std::vector<unsigned char> message;
    unsigned char status = dwParam1 & 0xFF;
    message.push_back(status);

    if ((status & 0xF0) != 0xF0) {
      message.push_back((dwParam1 >> 8) & 0xFF);
      if ((status & 0xF0) != 0xC0 && (status & 0xF0) != 0xD0) {
        message.push_back((dwParam1 >> 16) & 0xFF);
      }
    }

    double timeStamp = 0.0;

    if (data->userCallback_) {
      data->userCallback_(timeStamp, &message, data->userCallbackData_);
    } else if (data->inputQueue_.ringSize > 0) {
      unsigned int idx = data->inputQueue_.back;
      data->inputQueue_.ring[idx].bytes = message;
      data->inputQueue_.ring[idx].timeStamp = timeStamp;
      data->inputQueue_.back = (data->inputQueue_.back + 1) % data->inputQueue_.ringSize;
      if (data->inputQueue_.back == data->inputQueue_.front) {
        data->inputQueue_.front = (data->inputQueue_.front + 1) % data->inputQueue_.ringSize;
      }
    }
  }
}

void MidiInWinMM::openPort(unsigned int portNumber, const std::string & /*portName*/)
{
  if (connected_) {
    errorString_ = "MidiInWinMM::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  unsigned int nDevices = midiInGetNumDevs();
  if (nDevices == 0) {
    errorString_ = "MidiInWinMM::openPort: no MIDI input devices found!";
    error(RtMidiError::NO_DEVICES_FOUND, errorString_);
    return;
  }

  if (portNumber >= nDevices) {
    errorString_ = "MidiInWinMM::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  MMRESULT result = midiInOpen(&inHandle_, portNumber,
                                (DWORD_PTR)midiInputCallback,
                                (DWORD_PTR)this, CALLBACK_FUNCTION);
  if (result != MMSYSERR_NOERROR) {
    errorString_ = "MidiInWinMM::openPort: error opening MIDI input port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  midiInStart(inHandle_);
  connected_ = true;
}

void MidiInWinMM::openVirtualPort(const std::string & /*portName*/)
{
  errorString_ = "MidiInWinMM::openVirtualPort: virtual ports are not supported on Windows.";
  error(RtMidiError::WARNING, errorString_);
}

void MidiInWinMM::closePort()
{
  if (inHandle_) {
    midiInStop(inHandle_);
    midiInClose(inHandle_);
    inHandle_ = nullptr;
  }
  connected_ = false;
}

void MidiInWinMM::setClientName(const std::string & /*clientName*/)
{
  // Not supported on Windows
}

void MidiInWinMM::setPortName(const std::string & /*portName*/)
{
  // Not supported on Windows
}

// Windows MM Output

class MidiOutWinMM : public MidiOutApi
{
public:
  MidiOutWinMM(const std::string &clientName);
  ~MidiOutWinMM();
  RtMidi::Api getCurrentApi() override { return RtMidi::WINDOWS_MM; }
  void openPort(unsigned int portNumber, const std::string &portName) override;
  void openVirtualPort(const std::string &portName) override;
  void closePort() override;
  void setClientName(const std::string &clientName) override;
  void setPortName(const std::string &portName) override;
  unsigned int getPortCount() override;
  std::string getPortName(unsigned int portNumber) override;
  void sendMessage(const unsigned char *message, size_t size) override;

private:
  HMIDIOUT outHandle_;
};

MidiOutWinMM::MidiOutWinMM(const std::string & /*clientName*/)
  : MidiOutApi(), outHandle_(nullptr)
{
}

MidiOutWinMM::~MidiOutWinMM()
{
  closePort();
}

unsigned int MidiOutWinMM::getPortCount()
{
  return midiOutGetNumDevs();
}

std::string MidiOutWinMM::getPortName(unsigned int portNumber)
{
  MIDIOUTCAPS caps;
  if (midiOutGetDevCaps(portNumber, &caps, sizeof(MIDIOUTCAPS)) == MMSYSERR_NOERROR) {
    return std::string(caps.szPname);
  }
  return "";
}

void MidiOutWinMM::openPort(unsigned int portNumber, const std::string & /*portName*/)
{
  if (connected_) {
    errorString_ = "MidiOutWinMM::openPort: a valid connection already exists!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  unsigned int nDevices = midiOutGetNumDevs();
  if (nDevices == 0) {
    errorString_ = "MidiOutWinMM::openPort: no MIDI output devices found!";
    error(RtMidiError::NO_DEVICES_FOUND, errorString_);
    return;
  }

  if (portNumber >= nDevices) {
    errorString_ = "MidiOutWinMM::openPort: invalid port number!";
    error(RtMidiError::INVALID_PARAMETER, errorString_);
    return;
  }

  MMRESULT result = midiOutOpen(&outHandle_, portNumber, 0, 0, CALLBACK_NULL);
  if (result != MMSYSERR_NOERROR) {
    errorString_ = "MidiOutWinMM::openPort: error opening MIDI output port.";
    error(RtMidiError::DRIVER_ERROR, errorString_);
    return;
  }

  connected_ = true;
}

void MidiOutWinMM::openVirtualPort(const std::string & /*portName*/)
{
  errorString_ = "MidiOutWinMM::openVirtualPort: virtual ports are not supported on Windows.";
  error(RtMidiError::WARNING, errorString_);
}

void MidiOutWinMM::closePort()
{
  if (outHandle_) {
    midiOutClose(outHandle_);
    outHandle_ = nullptr;
  }
  connected_ = false;
}

void MidiOutWinMM::setClientName(const std::string & /*clientName*/)
{
  // Not supported on Windows
}

void MidiOutWinMM::setPortName(const std::string & /*portName*/)
{
  // Not supported on Windows
}

void MidiOutWinMM::sendMessage(const unsigned char *message, size_t size)
{
  if (!connected_) {
    errorString_ = "MidiOutWinMM::sendMessage: no open port!";
    error(RtMidiError::WARNING, errorString_);
    return;
  }

  DWORD msg = 0;
  for (size_t i = 0; i < size && i < 4; ++i) {
    msg |= (message[i] << (i * 8));
  }

  midiOutShortMsg(outHandle_, msg);
}

#endif // __WINDOWS_MM__

// **************************************************************** //
//
// RtMidiIn and RtMidiOut definitions.
//
// **************************************************************** //

RtMidiIn::RtMidiIn(RtMidi::Api api, const std::string &clientName, unsigned int queueSizeLimit)
  : RtMidi()
{
  if (api != UNSPECIFIED) {
    openMidiApi(api, clientName, queueSizeLimit);
    if (rtapi_) return;
    std::cerr << "RtMidiIn: no compiled API found for specified API.\n";
    return;
  }

  std::vector<RtMidi::Api> apis = getCompiledApi();
  for (auto a : apis) {
    openMidiApi(a, clientName, queueSizeLimit);
    if (rtapi_) return;
  }

  std::cerr << "RtMidiIn: no compiled API found.\n";
}

RtMidiIn::~RtMidiIn() throw()
{
  delete rtapi_;
  rtapi_ = nullptr;
}

void RtMidiIn::openMidiApi(RtMidi::Api api, const std::string &clientName, unsigned int queueSizeLimit)
{
  delete rtapi_;
  rtapi_ = nullptr;

#if defined(__MACOSX_CORE__)
  if (api == MACOSX_CORE)
    rtapi_ = new MidiInCore(clientName, queueSizeLimit);
#endif

#if defined(__LINUX_ALSA__)
  if (api == LINUX_ALSA)
    rtapi_ = new MidiInAlsa(clientName, queueSizeLimit);
#endif

#if defined(__WINDOWS_MM__)
  if (api == WINDOWS_MM)
    rtapi_ = new MidiInWinMM(clientName, queueSizeLimit);
#endif
}

RtMidi::Api RtMidiIn::getCurrentApi() throw()
{
  if (rtapi_)
    return ((MidiInApi *)rtapi_)->getCurrentApi();
  return UNSPECIFIED;
}

void RtMidiIn::openPort(unsigned int portNumber, const std::string &portName)
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->openPort(portNumber, portName);
}

void RtMidiIn::openVirtualPort(const std::string &portName)
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->openVirtualPort(portName);
}

void RtMidiIn::closePort()
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->closePort();
}

bool RtMidiIn::isPortOpen() const
{
  if (rtapi_)
    return rtapi_->isPortOpen();
  return false;
}

unsigned int RtMidiIn::getPortCount()
{
  if (rtapi_)
    return rtapi_->getPortCount();
  return 0;
}

std::string RtMidiIn::getPortName(unsigned int portNumber)
{
  if (rtapi_)
    return rtapi_->getPortName(portNumber);
  return "";
}

void RtMidiIn::setCallback(RtMidiCallback callback, void *userData)
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->setCallback(callback, userData);
}

void RtMidiIn::cancelCallback()
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->cancelCallback();
}

void RtMidiIn::ignoreTypes(bool midiSysex, bool midiTime, bool midiSense)
{
  if (rtapi_)
    ((MidiInApi *)rtapi_)->ignoreTypes(midiSysex, midiTime, midiSense);
}

double RtMidiIn::getMessage(std::vector<unsigned char> *message)
{
  if (rtapi_)
    return ((MidiInApi *)rtapi_)->getMessage(message);
  return 0.0;
}

// RtMidiOut

RtMidiOut::RtMidiOut(RtMidi::Api api, const std::string &clientName)
  : RtMidi()
{
  if (api != UNSPECIFIED) {
    openMidiApi(api, clientName);
    if (rtapi_) return;
    std::cerr << "RtMidiOut: no compiled API found for specified API.\n";
    return;
  }

  std::vector<RtMidi::Api> apis = getCompiledApi();
  for (auto a : apis) {
    openMidiApi(a, clientName);
    if (rtapi_) return;
  }

  std::cerr << "RtMidiOut: no compiled API found.\n";
}

RtMidiOut::~RtMidiOut() throw()
{
  delete rtapi_;
  rtapi_ = nullptr;
}

void RtMidiOut::openMidiApi(RtMidi::Api api, const std::string &clientName)
{
  delete rtapi_;
  rtapi_ = nullptr;

#if defined(__MACOSX_CORE__)
  if (api == MACOSX_CORE)
    rtapi_ = new MidiOutCore(clientName);
#endif

#if defined(__LINUX_ALSA__)
  if (api == LINUX_ALSA)
    rtapi_ = new MidiOutAlsa(clientName);
#endif

#if defined(__WINDOWS_MM__)
  if (api == WINDOWS_MM)
    rtapi_ = new MidiOutWinMM(clientName);
#endif
}

RtMidi::Api RtMidiOut::getCurrentApi() throw()
{
  if (rtapi_)
    return ((MidiOutApi *)rtapi_)->getCurrentApi();
  return UNSPECIFIED;
}

void RtMidiOut::openPort(unsigned int portNumber, const std::string &portName)
{
  if (rtapi_)
    ((MidiOutApi *)rtapi_)->openPort(portNumber, portName);
}

void RtMidiOut::openVirtualPort(const std::string &portName)
{
  if (rtapi_)
    ((MidiOutApi *)rtapi_)->openVirtualPort(portName);
}

void RtMidiOut::closePort()
{
  if (rtapi_)
    ((MidiOutApi *)rtapi_)->closePort();
}

bool RtMidiOut::isPortOpen() const
{
  if (rtapi_)
    return rtapi_->isPortOpen();
  return false;
}

unsigned int RtMidiOut::getPortCount()
{
  if (rtapi_)
    return rtapi_->getPortCount();
  return 0;
}

std::string RtMidiOut::getPortName(unsigned int portNumber)
{
  if (rtapi_)
    return rtapi_->getPortName(portNumber);
  return "";
}

void RtMidiOut::sendMessage(const std::vector<unsigned char> *message)
{
  if (rtapi_)
    ((MidiOutApi *)rtapi_)->sendMessage(message->data(), message->size());
}

void RtMidiOut::sendMessage(const unsigned char *message, size_t size)
{
  if (rtapi_)
    ((MidiOutApi *)rtapi_)->sendMessage(message, size);
}
