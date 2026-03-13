import SwiftUI

struct TranscriptionView: View {
    @Binding var text: String
    let isProcessing: Bool

    @State private var processingPulse = false

    var body: some View {
        ZStack {
            // Material background with subtle border
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(.quaternary)

            if text.isEmpty && !isProcessing {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                        .opacity(0.6)
                    Text(L.transcriptionPlaceholder)
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .opacity(0.6)
                }
            } else {
                VStack(spacing: 0) {
                    if isProcessing {
                        ProgressView()
                            .controlSize(.small)
                            .padding(.top, 12)
                    }

                    TextEditor(text: $text)
                        .font(.system(size: 14, design: .default))
                        .lineSpacing(4)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                        .opacity(isProcessing ? (processingPulse ? 0.3 : 0.5) : 1)
                        .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: processingPulse)
                }
                .overlay(alignment: .bottomTrailing) {
                    if !text.isEmpty {
                        Text(L.charCount(text.count))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .padding(.trailing, 12)
                            .padding(.bottom, 6)
                    }
                }
            }
        }
        .onChange(of: isProcessing) {
            processingPulse = isProcessing
        }
    }
}
