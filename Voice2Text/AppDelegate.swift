import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Called when the user clicks the Dock icon while the app is already running.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            // No visible windows — find the existing window and show it,
            // or rely on SwiftUI to recreate it.
            for window in sender.windows {
                if window.canBecomeMain {
                    window.makeKeyAndOrderFront(nil)
                    return false
                }
            }
        }
        return true
    }
}
