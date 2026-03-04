import SwiftUI
import AppKit

// MARK: - FloatingPanelState

enum FloatingPanelState {
    case recording
    case transcribing
    case done
}

// MARK: - FloatingRecordingPanel

class FloatingRecordingPanel {
    static let shared = FloatingRecordingPanel()

    private var panel: NSPanel?
    private var hostingView: NSView?
    private var indicatorState = FloatingIndicatorState()
    private var hideTimer: DispatchWorkItem?

    private init() {}

    func show(state: FloatingPanelState) {
        DispatchQueue.main.async { [self] in
            hideTimer?.cancel()
            hideTimer = nil
            indicatorState.state = state
            indicatorState.audioLevel = 0

            if panel == nil {
                createPanel()
            }

            repositionPanel()
            panel?.orderFrontRegardless()
        }
    }

    func updateAudioLevel(_ level: Float) {
        DispatchQueue.main.async { [self] in
            indicatorState.audioLevel = level
        }
    }

    func showDoneAndHide() {
        DispatchQueue.main.async { [self] in
            indicatorState.state = .done

            let item = DispatchWorkItem { [weak self] in
                self?.hide()
            }
            hideTimer = item
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: item)
        }
    }

    func hide() {
        DispatchQueue.main.async { [self] in
            hideTimer?.cancel()
            hideTimer = nil
            panel?.orderOut(nil)
        }
    }

    private func createPanel() {
        let view = FloatingIndicatorView(state: indicatorState)
            .frame(width: 200, height: 56)
        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(x: 0, y: 0, width: 200, height: 56)

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 200, height: 56),
            styleMask: [.nonactivatingPanel, .hudWindow],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        panel.contentMinSize = NSSize(width: 200, height: 56)
        panel.contentMaxSize = NSSize(width: 200, height: 56)
        panel.contentView = hosting
        panel.isMovableByWindowBackground = true

        self.panel = panel
        self.hostingView = hosting
    }

    /// Reposition panel to top-center of the current main screen.
    private func repositionPanel() {
        guard let panel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - panel.frame.width / 2
        let y = screenFrame.maxY - 80
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - Observable State

class FloatingIndicatorState: ObservableObject {
    @Published var state: FloatingPanelState = .recording
    @Published var audioLevel: Float = 0
}

// MARK: - SwiftUI View

struct FloatingIndicatorView: View {
    @ObservedObject var state: FloatingIndicatorState

    var body: some View {
        HStack(spacing: 10) {
            indicatorIcon
            indicatorText
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 12)
        .background(
            Capsule()
                .fill(.ultraThickMaterial)
                .shadow(color: .black.opacity(0.2), radius: 8, y: 4)
        )
        .animation(.easeInOut(duration: 0.2), value: state.state)
    }

    @ViewBuilder
    private var indicatorIcon: some View {
        switch state.state {
        case .recording:
            Circle()
                .fill(.red)
                .frame(width: 12, height: 12)
                .shadow(color: .red.opacity(0.6), radius: 4)
                .modifier(PulseModifier())
        case .transcribing:
            ProgressView()
                .controlSize(.small)
        case .done:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.system(size: 16))
        }
    }

    private var indicatorText: some View {
        Text(labelText)
            .font(.system(size: 13, weight: .medium))
            .foregroundStyle(.primary)
            .contentTransition(.numericText())
    }

    private var labelText: String {
        switch state.state {
        case .recording: return L.floatingRecording
        case .transcribing: return L.floatingTranscribing
        case .done: return L.floatingPasted
        }
    }
}

// MARK: - Pulse Animation

private struct PulseModifier: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(isPulsing ? 1.3 : 1.0)
            .opacity(isPulsing ? 0.7 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
    }
}
