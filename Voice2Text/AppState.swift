import Foundation

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var isStarting = false
    @Published var transcriptionText = ""

    let audioRecorder = AudioRecorder()

    var canToggle: Bool {
        !isStarting
    }

    func toggleRecording() {
        guard canToggle else { return }

        if isRecording {
            audioRecorder.stopRecording()
            isRecording = false
        } else {
            isStarting = true
            audioRecorder.startRecording { [weak self] success in
                self?.isStarting = false
                self?.isRecording = success
            }
        }
    }
}
