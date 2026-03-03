import SwiftUI

struct CopyButton: View {
    let text: String
    @State private var copied = false

    var body: some View {
        Button(action: {
            guard !text.isEmpty else { return }
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)
            copied = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                copied = false
            }
        }) {
            Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc")
                .font(.system(size: 16))
                .contentTransition(.symbolEffect(.replace))
                .foregroundStyle(copied ? .green : .secondary)
        }
        .buttonStyle(.plain)
        .disabled(text.isEmpty)
        .help(L.copyTooltip)
    }
}
