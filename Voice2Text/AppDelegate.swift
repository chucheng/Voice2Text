import AppKit

class AppDelegate: NSObject, NSApplicationDelegate {
    /// Called when the user clicks the Dock icon while the app is already running.
    ///
    /// BUG (WIP): When the SwiftUI Window is closed, its NSWindow is destroyed.
    /// `canBecomeMain` finds no windows, and `openWindow(id:)` is only available
    /// inside SwiftUI views — not from AppDelegate. Need a bridge mechanism
    /// (e.g., shared state triggering .openWindow, or keeping the window hidden
    /// instead of destroyed). See TODO in CLAUDE.md.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            for window in sender.windows where window.canBecomeMain {
                window.makeKeyAndOrderFront(nil)
                NSApp.activate(ignoringOtherApps: true)
                return false
            }
        }
        return true
    }
}
