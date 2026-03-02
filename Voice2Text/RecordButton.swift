import SwiftUI

enum RecordButtonState {
    case idle
    case starting
    case recording
    case transcribing
    case reformatting
}

struct RecordButton: View {
    let state: RecordButtonState
    let action: () -> Void
    let disabled: Bool

    private let size: CGFloat = 80

    private var iconName: String {
        switch state {
        case .idle: return "mic.fill"
        case .starting: return "mic.fill"
        case .recording: return "stop.fill"
        case .transcribing: return "waveform"
        case .reformatting: return "text.alignleft"
        }
    }

    private var buttonColor: Color {
        switch state {
        case .idle: return .accentColor
        case .starting: return .orange
        case .recording: return .red
        case .transcribing: return .blue
        case .reformatting: return .purple
        }
    }

    private var isAnimating: Bool {
        state == .recording
    }

    private var isSpinning: Bool {
        state == .transcribing || state == .reformatting
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                // Pulsing rings (recording)
                if isAnimating {
                    PulseRings(color: buttonColor)
                }

                // Spinning ring (transcribing/reformatting)
                if isSpinning {
                    SpinRing(color: buttonColor, size: size + 16)
                }

                // Main circle
                Circle()
                    .fill(buttonColor.gradient)
                    .frame(width: size, height: size)
                    .shadow(color: buttonColor.opacity(0.4), radius: isAnimating ? 12 : 6)

                // Icon
                Image(systemName: iconName)
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(.white)
                    .contentTransition(.symbolEffect(.replace))
            }
            .frame(width: size + 40, height: size + 40)
        }
        .buttonStyle(.plain)
        .disabled(disabled)
        .opacity(disabled ? 0.5 : 1)
        .animation(.spring(response: 0.4), value: state == .recording)
    }
}

// MARK: - Pulse Rings

private struct PulseRings: View {
    let color: Color

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                for i in 0..<3 {
                    let phase = (t + Double(i) * 0.5).truncatingRemainder(dividingBy: 1.5) / 1.5
                    let radius = 40 + phase * 30
                    let opacity = (1 - phase) * 0.3
                    let path = Path(ellipseIn: CGRect(
                        x: center.x - radius,
                        y: center.y - radius,
                        width: radius * 2,
                        height: radius * 2
                    ))
                    context.stroke(path, with: .color(color.opacity(opacity)), lineWidth: 2)
                }
            }
        }
    }
}

// MARK: - Spin Ring

private struct SpinRing: View {
    let color: Color
    let size: CGFloat
    @State private var rotation: Double = 0

    var body: some View {
        Circle()
            .trim(from: 0, to: 0.3)
            .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 3, lineCap: .round))
            .frame(width: size, height: size)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}
