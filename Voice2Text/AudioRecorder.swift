import AVFoundation

class AudioRecorder {
    private let audioEngine = AVAudioEngine()
    private(set) var isRecording = false
    private var isStarting = false

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

            let inputNode = self.audioEngine.inputNode
            let format = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, time in
                // Placeholder: forward audio buffer for transcription
                _ = buffer
                _ = time
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
    func stopRecording() {
        guard isRecording else { return }
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
    }
}
