import SwiftUI
import Carbon

struct HotkeyRecorderView: View {
    @Binding var combo: HotkeyCombo
    @State private var isListening = false
    @State private var monitor: Any?

    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                if isListening {
                    stopListening()
                } else {
                    startListening()
                }
            }) {
                Text(isListening ? "Press shortcut..." : combo.displayString)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(minWidth: 100)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isListening ? Color.accentColor.opacity(0.15) : Color.secondary.opacity(0.1))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(isListening ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .onDisappear {
                stopListening()
            }

            if combo != .default {
                Button("Reset") {
                    combo = .default
                }
                .controlSize(.small)
                .buttonStyle(.bordered)
            }
        }
    }

    private func startListening() {
        isListening = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown]) { [self] event in
            // Escape cancels
            if event.keyCode == UInt16(kVK_Escape) {
                stopListening()
                return nil
            }

            let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

            // Require at least one modifier
            guard !modifiers.intersection([.command, .option, .control, .shift]).isEmpty else {
                return nil
            }

            let newCombo = HotkeyCombo(
                keyCode: UInt32(event.keyCode),
                carbonModifiers: HotkeyCombo.carbonModifiers(from: modifiers),
                displayString: HotkeyCombo.displayString(keyCode: event.keyCode, modifiers: modifiers)
            )

            combo = newCombo
            stopListening()
            return nil
        }
    }

    private func stopListening() {
        isListening = false
        if let monitor {
            NSEvent.removeMonitor(monitor)
        }
        monitor = nil
    }
}
