import AVFoundation

class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private(set) var isRecording = false
    private var isStarting = false

    /// Accumulated 16kHz mono Float32 samples for whisper inference.
    private(set) var accumulatedSamples: [Float] = []

    private let whisperFormat = AVAudioFormat(
        commonFormat: .pcmFormatFloat32,
        sampleRate: 16000,
        channels: 1,
        interleaved: false
    )!

    /// Requests microphone permission and calls the completion handler with the result.
    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Starts recording audio from the default input device.
    /// Calls completion on main thread with true if recording started successfully.
    func startRecording(completion: @escaping (Bool) -> Void) {
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
    /// Returns the accumulated 16kHz Float32 samples.
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
}
