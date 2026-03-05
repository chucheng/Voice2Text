import SwiftUI

@main
struct Voice2TextApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var appState = AppState.shared

    @Environment(\.openWindow) private var openWindow

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
            .onAppear {
                if appState.devMode {
                    openWindow(id: "debug-log")
                }
            }
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
            Image(systemName: "waveform.circle.fill")
        }
    }
}
