import SwiftUI

struct TranscriptionView: View {
    @Binding var text: String
    let isProcessing: Bool

    var body: some View {
        ZStack {
            // Material background
            RoundedRectangle(cornerRadius: 12)
                .fill(.ultraThinMaterial)

            if text.isEmpty && !isProcessing {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 28))
                        .foregroundStyle(.tertiary)
                    Text("Transcription will appear here")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
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
                        .opacity(isProcessing ? 0.4 : 1)

                    // Character count
                    if !text.isEmpty {
                        HStack {
                            Spacer()
                            Text("\(text.count) chars")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                .padding(.trailing, 12)
                                .padding(.bottom, 6)
                        }
                    }
                }
            }
        }
    }
}
