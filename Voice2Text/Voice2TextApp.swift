import SwiftUI

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState()

    var body: some Scene {
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("V2T", systemImage: "waveform.circle")
        }

        Window("Voice2Text", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 400, minHeight: 300)
        }
    }
}
