import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        TabView {
            GeneralTab(appState: appState)
                .tabItem {
                    Label("General", systemImage: "gearshape")
                }

            ModelsTab(appState: appState)
                .tabItem {
                    Label("Models", systemImage: "cube.box")
                }

            ShortcutsTab(appState: appState)
                .tabItem {
                    Label("Shortcuts", systemImage: "keyboard")
                }

            AdvancedTab(appState: appState)
                .tabItem {
                    Label("Advanced", systemImage: "wrench.and.screwdriver")
                }
        }
        .frame(width: 450, height: 380)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Speech-to-Text Engine") {
                Picker("Engine", selection: $appState.sttEngine) {
                    ForEach(STTEngine.allCases) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)

                if appState.sttEngine == .apple {
                    HStack {
                        Image(systemName: appState.isNetworkAvailable ? "wifi" : "wifi.slash")
                            .foregroundColor(appState.isNetworkAvailable ? .green : .red)
                        Text(appState.isNetworkAvailable ? "Network available" : "No network — Apple Speech requires internet")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section("Output Script") {
                Picker("Script", selection: $appState.outputScript) {
                    ForEach(OutputScript.allCases) { script in
                        Text(script.rawValue).tag(script)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: appState.outputScript) {
                    appState.updateDisplayScript()
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}

// MARK: - Models Tab

private struct ModelsTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            List {
                ForEach(WhisperModel.allCases) { model in
                    ModelRow(model: model, appState: appState)
                }
            }

            if appState.isDownloadingModel {
                VStack(spacing: 4) {
                    ProgressView(value: appState.downloadProgress)
                    Text("Downloading... \(Int(appState.downloadProgress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            }
        }
    }
}

private struct ModelRow: View {
    let model: WhisperModel
    @ObservedObject var appState: AppState

    private var isSelected: Bool { appState.selectedModel == model }
    private var isDownloaded: Bool { appState.isModelDownloaded(model) }
    private var isLoaded: Bool { isSelected && appState.isModelLoaded }

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if isLoaded {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.caption)
                    }
                }
                if isSelected && !isLoaded && isDownloaded {
                    Text("Loading...")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if isDownloaded {
                if !isSelected {
                    Button("Select") {
                        appState.switchModel(to: model)
                    }
                    .controlSize(.small)
                }
                Button(role: .destructive) {
                    appState.deleteModel(model)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
                .help("Delete model")
            } else {
                Button("Download") {
                    appState.switchModel(to: model)
                    appState.downloadModel(model)
                }
                .controlSize(.small)
                .disabled(appState.isDownloadingModel)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Shortcuts Tab

private struct ShortcutsTab: View {
    @ObservedObject var appState: AppState
    @State private var combo = GlobalHotkeyManager.shared.combo
    @State private var accessibilityTimer: DispatchWorkItem?

    var body: some View {
        Form {
            Section("Global Push-to-Talk") {
                Toggle("Enable global hotkey", isOn: $appState.globalHotkeyEnabled)
                    .onChange(of: appState.globalHotkeyEnabled) { _, enabled in
                        if enabled {
                            GlobalHotkeyManager.shared.register()
                        } else {
                            GlobalHotkeyManager.shared.unregister()
                        }
                    }

                if appState.globalHotkeyEnabled {
                    HStack {
                        Text("Shortcut")
                        Spacer()
                        HotkeyRecorderView(combo: $combo)
                            .onChange(of: combo) { _, newCombo in
                                GlobalHotkeyManager.shared.updateCombo(newCombo)
                            }
                    }

                    Text("Hold the shortcut from any app to record. Release to transcribe and auto-paste.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Accessibility") {
                HStack {
                    Circle()
                        .fill(appState.isAccessibilityGranted ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(appState.isAccessibilityGranted
                         ? "Accessibility granted — auto-paste enabled"
                         : "Accessibility not granted — auto-paste disabled")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !appState.isAccessibilityGranted {
                    Text("Without Accessibility, the global hotkey will still record and copy to clipboard, but cannot auto-paste.")
                        .font(.caption)
                        .foregroundColor(.orange)

                    Button("Open System Settings") {
                        GlobalHotkeyManager.requestAccessibility()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            appState.refreshAccessibilityStatus()
            startPollingAccessibility()
        }
        .onDisappear {
            accessibilityTimer?.cancel()
        }
    }

    private func startPollingAccessibility() {
        func poll() {
            let item = DispatchWorkItem {
                appState.refreshAccessibilityStatus()
                if !appState.isAccessibilityGranted {
                    poll()
                }
            }
            accessibilityTimer = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
        }
        if !appState.isAccessibilityGranted {
            poll()
        }
    }
}

// MARK: - Advanced Tab

private struct AdvancedTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section("Punctuation Restoration (Chinese + English only)") {
                Toggle("Enable punctuation restore", isOn: $appState.usePunctuationRestore)
                    .disabled(!appState.isPunctuationServerAvailable)

                Text("Uses a BERT model to add punctuation to Chinese text. Non-Chinese speech is not affected. When disabled, the zh-wiki-punctuation-restore model is not used.")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Circle()
                        .fill(appState.isPunctuationServerAvailable ? .green : .red)
                        .frame(width: 8, height: 8)
                    Text(appState.isPunctuationServerAvailable ? "Server available" : "Server unavailable")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if !appState.isPunctuationServerAvailable {
                        Button("Retry") {
                            appState.checkPunctuationServer()
                        }
                        .controlSize(.small)
                    }
                }
            }

            Section("Developer") {
                Toggle("Dev Mode", isOn: $appState.devMode)
            }
        }
        .formStyle(.grouped)
        .padding()

        if appState.devMode {
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
                    .frame(maxHeight: 120)
                    .onChange(of: appState.debugLog.count) {
                        if let last = appState.debugLog.indices.last {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
    }
}
