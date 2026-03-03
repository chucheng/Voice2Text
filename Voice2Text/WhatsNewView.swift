import SwiftUI

// MARK: - WhatsNew Data

struct WhatsNewEntry: Codable {
    let version: String
    let changes: [String: [String]]  // "en" / "zh" → list of changes

    func localizedChanges(for language: UILanguage) -> [String] {
        let key = language == .chinese ? "zh" : "en"
        return changes[key] ?? changes["en"] ?? []
    }
}

enum WhatsNewLoader {
    /// Load changelog from bundled WhatsNew.json.
    static func load() -> [WhatsNewEntry] {
        guard let url = Bundle.main.url(forResource: "WhatsNew", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let entries = try? JSONDecoder().decode([WhatsNewEntry].self, from: data)
        else { return [] }
        return entries
    }

    /// Get the entry for a specific version.
    static func entry(for version: String) -> WhatsNewEntry? {
        load().first { $0.version == version }
    }
}

// MARK: - WhatsNewView

struct WhatsNewView: View {
    let entry: WhatsNewEntry
    let language: UILanguage
    let onDismiss: () -> Void

    @State private var countdown = 3
    @State private var timer: Timer?

    var body: some View {
        VStack(spacing: 12) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.blue)
                Text(L.whatsNewTitle(entry.version))
                    .font(.headline)
                Spacer()
                Text("\(countdown)")
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.secondary)
                    .frame(width: 16)
            }

            // Changes list
            VStack(alignment: .leading, spacing: 4) {
                ForEach(entry.localizedChanges(for: language), id: \.self) { change in
                    HStack(alignment: .top, spacing: 6) {
                        Text("•")
                            .foregroundColor(.blue)
                        Text(change)
                            .font(.callout)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(16)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.15), radius: 8, y: 4)
        .padding(.horizontal, 24)
        .transition(.move(edge: .top).combined(with: .opacity))
        .onTapGesture {
            dismiss()
        }
        .onAppear {
            startCountdown()
        }
        .onDisappear {
            timer?.invalidate()
        }
    }

    private func startCountdown() {
        countdown = 3
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            if countdown > 1 {
                countdown -= 1
            } else {
                dismiss()
            }
        }
    }

    private func dismiss() {
        timer?.invalidate()
        timer = nil
        withAnimation(.easeOut(duration: 0.3)) {
            onDismiss()
        }
    }
}
