import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    private var recordButtonState: RecordButtonState {
        if appState.isReformatting { return .reformatting }
        if appState.isTranscribing { return .transcribing }
        if appState.isStarting { return .starting }
        if appState.isRecording { return .recording }
        return .idle
    }

    private var statusText: String {
        if appState.isReformatting { return L.reformatting }
        if appState.isTranscribing { return L.transcribing }
        if appState.isStarting { return L.starting }
        if appState.isRecording { return L.recording }
        return L.holdSpaceToRecord
    }

    var body: some View {
        VStack(spacing: 0) {
            // Top bar: engine badge + warnings
            topBar
                .padding(.horizontal, 16)
                .padding(.top, 12)

            Spacer()

            // Center: record button + waveform + status
            VStack(spacing: 12) {
                RecordButton(
                    state: recordButtonState,
                    action: { appState.toggleRecording() },
                    disabled: !appState.canToggle
                )

                // Waveform (only when recording)
                if appState.isRecording {
                    WaveformView(audioLevel: appState.audioLevel)
                        .frame(width: 200)
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }

                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .animation(.spring(response: 0.4), value: appState.isRecording)

            Spacer()

            // Transcription area
            TranscriptionView(
                text: $appState.transcriptionText,
                isProcessing: appState.isTranscribing || appState.isReformatting
            )
            .frame(minHeight: 80, maxHeight: 160)
            .padding(.horizontal, 16)

            // Bottom toolbar
            bottomToolbar
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
        }
        .overlay(alignment: .bottom) {
            if appState.lowAudioWarning {
                Text(L.lowAudioBanner)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.yellow))
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if appState.reviseFailed {
                Text(L.reviseFailedBanner)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange))
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            } else if appState.reviseFailedWithFallback {
                Text(L.reviseFailedFallbackBanner)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.orange))
                    .padding(.bottom, 52)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if let warning = appState.deviceDisconnectedWarning {
                Text(warning)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(.orange))
                    .padding(.top, 4)
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .overlay(alignment: .top) {
            if appState.showWhatsNew, !appState.whatsNewEntries.isEmpty {
                WhatsNewView(
                    entries: appState.whatsNewEntries,
                    language: appState.uiLanguage,
                    onDismiss: { appState.dismissWhatsNew() }
                )
                .padding(.top, 8)
            }
        }
        .background(.regularMaterial)
        .alert(L.micAccessRequired, isPresented: $appState.showMicrophoneAlert) {
            Button(L.openSystemSettings) {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button(L.later, role: .cancel) {}
        } message: {
            Text(L.micAccessMessage)
        }
        .alert(L.enableAutoPaste, isPresented: $appState.showAccessibilityAlert) {
            Button(L.openSystemSettings) {
                GlobalHotkeyManager.requestAccessibility()
            }
            Button(L.disableGlobalHotkey) {
                appState.globalHotkeyEnabled = false
                GlobalHotkeyManager.shared.unregister()
            }
            Button(L.later, role: .cancel) {}
        } message: {
            Text(L.autoPasteMessage)
        }
        .alert(L.accessibilityNeedsRefresh, isPresented: $appState.showAccessibilityUpgradeAlert) {
            Button(L.openSystemSettings) {
                GlobalHotkeyManager.requestAccessibility()
            }
            Button(L.disableGlobalHotkey) {
                appState.globalHotkeyEnabled = false
                GlobalHotkeyManager.shared.unregister()
            }
            Button(L.later, role: .cancel) {}
        } message: {
            Text(L.accessibilityRefreshMessage)
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 6) {
            // Engine badge — tap to toggle Whisper ↔ Apple Speech
            HStack(spacing: 4) {
                Image(systemName: appState.sttEngine == .whisper ? "cpu" : "applelogo")
                    .font(.caption2)
                Text(appState.sttEngine.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.ultraThinMaterial))
            .overlay(Capsule().strokeBorder(.quaternary))
            .onTapGesture {
                appState.sttEngine = appState.sttEngine == .whisper ? .apple : .whisper
            }

            // Microphone device indicator
            HStack(spacing: 4) {
                Image(systemName: "mic")
                    .font(.caption2)
                Text(appState.currentInputDeviceName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: 160)
            .background(Capsule().fill(.ultraThinMaterial))
            .help(L.inputDeviceLabel)

            // Service status capsules (BERT hidden when any LLM provider active)
            if appState.usePunctuationRestore && appState.postEditProvider == .none {
                HStack(spacing: 4) {
                    Circle()
                        .fill(appState.isPunctuationModelLoaded ? .green : .red)
                        .frame(width: 7, height: 7)
                    Text(L.autoPunctuation)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
            }

            if appState.postEditProvider == .localLLM {
                HStack(spacing: 4) {
                    if appState.isLoadingLocalLLMModel {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 7, height: 7)
                    } else {
                        Circle()
                            .fill(appState.isPostEditPaused ? .gray :
                                  appState.isLocalLLMModelLoaded ? .green :
                                  appState.isLocalLLMModelDownloaded(appState.selectedLocalLLMModel) ? .orange : .red)
                            .frame(width: 7, height: 7)
                    }
                    Text(L.localLLMBadge)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
                .opacity(appState.isPostEditPaused ? 0.6 : 1.0)
                .onTapGesture {
                    if appState.isPostEditPaused {
                        appState.isPostEditPaused = false
                        appState.log("Local LLM: resumed from badge tap")
                    } else if appState.isLocalLLMModelLoaded {
                        appState.isPostEditPaused = true
                        appState.log("Local LLM: paused from badge tap")
                    } else if !appState.isLoadingLocalLLMModel &&
                              appState.isLocalLLMModelDownloaded(appState.selectedLocalLLMModel) {
                        appState.log("Local LLM: manual load from badge tap")
                        appState.loadLocalLLMModel()
                    }
                }
            }

            if appState.postEditProvider == .cloudAPI {
                HStack(spacing: 4) {
                    if appState.apiCheckState == .checking {
                        ProgressView()
                            .controlSize(.mini)
                            .frame(width: 7, height: 7)
                    } else {
                        Circle()
                            .fill(appState.isPostEditPaused ? .gray :
                                  appState.apiCheckState.isValid ? .green : .red)
                            .frame(width: 7, height: 7)
                    }
                    Text(L.aiRevise)
                        .font(.caption)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Capsule().fill(.ultraThinMaterial))
                .opacity(appState.isPostEditPaused ? 0.6 : 1.0)
                .onTapGesture {
                    if appState.isPostEditPaused {
                        appState.isPostEditPaused = false
                        appState.log("Cloud API: resumed from badge tap")
                    } else if appState.apiCheckState.isValid {
                        appState.isPostEditPaused = true
                        appState.log("Cloud API: paused from badge tap")
                    } else if appState.apiCheckState != .checking {
                        appState.ensureCloudAPIReady()
                    }
                }
            }

            // Warnings
            if appState.sttEngine == .whisper && !appState.isModelLoaded {
                Label(L.noModelLoaded, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if appState.sttEngine == .apple && !appState.isNetworkAvailable {
                Label(L.noNetwork, systemImage: "wifi.slash")
                    .font(.caption)
                    .foregroundColor(.red)
            }

            Spacer()
        }
    }

    // MARK: - Bottom Toolbar

    @ViewBuilder
    private var bottomToolbar: some View {
        HStack {
            // Settings button
            Button(action: {
                openSettings()
            }) {
                Image(systemName: "gearshape")
                    .font(.system(size: 16))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            .help(L.settingsTooltip)

            // Script indicator
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    appState.toggleOutputScript()
                }
            }) {
                Text(appState.outputScript == .traditional ? "繁" : "简")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .frame(width: 22, height: 22)
                    .background(
                        RoundedRectangle(cornerRadius: 5)
                            .fill(.ultraThinMaterial)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 5)
                            .strokeBorder(.quaternary)
                    )
                    .contentTransition(.numericText())
            }
            .buttonStyle(.plain)
            .help(L.scriptIndicatorHelp)
            .padding(.leading, 6)

            Spacer()

            // First-use tooltip or copyright
            if appState.showFirstUseTooltip {
                Text(L.firstUseTooltip)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            withAnimation {
                                appState.showFirstUseTooltip = false
                            }
                        }
                    }
            } else {
                let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
                Text("\u{00A9} Chucheng Hsieh (v\(version))")
                    .font(.caption2)
                    .foregroundStyle(.quaternary)
            }

            Spacer()

            // Copy button
            CopyButton(text: appState.transcriptionText)
        }
    }
}
