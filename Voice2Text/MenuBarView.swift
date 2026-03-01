import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioRecorder = AudioRecorder()
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button(appState.isRecording ? "Stop Recording" : "Start Recording") {
            toggleRecording()
        }
        .keyboardShortcut("r")

        Divider()

        Button("Output Script") {
            // Placeholder: will copy transcription to clipboard or paste
        }
        .disabled(appState.transcriptionText.isEmpty)

        Divider()

        Button("Open Window") {
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }

    private func toggleRecording() {
        if appState.isRecording {
            audioRecorder.stopRecording()
            appState.isRecording = false
        } else {
            audioRecorder.startRecording()
            appState.isRecording = true
        }
    }
}
