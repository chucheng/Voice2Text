import AVFoundation

class AudioRecorder: ObservableObject {
    private let audioEngine = AVAudioEngine()
    @Published var isRecording = false

    /// Requests microphone permission and calls the completion handler with the result.
    func requestMicPermission(completion: @escaping (Bool) -> Void) {
        AVCaptureDevice.requestAccess(for: .audio) { granted in
            DispatchQueue.main.async {
                completion(granted)
            }
        }
    }

    /// Starts recording audio from the default input device.
    /// Installs a tap on the audio engine's input node. No WAV export yet.
    func startRecording() {
        requestMicPermission { [weak self] granted in
            guard let self, granted else { return }

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
            } catch {
                print("AudioEngine failed to start: \(error.localizedDescription)")
            }
        }
    }

    /// Stops recording and removes the tap from the input node.
    func stopRecording() {
        audioEngine.inputNode.removeTap(onBus: 0)
        audioEngine.stop()
        isRecording = false
    }
}
