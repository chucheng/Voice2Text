import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var copied = false

    private var statusColor: Color {
        if appState.isReformatting { return .purple }
        if appState.isTranscribing { return .blue }
        if appState.isStarting { return .orange }
        if appState.isRecording { return .red }
        return .gray
    }

    private var statusText: String {
        if appState.isReformatting { return "Reformatting..." }
        if appState.isTranscribing { return "Transcribing..." }
        if appState.isStarting { return "Starting..." }
        if appState.isRecording { return "Recording..." }
        return "Idle"
    }

    private var buttonLabel: String {
        if appState.isTranscribing { return "Transcribing..." }
        if appState.isStarting { return "Starting..." }
        return appState.isRecording ? "Stop Recording" : "Start Recording"
    }

    private var buttonIcon: String {
        appState.isRecording ? "stop.circle.fill" : "mic.circle.fill"
    }

    var body: some View {
        VStack(spacing: 16) {
            // Model selection & status
            modelStatusView

            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.headline)
            }

            // STT engine + script picker
            HStack(spacing: 12) {
                Picker("", selection: $appState.sttEngine) {
                    ForEach(STTEngine.allCases) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .disabled(appState.isRecording)

                if appState.sttEngine == .apple && !appState.isNetworkAvailable {
                    Label("No network", systemImage: "wifi.slash")
                        .font(.caption)
                        .foregroundColor(.red)
                }

                Spacer()

                Picker("", selection: $appState.outputScript) {
                    ForEach(OutputScript.allCases) { script in
                        Text(script.rawValue).tag(script)
                    }
                }
                .pickerStyle(.segmented)
                .fixedSize()
                .onChange(of: appState.outputScript) { _ in
                    appState.updateDisplayScript()
                }
            }

            Divider()

            // Transcription result (editable)
            ZStack {
                if appState.isTranscribing || appState.isReformatting {
                    VStack {
                        ProgressView(appState.isReformatting ? "Reformatting..." : "Transcribing...")
                            .padding()
                        Spacer()
                    }
                }

                if appState.transcriptionText.isEmpty && !appState.isTranscribing && !appState.isReformatting {
                    Text("Transcription will appear here...")
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    TextEditor(text: $appState.transcriptionText)
                        .font(.body)
                        .opacity(appState.isTranscribing || appState.isReformatting ? 0.3 : 1)
                }
            }
            .frame(maxHeight: .infinity)

            // Action buttons
            HStack(spacing: 12) {
                Button(action: { appState.toggleRecording() }) {
                    Label(buttonLabel, systemImage: buttonIcon)
                        .font(.title3)
                }
                .disabled(!appState.canToggle)
                .controlSize(.large)

                Button(action: {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(appState.transcriptionText, forType: .string)
                    copied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { copied = false }
                }) {
                    Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                }
                .disabled(appState.transcriptionText.isEmpty)
                .controlSize(.large)
            }
            .padding(.bottom)

            // Debug log (dev mode)
            if appState.devMode {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Debug Log")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("Clear") {
                            appState.debugLog.removeAll()
                        }
                        .font(.caption)
                        .buttonStyle(.borderless)
                    }
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 2) {
                                ForEach(Array(appState.debugLog.enumerated()), id: \.offset) { idx, line in
                                    Text(line)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundColor(.secondary)
                                        .textSelection(.enabled)
                                        .id(idx)
                                }
                            }
                        }
                        .frame(height: 100)
                        .onChange(of: appState.debugLog.count) { _ in
                            if let last = appState.debugLog.indices.last {
                                proxy.scrollTo(last, anchor: .bottom)
                            }
                        }
                    }
                }
            }
        }
        .padding()
    }

    @ViewBuilder
    private var modelStatusView: some View {
        VStack(spacing: 8) {
            // Model picker
            HStack {
                Text("Model:")
                    .font(.callout)
                Picker("", selection: $appState.selectedModel) {
                    ForEach(WhisperModel.allCases) { model in
                        HStack {
                            Text(model.displayName)
                            if appState.isModelDownloaded(model) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                                    .font(.caption)
                            }
                        }
                        .tag(model)
                    }
                }
                .frame(maxWidth: 220)
                .onChange(of: appState.selectedModel) { newModel in
                    appState.switchModel(to: newModel)
                }

                if appState.isModelDownloaded(appState.selectedModel) && !appState.isDownloadingModel {
                    Button(role: .destructive, action: {
                        appState.deleteModel(appState.selectedModel)
                    }) {
                        Image(systemName: "trash")
                            .font(.callout)
                    }
                    .buttonStyle(.borderless)
                    .help("Delete \(appState.selectedModel.displayName)")
                }
            }

            if appState.isDownloadingModel {
                ProgressView(value: appState.downloadProgress) {
                    Text("Downloading \(appState.selectedModel.fileName)...")
                }
                Text("\(Int(appState.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else if !appState.isModelDownloaded(appState.selectedModel) {
                Button("Download \(appState.selectedModel.displayName)") {
                    appState.downloadModel()
                }
                .controlSize(.small)
            } else if !appState.isModelLoaded {
                ProgressView("Loading model...")
                    .font(.caption)
            }

            if appState.isModelLoaded {
                Text("Loaded: \(appState.loadedModelName)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))
    }
}
