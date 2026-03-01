import SwiftUI

@main
struct Voice2TextApp: App {
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra("Voice2Text", systemImage: "waveform.circle") {
            MenuBarView()
                .environmentObject(appState)
        }

        Window("Voice2Text", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}
