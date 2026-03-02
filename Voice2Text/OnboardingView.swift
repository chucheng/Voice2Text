import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var step: OnboardingStep = .welcome
    @State private var selectedModel: WhisperModel = .base
    @State private var accessibilityPollTimer: DispatchWorkItem?

    enum OnboardingStep {
        case welcome
        case modelSelection
        case downloading
        case permissions
    }

    var body: some View {
        VStack(spacing: 0) {
            switch step {
            case .welcome:
                welcomeStep
            case .modelSelection:
                modelSelectionStep
            case .downloading:
                downloadingStep
            case .permissions:
                permissionsStep
            }
        }
        .frame(minWidth: 400, minHeight: 400)
        .background(.regularMaterial)
    }

    // MARK: - Welcome

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.blue.gradient)

            Text("Welcome to Voice2Text")
                .font(.title.bold())

            Text("Transcribe speech to text using AI — right from your menu bar.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            Spacer()

            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    step = .modelSelection
                }
            }) {
                Text("Get Started")
                    .font(.headline)
                    .frame(maxWidth: 200)
            }
            .controlSize(.large)
            .buttonStyle(.borderedProminent)

            Spacer()
                .frame(height: 40)
        }
        .padding()
    }

    // MARK: - Model Selection

    private var modelSelectionStep: some View {
        VStack(spacing: 16) {
            Text("Choose a Speech Model")
                .font(.title2.bold())
                .padding(.top, 24)

            Text("Download a Whisper model for offline transcription, or skip to use Apple Speech (requires internet).")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 340)

            // Model list
            List(WhisperModel.allCases, selection: $selectedModel) { model in
                ModelOptionRow(
                    model: model,
                    isSelected: selectedModel == model,
                    isDownloaded: appState.isModelDownloaded(model)
                )
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedModel = model
                }
            }
            .listStyle(.inset(alternatesRowBackgrounds: true))
            .frame(maxHeight: 200)

            HStack(spacing: 12) {
                Button("Skip — Use Apple Speech") {
                    appState.sttEngine = .apple
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .permissions
                    }
                }
                .controlSize(.large)
                .buttonStyle(.bordered)

                if appState.isModelDownloaded(selectedModel) {
                    Button("Continue with \(selectedModel.rawValue)") {
                        appState.sttEngine = .whisper
                        appState.switchModel(to: selectedModel)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .permissions
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Download & Continue") {
                        appState.sttEngine = .whisper
                        appState.switchModel(to: selectedModel)
                        appState.downloadModel(selectedModel)
                        withAnimation(.easeInOut(duration: 0.3)) {
                            step = .downloading
                        }
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 24)
        }
        .padding(.horizontal)
        .onAppear {
            // Auto-select an already-downloaded model if available
            if let downloaded = WhisperModel.allCases.first(where: { appState.isModelDownloaded($0) }) {
                selectedModel = downloaded
            }
        }
    }

    // MARK: - Downloading

    private var downloadingStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "arrow.down.circle")
                .font(.system(size: 48))
                .foregroundStyle(.blue)
                .symbolEffect(.pulse, isActive: appState.isDownloadingModel)

            Text("Downloading \(selectedModel.displayName)")
                .font(.title3.bold())

            VStack(spacing: 8) {
                ProgressView(value: appState.downloadProgress)
                    .frame(maxWidth: 260)

                Text("\(Int(appState.downloadProgress * 100))%")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            if !appState.isDownloadingModel && appState.isModelDownloaded(selectedModel) {
                Text("Download complete!")
                    .font(.callout)
                    .foregroundColor(.green)
                    .transition(.opacity)
            }

            Spacer()
        }
        .padding()
        .onChange(of: appState.isDownloadingModel) { _, isDownloading in
            if !isDownloading && appState.isModelDownloaded(selectedModel) {
                // Auto-transition to permissions after a brief pause
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        step = .permissions
                    }
                }
            }
        }
    }

    // MARK: - Permissions

    private var permissionsStep: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "keyboard.badge.ellipsis")
                .font(.system(size: 48))
                .foregroundStyle(.blue.gradient)

            Text("Global Hotkey")
                .font(.title2.bold())

            VStack(spacing: 12) {
                Text("**Hold ⌘; from any app** to start recording, **release** to transcribe and auto-paste at your cursor.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)

                VStack(alignment: .leading, spacing: 6) {
                    Label("Voice-to-text in any app — no switching windows", systemImage: "text.cursor")
                    Label("Hold to record, release to paste — one shortcut does it all", systemImage: "keyboard")
                    Label("Works in browsers, editors, chat apps, terminals...", systemImage: "globe")
                }
                .font(.callout)
                .foregroundStyle(.secondary)
                .frame(maxWidth: 320, alignment: .leading)

                Text("Accessibility permission is needed so Voice2Text can paste text at your cursor position.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }

            if appState.isAccessibilityGranted {
                Label("Accessibility Granted", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.callout.bold())
            }

            Spacer()

            VStack(spacing: 12) {
                if !appState.isAccessibilityGranted {
                    Button(action: {
                        GlobalHotkeyManager.requestAccessibility()
                        // Poll for grant
                        pollAccessibility()
                    }) {
                        Text("Open System Settings")
                            .font(.headline)
                            .frame(maxWidth: 200)
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                }

                if appState.isAccessibilityGranted {
                    Button("Continue") {
                        appState.onboardingCompleted = true
                    }
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Skip for Now") {
                        appState.globalHotkeyEnabled = true
                        appState.onboardingCompleted = true
                    }
                    .controlSize(.large)
                    .buttonStyle(.bordered)
                }
            }

            Spacer()
                .frame(height: 40)
        }
        .padding()
        .onAppear {
            appState.refreshAccessibilityStatus()
        }
        .onDisappear {
            accessibilityPollTimer?.cancel()
        }
    }

    private func pollAccessibility() {
        accessibilityPollTimer?.cancel()
        func schedule() {
            let item = DispatchWorkItem {
                appState.refreshAccessibilityStatus()
                if !appState.isAccessibilityGranted {
                    schedule()
                }
            }
            accessibilityPollTimer = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1, execute: item)
        }
        schedule()
    }
}

// MARK: - Model Option Row

private struct ModelOptionRow: View {
    let model: WhisperModel
    let isSelected: Bool
    let isDownloaded: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(model.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    if isDownloaded {
                        Text("Downloaded")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(.green.opacity(0.15)))
                            .foregroundColor(.green)
                    }
                }
                Text(modelDescription(model))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding(.vertical, 2)
    }

    private func modelDescription(_ model: WhisperModel) -> String {
        switch model {
        case .tiny: return "Fastest, lowest accuracy"
        case .base: return "Good balance of speed and accuracy"
        case .small: return "Better accuracy, moderate size"
        case .medium: return "High accuracy, large download"
        case .largeTurbo: return "Best accuracy, largest download"
        }
    }
}
