import SwiftUI
import AppKit
import os.log

private let logger = Logger(subsystem: "com.voice2text", category: "WindowAccessor")

/// Invisible NSViewRepresentable that captures the hosting NSWindow reference
/// and intercepts the close button to quit the app.
struct WindowAccessor: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            guard let window = view.window else {
                logger.warning("makeNSView: view.window is nil")
                return
            }
            logger.info("Captured mainWindow: \(window.title), delegate=\(String(describing: window.delegate))")
            AppState.shared.mainWindow = window
            // Replace delegate to intercept windowShouldClose
            context.coordinator.originalDelegate = window.delegate
            window.delegate = context.coordinator
            logger.info("Installed custom window delegate")
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    class Coordinator: NSObject, NSWindowDelegate {
        weak var originalDelegate: NSWindowDelegate?

        func windowShouldClose(_ sender: NSWindow) -> Bool {
            logger.info("windowShouldClose intercepted — terminating app")
            NSApp.terminate(nil)
            return false
        }

        // Forward lifecycle events to SwiftUI's original delegate
        func windowDidBecomeKey(_ notification: Notification) {
            originalDelegate?.windowDidBecomeKey?(notification)
        }

        func windowDidResignKey(_ notification: Notification) {
            originalDelegate?.windowDidResignKey?(notification)
        }

        func windowDidResize(_ notification: Notification) {
            originalDelegate?.windowDidResize?(notification)
        }

        func windowDidMove(_ notification: Notification) {
            originalDelegate?.windowDidMove?(notification)
        }
    }
}
