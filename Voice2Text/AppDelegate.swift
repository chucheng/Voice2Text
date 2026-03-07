import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        // Clean up global hotkey before exit to avoid Carbon handler crash
        GlobalHotkeyManager.shared.unregister()

        // Stop recording directly without triggering async transcription
        let appState = AppState.shared
        if appState.isRecording {
            appState.audioRecorder.stopRecording()
            appState.appleSpeech.stopRecognition()
            appState.isRecording = false
        }

        // Hide floating panel
        FloatingRecordingPanel.shared.hide()

        // Free whisper models synchronously on inference queue
        // to avoid race with in-flight transcription
        appState.whisperBridge.freeModelSync()

        // Free llama model synchronously on inference queue
        appState.llamaBridge.freeModelSync()

        return .terminateNow
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSLog("[Voice2Text] applicationDidFinishLaunching")
        NSLog("[Voice2Text] Windows: %@", NSApp.windows.map { "\($0.title) visible=\($0.isVisible)" }.description)

        // SwiftUI Window scene may not auto-present when combined with MenuBarExtra.
        // Give SwiftUI a moment to set up, then ensure a window is visible.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            NSLog("[Voice2Text] Delayed check — windows: %@", NSApp.windows.map { "\($0.title) visible=\($0.isVisible)" }.description)
            let hasVisible = NSApp.windows.contains { $0.isVisible && $0.canBecomeMain }
            if !hasVisible {
                // Try to find and show the SwiftUI Window
                for window in NSApp.windows where window.canBecomeMain {
                    NSLog("[Voice2Text] Showing window: %@", window.title)
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate()
                    return
                }
                NSLog("[Voice2Text] No main-capable window found")
            }
        }
    }

    /// Called when the user clicks the Dock icon while the app is already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NSLog("[Voice2Text] applicationShouldHandleReopen hasVisibleWindows=%d", flag)
        NSLog("[Voice2Text] mainWindow=%@", String(describing: AppState.shared.mainWindow))

        if !flag {
            if let window = AppState.shared.mainWindow {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate()
                NSLog("[Voice2Text] Reopened main window")
                return false
            } else {
                NSLog("[Voice2Text] mainWindow is nil — scanning all windows")
                for window in sender.windows where window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    NSApp.activate()
                    return false
                }
            }
        }
        return true
    }
}
