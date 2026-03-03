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
        if appState.isReformatting { return "Reformatting..." }
        if appState.isTranscribing { return "Transcribing..." }
        if appState.isStarting { return "Starting..." }
        if appState.isRecording { return "Recording..." }
        return "Hold Space to record"
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
                .padding(.vertical, 10)
        }
        .background(.regularMaterial)
        .alert("Microphone Access Required", isPresented: $appState.showMicrophoneAlert) {
            Button("Open System Settings") {
                if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                    NSWorkspace.shared.open(url)
                }
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Voice2Text needs microphone access to record audio. Please enable it in System Settings > Privacy & Security > Microphone.")
        }
        .alert("Enable Auto-Paste?", isPresented: $appState.showAccessibilityAlert) {
            Button("Open System Settings") {
                GlobalHotkeyManager.requestAccessibility()
            }
            Button("Disable Global Hotkey") {
                appState.globalHotkeyEnabled = false
                GlobalHotkeyManager.shared.unregister()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("Grant Accessibility permission to let the global hotkey (⌘;) auto-paste transcriptions at your cursor. Without it, text will only be copied to clipboard.")
        }
        .alert("Accessibility Permission Needs Refresh", isPresented: $appState.showAccessibilityUpgradeAlert) {
            Button("Open System Settings") {
                GlobalHotkeyManager.requestAccessibility()
            }
            Button("Disable Global Hotkey") {
                appState.globalHotkeyEnabled = false
                GlobalHotkeyManager.shared.unregister()
            }
            Button("Later", role: .cancel) {}
        } message: {
            Text("After updating Voice2Text, macOS invalidates the Accessibility permission. Please open System Settings → Privacy & Security → Accessibility, select Voice2Text and click \"−\" to remove it, then re-add it by clicking \"+\" or relaunch the app.")
        }
    }

    // MARK: - Top Bar

    @ViewBuilder
    private var topBar: some View {
        HStack(spacing: 8) {
            // Engine badge
            HStack(spacing: 4) {
                Image(systemName: appState.sttEngine == .whisper ? "cpu" : "applelogo")
                    .font(.caption2)
                Text(appState.sttEngine.rawValue)
                    .font(.caption)
                    .fontWeight(.medium)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.quaternary))

            // Warnings
            if appState.sttEngine == .whisper && !appState.isModelLoaded {
                Label("No model loaded", systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundColor(.orange)
            }
            if appState.sttEngine == .apple && !appState.isNetworkAvailable {
                Label("No network", systemImage: "wifi.slash")
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
            .help("Settings (⌘,)")

            Spacer()

            // First-use tooltip
            if appState.showFirstUseTooltip {
                Text("Hold Space to record, ⌘C to copy")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .onAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 8) {
                            withAnimation {
                                appState.showFirstUseTooltip = false
                            }
                        }
                    }
            }

            Spacer()

            // Copy button
            CopyButton(text: appState.transcriptionText)
        }
    }
}
