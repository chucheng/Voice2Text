import AVFoundation
import CoreAudio

struct AudioInputDevice: Identifiable, Equatable, Hashable {
    let id: AudioDeviceID        // CoreAudio device ID (UInt32)
    let name: String
    let uid: String              // Persistent unique ID for UserDefaults storage

    static let systemDefault = AudioInputDevice(
        id: AudioDeviceID(0),
        name: "System Default",
        uid: "__system_default__"
    )
}

class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private(set) var isRecording = false
    private var isStarting = false

    /// Accumulated 16kHz mono Float32 samples for whisper inference.
    private(set) var accumulatedSamples: [Float] = []

    /// Called with RMS audio level (0.0–1.0) from the tap buffer.
    var onAudioLevel: ((Float) -> Void)?

    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    /// Requests microphone permission and calls the completion handler with the result.
    private func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Starts recording for whisper (resamples to 16kHz Float32).
    func startRecording(completion: @escaping (Bool) -> Void) {
        startRecording(tapHandler: nil, completion: completion)
    }

    /// Starts recording with an optional raw buffer tap (for Apple Speech).
    /// If tapHandler is provided, raw AVAudioPCMBuffers are forwarded to it.
    /// Resampled samples are always accumulated for whisper.
    func startRecording(tapHandler: ((AVAudioPCMBuffer) -> Void)?, completion: @escaping (Bool) -> Void) {
        guard !isRecording, !isStarting else {
            completion(false)
            return
        }

        isStarting = true

        requestMicPermission { [weak self] granted in
            guard let self, granted else {
                self?.isStarting = false
                completion(false)
                return
            }

            self.accumulatedSamples.removeAll()

            let inputNode = self.audioEngine.inputNode
            let inputFormat = inputNode.outputFormat(forBus: 0)

            guard let converter = AVAudioConverter(from: inputFormat, to: self.whisperFormat) else {
                self.isStarting = false
                completion(false)
                return
            }

            inputNode.installTap(onBus: 0, bufferSize: 4096, format: inputFormat) { [weak self] buffer, _ in
                guard let self else { return }

                // Calculate RMS audio level
                if let channelData = buffer.floatChannelData {
                    let frames = Int(buffer.frameLength)
                    let ptr = channelData[0]
                    var sumSquares: Float = 0
                    for i in 0..<frames {
                        let sample = ptr[i]
                        sumSquares += sample * sample
                    }
                    let rms = sqrtf(sumSquares / Float(max(frames, 1)))
                    // Normalize: typical speech RMS ~0.01–0.1, clamp to 0–1
                    let level = min(rms * 10, 1.0)
                    DispatchQueue.main.async {
                        self.onAudioLevel?(level)
                    }
                }

                // Forward raw buffer to tap handler (Apple Speech)
                tapHandler?(buffer)

                // Resample for whisper
                let frameCount = AVAudioFrameCount(
                    Double(buffer.frameLength) * 16000.0 / inputFormat.sampleRate
                )
                guard frameCount > 0,
                      let convertedBuffer = AVAudioPCMBuffer(pcmFormat: self.whisperFormat, frameCapacity: frameCount)
                else { return }

                var error: NSError?
                let status = converter.convert(to: convertedBuffer, error: &error) { _, outStatus in
                    outStatus.pointee = .haveData
                    return buffer
                }

                if status == .haveData, let channelData = convertedBuffer.floatChannelData {
                    let samples = Array(UnsafeBufferPointer(
                        start: channelData[0],
                        count: Int(convertedBuffer.frameLength)
                    ))
                    DispatchQueue.main.async {
                        self.accumulatedSamples.append(contentsOf: samples)
                    }
                }
            }

            do {
                try self.audioEngine.start()
                self.isRecording = true
                self.isStarting = false
                completion(true)
            } catch {
                print("AudioEngine failed to start: \(error.localizedDescription)")
                inputNode.removeTap(onBus: 0)
                self.isStarting = false
                completion(false)
            }
        }
    }

    /// Stops recording and removes the tap from the input node.
    @discardableResult
    func stopRecording() -> [Float] {
        guard isRecording else { return [] }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
        let samples = accumulatedSamples
        accumulatedSamples.removeAll()
        return samples
    }

    // MARK: - Audio Input Device Management

    /// Called when device list changes (plug/unplug). Delivers updated list.
    var onDevicesChanged: (([AudioInputDevice]) -> Void)?

    /// Called when the system default input device changes.
    var onDefaultDeviceChanged: ((AudioDeviceID) -> Void)?

    private var deviceListListenerBlock: AudioObjectPropertyListenerBlock?
    private var defaultDeviceListenerBlock: AudioObjectPropertyListenerBlock?
    private let listenerQueue = DispatchQueue(label: "com.voice2text.audio-device-listener")

    /// Read a CFString property from a CoreAudio object without triggering pointer warnings.
    private static func copyStringProperty(_ selector: AudioObjectPropertySelector, from objectID: AudioObjectID) -> String? {
        var address = AudioObjectPropertyAddress(
            mSelector: selector,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var size = UInt32(MemoryLayout<CFString>.size)
        let buffer = UnsafeMutableRawPointer.allocate(byteCount: MemoryLayout<CFString>.size, alignment: MemoryLayout<CFString>.alignment)
        defer { buffer.deallocate() }
        let status = AudioObjectGetPropertyData(objectID, &address, 0, nil, &size, buffer)
        guard status == noErr else { return nil }
        return buffer.load(as: CFString.self) as String
    }

    /// Enumerate all available audio input devices.
    static func enumerateInputDevices() -> [AudioInputDevice] {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var dataSize: UInt32 = 0
        var status = AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize
        )
        guard status == noErr, dataSize > 0 else { return [.systemDefault] }

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)
        status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceIDs
        )
        guard status == noErr else { return [.systemDefault] }

        var devices: [AudioInputDevice] = []
        for deviceID in deviceIDs {
            // Check if device has input streams
            var streamAddress = AudioObjectPropertyAddress(
                mSelector: kAudioDevicePropertyStreams,
                mScope: kAudioObjectPropertyScopeInput,
                mElement: kAudioObjectPropertyElementMain
            )
            var streamSize: UInt32 = 0
            let streamStatus = AudioObjectGetPropertyDataSize(deviceID, &streamAddress, 0, nil, &streamSize)
            guard streamStatus == noErr, streamSize > 0 else { continue }

            // Get device name
            let name = deviceName(for: deviceID)

            // Get device UID
            guard let uid = copyStringProperty(kAudioDevicePropertyDeviceUID, from: deviceID) else { continue }

            devices.append(AudioInputDevice(id: deviceID, name: name, uid: uid))
        }

        return [.systemDefault] + devices
    }

    /// Get the system default input device ID.
    static func systemDefaultInputDeviceID() -> AudioDeviceID {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        var deviceID: AudioDeviceID = 0
        var dataSize = UInt32(MemoryLayout<AudioDeviceID>.size)
        let status = AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress, 0, nil, &dataSize, &deviceID
        )
        guard status == noErr else { return 0 }
        return deviceID
    }

    /// Get the name of a specific audio device.
    static func deviceName(for deviceID: AudioDeviceID) -> String {
        copyStringProperty(kAudioObjectPropertyName, from: deviceID) ?? "Unknown"
    }

    /// Set the input device for the audio engine. Must NOT be called while recording.
    func setInputDevice(_ device: AudioInputDevice) {
        guard !isRecording else { return }
        let deviceID: AudioDeviceID
        if device.uid == AudioInputDevice.systemDefault.uid {
            deviceID = AudioRecorder.systemDefaultInputDeviceID()
        } else {
            deviceID = device.id
        }
        guard deviceID != 0 else { return }
        guard let audioUnit = audioEngine.inputNode.audioUnit else { return }

        var mutableDeviceID = deviceID
        AudioUnitSetProperty(
            audioUnit,
            kAudioOutputUnitProperty_CurrentDevice,
            kAudioUnitScope_Global,
            0,
            &mutableDeviceID,
            UInt32(MemoryLayout<AudioDeviceID>.size)
        )
    }

    /// Start listening for device list and default device changes.
    func startDeviceMonitoring() {
        var devicesAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let devicesBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            let devices = AudioRecorder.enumerateInputDevices()
            DispatchQueue.main.async {
                self?.onDevicesChanged?(devices)
            }
        }
        deviceListListenerBlock = devicesBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &devicesAddress,
            listenerQueue,
            devicesBlock
        )

        var defaultAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDefaultInputDevice,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )
        let defaultBlock: AudioObjectPropertyListenerBlock = { [weak self] _, _ in
            let defaultID = AudioRecorder.systemDefaultInputDeviceID()
            DispatchQueue.main.async {
                self?.onDefaultDeviceChanged?(defaultID)
            }
        }
        defaultDeviceListenerBlock = defaultBlock
        AudioObjectAddPropertyListenerBlock(
            AudioObjectID(kAudioObjectSystemObject),
            &defaultAddress,
            listenerQueue,
            defaultBlock
        )
    }

    /// Stop listening for device changes.
    func stopDeviceMonitoring() {
        if let block = deviceListListenerBlock {
            var devicesAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDevices,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &devicesAddress,
                listenerQueue,
                block
            )
            deviceListListenerBlock = nil
        }
        if let block = defaultDeviceListenerBlock {
            var defaultAddress = AudioObjectPropertyAddress(
                mSelector: kAudioHardwarePropertyDefaultInputDevice,
                mScope: kAudioObjectPropertyScopeGlobal,
                mElement: kAudioObjectPropertyElementMain
            )
            AudioObjectRemovePropertyListenerBlock(
                AudioObjectID(kAudioObjectSystemObject),
                &defaultAddress,
                listenerQueue,
                block
            )
            defaultDeviceListenerBlock = nil
        }
    }
}
