import SwiftUI

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        WindowGroup("Voice2Text", id: "main") {
            Group {
                if appState.onboardingCompleted {
                    ContentView()
                        .frame(minWidth: 400, minHeight: 400)
                        .background(WindowAccessor())
                } else {
                    OnboardingView()
                        .frame(minWidth: 400, minHeight: 400)
                }
            }
            .environmentObject(appState)
        }
        .defaultSize(width: 440, height: 520)

        Window(L.debugLogTitle, id: "debug-log") {
            DebugLogView()
        }
        .defaultSize(width: 600, height: 400)

        Settings {
            SettingsView()
        }

        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
        } label: {
            Label("V2T", systemImage: "waveform.circle")
        }
    }
}
