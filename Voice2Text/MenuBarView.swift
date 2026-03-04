import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @Environment(\.openSettings) private var openSettings

    private var recordingLabel: String {
        if appState.isTranscribing { return L.transcribing }
        if appState.isStarting { return L.starting }
        return appState.isRecording ? L.stopRecording : L.startRecording
    }

    var body: some View {
        Button(recordingLabel) {
            appState.toggleRecording()
        }
        .disabled(!appState.canToggle)
        .keyboardShortcut("r")

        Divider()

        // Script selection (繁體/簡體)
        Picker(L.output, selection: $appState.outputScript) {
            ForEach(OutputScript.allCases) { script in
                Text(script.rawValue).tag(script)
            }
        }
        .onChange(of: appState.outputScript) {
            appState.updateDisplayScript()
        }

        Divider()

        // Model selection
        Menu(L.modelMenu(appState.selectedModel.displayName)) {
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
                            Text(L.downloadLabel)
                        }
                    }
                }
            }
        }

        Divider()

        Button(L.copyTranscription) {
            if !appState.transcriptionText.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(appState.transcriptionText, forType: .string)
            }
        }
        .disabled(appState.transcriptionText.isEmpty)

        Divider()

        Button(L.openWindow) {
            openWindow(id: "main")
        }
        .keyboardShortcut("o")

        Button(L.settings) {
            openSettings()
        }
        .keyboardShortcut(",")

        Divider()

        Toggle(L.punctuationRestore, isOn: $appState.usePunctuationRestore)
            .disabled(!appState.isPunctuationModelLoaded || appState.usePostEditRevise)

        Divider()

        Button(L.quit) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
