import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState

    private var statusColor: Color {
        if appState.isStarting { return .orange }
        if appState.isRecording { return .red }
        return .gray
    }

    private var statusText: String {
        if appState.isStarting { return "Starting..." }
        if appState.isRecording { return "Recording..." }
        return "Idle"
    }

    private var buttonLabel: String {
        if appState.isStarting { return "Starting..." }
        return appState.isRecording ? "Stop Recording" : "Start Recording"
    }

    private var buttonIcon: String {
        appState.isRecording ? "stop.circle.fill" : "mic.circle.fill"
    }

    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)
                Text(statusText)
                    .font(.headline)
            }

            Divider()

            // Transcription result
            ScrollView {
                Text(appState.transcriptionText.isEmpty
                     ? "Transcription will appear here..."
                     : appState.transcriptionText)
                    .foregroundColor(appState.transcriptionText.isEmpty ? .secondary : .primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
            }
            .frame(maxHeight: .infinity)

            // Start/Stop button
            Button(action: { appState.toggleRecording() }) {
                Label(buttonLabel, systemImage: buttonIcon)
                    .font(.title3)
            }
            .disabled(!appState.canToggle)
            .controlSize(.large)
            .padding(.bottom)
        }
        .padding()
    }
}
