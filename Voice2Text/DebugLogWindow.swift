import SwiftUI

// MARK: - Debug Log Window

struct DebugLogView: View {
    @ObservedObject var appState = AppState.shared

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
                Button(L.clear) {
                    appState.debugLog.removeAll()
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(.bar)

            Divider()

            // Log content
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(Array(appState.debugLog.enumerated()), id: \.offset) { idx, line in
                            Text(line)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 1)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(idx % 2 == 0 ? Color.clear : Color.primary.opacity(0.03))
                                .id(idx)
                        }
                    }
                }
                .onChange(of: appState.debugLog.count) {
                    if let last = appState.debugLog.indices.last {
                        withAnimation(.easeOut(duration: 0.1)) {
                            proxy.scrollTo(last, anchor: .bottom)
                        }
                    }
                }
            }
        }
        .frame(minWidth: 500, minHeight: 300)
    }
}
