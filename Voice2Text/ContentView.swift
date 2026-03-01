import SwiftUI

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var audioRecorder = AudioRecorder()

    var body: some View {
        VStack(spacing: 20) {
            // Status indicator
            HStack {
                Circle()
                    .fill(appState.isRecording ? Color.red : Color.gray)
                    .frame(width: 12, height: 12)
                Text(appState.isRecording ? "Recording..." : "Idle")
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
            Button(action: toggleRecording) {
                Label(
                    appState.isRecording ? "Stop Recording" : "Start Recording",
                    systemImage: appState.isRecording ? "stop.circle.fill" : "mic.circle.fill"
                )
                .font(.title3)
            }
            .controlSize(.large)
            .padding(.bottom)
        }
        .padding()
    }

    private func toggleRecording() {
        if appState.isRecording {
            audioRecorder.stopRecording()
            appState.isRecording = false
        } else {
            audioRecorder.startRecording()
            appState.isRecording = true
        }
    }
}
