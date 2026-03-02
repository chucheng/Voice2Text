import SwiftUI

struct WaveformView: View {
    let audioLevel: Float
    let barCount: Int = 20

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30)) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            Canvas { context, canvasSize in
                let barWidth: CGFloat = 3
                let gap: CGFloat = 2
                let totalWidth = CGFloat(barCount) * (barWidth + gap) - gap
                let startX = (canvasSize.width - totalWidth) / 2
                let maxHeight = canvasSize.height

                for i in 0..<barCount {
                    let phase = sin(t * 4 + Double(i) * 0.4)
                    let base = CGFloat(audioLevel) * maxHeight
                    let height = max(4, base * CGFloat(0.5 + 0.5 * phase))

                    let x = startX + CGFloat(i) * (barWidth + gap)
                    let y = (maxHeight - height) / 2

                    let rect = CGRect(x: x, y: y, width: barWidth, height: height)
                    let path = Path(roundedRect: rect, cornerRadius: barWidth / 2)

                    let progress = CGFloat(i) / CGFloat(barCount - 1)
                    let color = Color(
                        hue: 0.55 + Double(progress) * 0.1,
                        saturation: 0.7,
                        brightness: 0.9
                    )
                    context.fill(path, with: .color(color.opacity(0.8)))
                }
            }
        }
        .frame(height: 40)
    }
}
