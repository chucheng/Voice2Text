import SwiftUI

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("Voice2Text", id: "main") {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 480, minHeight: 300)
                .background(WindowAccessor())
        }
        .defaultSize(width: 500, height: 400)

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("V2T", systemImage: "waveform.circle")
        }
    }
}
