import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow

    private var recordingLabel: String {
        if appState.isTranscribing { return "Transcribing..." }
        if appState.isStarting { return "Starting..." }
        return appState.isRecording ? "Stop Recording" : "Start Recording"
    }

    var body: some View {
        Button(recordingLabel) {
            appState.toggleRecording()
        }
        .disabled(!appState.canToggle)
        .keyboardShortcut("r")

        Divider()

        // Script selection (繁體/簡體)
        Picker("Output", selection: $appState.outputScript) {
            ForEach(OutputScript.allCases) { script in
                Text(script.rawValue).tag(script)
            }
        }
        .onChange(of: appState.outputScript) {
            appState.updateDisplayScript()
        }

        Divider()

        // Model selection
        Menu("Model: \(appState.selectedModel.displayName)") {
            ForEach(WhisperModel.allCases) { model in
                Button {
                    appState.switchModel(to: model)
                    if !appState.isModelDownloaded(model) {
                        appState.downloadModel(model)
                    }
                } label: {
                    HStack {
                        Text(model.displayName)
                        if appState.selectedModel == model && appState.isModelLoaded {
                            Text("✓")
                        }
                        if !appState.isModelDownloaded(model) {
                            Text("(Download)")
                        }
                    }
                }
            }
        }

        Divider()

        Button("Output Script") {
            if !appState.transcriptionText.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(appState.transcriptionText, forType: .string)
            }
        }
        .disabled(appState.transcriptionText.isEmpty)

        Divider()

        Button("Open Window") {
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Divider()

        Toggle("Punctuation Restore", isOn: $appState.usePunctuationRestore)
            .disabled(!appState.isPunctuationServerAvailable)

        Toggle("Dev Mode", isOn: $appState.devMode)

        Divider()

        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
