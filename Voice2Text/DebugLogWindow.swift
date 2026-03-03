import SwiftUI

// MARK: - Debug Log Window

struct DebugLogView: View {
    @ObservedObject var appState = AppState.shared

    private var logText: String {
        appState.debugLog.joined(separator: "\n")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(L.debugLogTitle)
                    .font(.headline)
                Text("(\(appState.debugLog.count))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Button(L.copyAll) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(logText, forType: .string)
                }
                .controlSize(.small)
                .disabled(appState.debugLog.isEmpty)
                Button(L.clear) {
                    appState.debugLog.removeAll()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Log content — plain TextEditor for easy select-all and copy
            ScrollViewReader { proxy in
                ScrollView {
                    Text(logText)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.primary)
                        .textSelection(.enabled)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .id("logBottom")
                }
                .onChange(of: appState.debugLog.count) {
                    withAnimation(.easeOut(duration: 0.1)) {
                        proxy.scrollTo("logBottom", anchor: .bottom)
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}
