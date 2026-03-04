import SwiftUI

struct SettingsView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        TabView {
            GeneralTab(appState: appState)
                .tabItem {
                    Label(L.generalTab, systemImage: "gearshape")
                }

            ModelsTab(appState: appState)
                .tabItem {
                    Label(L.modelsTab, systemImage: "cube.box")
                }

            ShortcutsTab(appState: appState)
                .tabItem {
                    Label(L.shortcutsTab, systemImage: "keyboard")
                }

            AdvancedTab(appState: appState)
                .tabItem {
                    Label(L.advancedTab, systemImage: "wrench.and.screwdriver")
                }

            AIServicesTab(appState: appState)
                .tabItem {
                    Label(L.aiServicesTab, systemImage: "cloud")
                }
        }
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 600)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @ObservedObject var appState: AppState

    var body: some View {
        Form {
            Section(L.languageSection) {
                Picker(L.languageLabel, selection: $appState.uiLanguage) {
                    ForEach(UILanguage.allCases) { lang in
                        Text(lang.rawValue).tag(lang)
                    }
                }
                .pickerStyle(.segmented)
            }

            Section(L.sttEngineSection) {
                Picker(L.engineLabel, selection: $appState.sttEngine) {
                    ForEach(STTEngine.allCases) { engine in
                        Text(engine.rawValue).tag(engine)
                    }
                }
                .pickerStyle(.segmented)

                if appState.sttEngine == .apple {
                    HStack {
                        Image(systemName: appState.isNetworkAvailable ? "wifi" : "wifi.slash")
                            .foregroundColor(appState.isNetworkAvailable ? .green : .red)
                        Text(appState.isNetworkAvailable ? L.networkAvailable : L.noNetworkAppleSpeech)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(L.outputScriptSection) {
                Picker(L.scriptLabel, selection: $appState.outputScript) {
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
                    Text(L.downloadingProgress(Int(appState.downloadProgress * 100)))
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
                    Text(L.loading)
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if isDownloaded {
                if !isSelected {
                    Button(L.selectButton) {
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
                .help(L.deleteTooltip)
            } else {
                Button(L.downloadButton) {
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
            Section(L.globalPushToTalk) {
                Toggle(L.enableGlobalHotkey, isOn: $appState.globalHotkeyEnabled)
                    .onChange(of: appState.globalHotkeyEnabled) { _, enabled in
                        if enabled {
                            GlobalHotkeyManager.shared.register()
                        } else {
                            GlobalHotkeyManager.shared.unregister()
                        }
                    }

                if appState.globalHotkeyEnabled {
                    HStack {
                        Text(L.shortcutLabel)
                        Spacer()
                        HotkeyRecorderView(combo: $combo)
                            .onChange(of: combo) { _, newCombo in
                                GlobalHotkeyManager.shared.updateCombo(newCombo)
                            }
                    }

                    Text(L.hotkeyUsageHint)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section(L.accessibilitySection) {
                HStack {
                    Circle()
                        .fill(appState.isAccessibilityGranted ? .green : .orange)
                        .frame(width: 8, height: 8)
                    Text(appState.isAccessibilityGranted
                         ? L.accessibilityGrantedStatus
                         : L.accessibilityNotGrantedStatus)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if !appState.isAccessibilityGranted {
                    Text(L.accessibilityWarning)
                        .font(.caption)
                        .foregroundColor(.orange)

                    Button(L.openSystemSettings) {
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
            Section(L.punctuationSection) {
                Toggle(L.enablePunctuation, isOn: $appState.usePunctuationRestore)
                    .disabled(!appState.isPunctuationModelLoaded || appState.usePostEditRevise)

                if appState.usePostEditRevise {
                    Text(L.punctuationHandledByRevise)
                        .font(.caption)
                        .foregroundColor(.orange)
                } else {
                    Text(L.punctuationDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Download / Delete Punctuation Model
                if appState.isDownloadingPunctuationModel {
                    VStack(alignment: .leading, spacing: 4) {
                        ProgressView(value: appState.punctuationModelDownloadProgress)
                        Text(L.downloadingProgress(Int(appState.punctuationModelDownloadProgress * 100)))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else if appState.isPunctuationModelDownloaded {
                    HStack {
                        Label(L.punctuationModelDownloaded, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                        Spacer()
                        Button(L.deletePunctuationModel, role: .destructive) {
                            appState.deletePunctuationModel()
                        }
                        .controlSize(.small)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 4) {
                        Button(L.downloadPunctuationModel) {
                            appState.downloadPunctuationModel()
                        }
                        .controlSize(.small)

                        Text(L.punctuationModelSizeNote)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Section(L.developerSection) {
                Toggle(L.devModeToggle, isOn: $appState.devMode)

                if appState.devMode {
                    Button(L.debugLogTitle) {
                        openDebugLog()
                    }
                    .controlSize(.small)
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }

    @Environment(\.openWindow) private var openWindow

    private func openDebugLog() {
        openWindow(id: "debug-log")
    }
}

// MARK: - AI Services Tab

private struct AIServicesTab: View {
    @ObservedObject var appState: AppState
    @State private var tokenInput = ""
    @State private var showToken = false
    @State private var tokenSavedFeedback = false
    @State private var promptDraft = ""
    @State private var promptSavedFeedback = false

    private var isBaseURLValid: Bool {
        appState.dangerousZoneBaseURL.isEmpty || AnthropicClient.isValidBaseURL(appState.dangerousZoneBaseURL)
    }

    var body: some View {
        Form {
            // Warning banner
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(L.aiServicesWarning)
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 6).fill(Color.orange.opacity(0.1)))
            .listRowInsets(EdgeInsets())
            .padding(.horizontal)

            Section(L.apiCredentialsSection) {
                // Base URL
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.baseURLLabel).font(.caption).foregroundColor(.secondary)
                    TextField(L.baseURLPlaceholder, text: $appState.dangerousZoneBaseURL)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: appState.dangerousZoneBaseURL) {
                            appState.resetAPICheckState()
                        }
                }
                if !isBaseURLValid {
                    Text(L.invalidBaseURL)
                        .font(.caption)
                        .foregroundColor(.red)
                }
                if AnthropicClient.isInsecureURL(appState.dangerousZoneBaseURL) {
                    Text(L.insecureURLWarning)
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                // Model
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.modelLabel).font(.caption).foregroundColor(.secondary)
                    TextField("", text: $appState.dangerousZoneModel)
                        .textFieldStyle(.roundedBorder)
                        .onChange(of: appState.dangerousZoneModel) {
                            appState.resetAPICheckState()
                        }
                }

                // API Token
                VStack(alignment: .leading, spacing: 2) {
                    Text(L.apiTokenLabel).font(.caption).foregroundColor(.secondary)
                    HStack {
                        if showToken {
                            TextField(L.apiTokenPlaceholder, text: $tokenInput)
                                .textFieldStyle(.roundedBorder)
                        } else {
                            SecureField(L.apiTokenPlaceholder, text: $tokenInput)
                                .textFieldStyle(.roundedBorder)
                        }
                        Button(action: { showToken.toggle() }) {
                            Image(systemName: showToken ? "eye.slash" : "eye")
                        }
                        .buttonStyle(.borderless)
                    }
                }

                HStack(spacing: 8) {
                    Button(L.saveToken) {
                        appState.saveDangerousZoneToken(tokenInput)
                        tokenInput = ""
                        tokenSavedFeedback = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                            tokenSavedFeedback = false
                        }
                    }
                    .disabled(tokenInput.isEmpty)
                    .controlSize(.small)

                    if appState.dangerousZoneTokenIsSet {
                        Button(L.deleteToken, role: .destructive) {
                            appState.deleteDangerousZoneToken()
                            tokenSavedFeedback = false
                        }
                        .controlSize(.small)
                    }

                    Spacer()

                    // Token status
                    if tokenSavedFeedback {
                        Label(L.tokenSaved, systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    } else if appState.dangerousZoneTokenIsSet {
                        Label(L.tokenIsSet, systemImage: "key.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    } else {
                        Label(L.tokenNotSet, systemImage: "key")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Check API button + status
                HStack(spacing: 8) {
                    Button(L.checkAPI) {
                        appState.performAPICheck()
                    }
                    .disabled(!appState.dangerousZoneTokenIsSet
                              || appState.dangerousZoneBaseURL.isEmpty
                              || !isBaseURLValid
                              || appState.apiCheckState == .checking)
                    .controlSize(.small)

                    switch appState.apiCheckState {
                    case .unchecked:
                        EmptyView()
                    case .checking:
                        ProgressView()
                            .controlSize(.small)
                        Text(L.checking)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    case .valid(let ms):
                        Label(L.apiValid(ms), systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.green)
                    case .invalid(let msg):
                        Label(L.apiInvalid(msg), systemImage: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            Section(L.postEditReviseSection) {
                Toggle(L.enablePostEditRevise, isOn: Binding(
                    get: { appState.usePostEditRevise },
                    set: { newValue in
                        if newValue && !appState.apiCheckState.isValid {
                            // Auto-check API when user tries to enable
                            appState.pendingEnableRevise = true
                            appState.performAPICheck()
                        } else {
                            appState.usePostEditRevise = newValue
                        }
                    }
                ))
                .disabled(appState.apiCheckState == .checking
                          || !appState.dangerousZoneTokenIsSet
                          || appState.dangerousZoneBaseURL.isEmpty)

                Text(L.postEditReviseDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if appState.usePostEditRevise {
                    Text(L.reviseExclusivityNote)
                        .font(.caption)
                        .foregroundColor(.orange)

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(L.customPromptLabel)
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Spacer()

                            if promptDraft != appState.customRevisePrompt {
                                Button(L.savePrompt) {
                                    appState.customRevisePrompt = promptDraft
                                    promptSavedFeedback = true
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                        promptSavedFeedback = false
                                    }
                                }
                                .font(.caption)
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }

                            if promptSavedFeedback {
                                Label(L.saved, systemImage: "checkmark.circle.fill")
                                    .font(.caption)
                                    .foregroundColor(.green)
                            }

                            Button(L.resetToDefault) {
                                promptDraft = AnthropicClient.revisePrompt
                                appState.customRevisePrompt = AnthropicClient.revisePrompt
                            }
                            .font(.caption)
                            .buttonStyle(.borderless)
                            .disabled(promptDraft == AnthropicClient.revisePrompt)
                        }
                        TextEditor(text: $promptDraft)
                            .font(.system(size: 11, design: .monospaced))
                            .frame(minHeight: 120, maxHeight: 300)
                    }
                    .onAppear { promptDraft = appState.customRevisePrompt }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
    }
}
