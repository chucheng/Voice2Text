import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    private var recordingLabel: String {
        if appState.isStarting {
            return "Starting..."
        }
        return appState.isRecording ? "Stop Recording" : "Start Recording"
    }

    var body: some View {
        Button(recordingLabel) {
            appState.toggleRecording()
        }
        .disabled(!appState.canToggle)
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
}
