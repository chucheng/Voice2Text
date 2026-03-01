import Foundation

class AppState: ObservableObject {
    @Published var isRecording = false
    @Published var transcriptionText = ""
}
