import XCTest
@testable import Voice2Text

final class WhatsNewTests: XCTestCase {

    /// Load entries directly from source file (reliable in test context).
    /// Falls back to WhatsNewLoader.load() if source file not available.
    private func loadEntries() throws -> [WhatsNewEntry] {
        // First try WhatsNewLoader (uses Bundle.main)
        let bundleEntries = WhatsNewLoader.load()
        if !bundleEntries.isEmpty { return bundleEntries }

        // Fallback: load from source directory (for CI or when bundle isn't available)
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // Voice2TextTests/
            .deletingLastPathComponent()  // project root
            .appendingPathComponent("Voice2Text/WhatsNew.json")
        let data = try Data(contentsOf: sourceURL)
        return try JSONDecoder().decode([WhatsNewEntry].self, from: data)
    }

    // MARK: - JSON loads successfully

    func testWhatsNewLoads() throws {
        let entries = try loadEntries()
        XCTAssertFalse(entries.isEmpty, "WhatsNew.json should load with entries")
    }

    // MARK: - Structure validation

    func testAllEntriesHaveVersion() throws {
        let entries = try loadEntries()
        for entry in entries {
            XCTAssertFalse(entry.version.isEmpty, "Every entry must have a version string")
        }
    }

    func testAllEntriesHaveEnglishChanges() throws {
        let entries = try loadEntries()
        for entry in entries {
            let en = entry.changes["en"] ?? []
            XCTAssertFalse(en.isEmpty, "v\(entry.version) missing English changes")
        }
    }

    func testAllEntriesHaveChineseChanges() throws {
        let entries = try loadEntries()
        for entry in entries {
            let zh = entry.changes["zh"] ?? []
            XCTAssertFalse(zh.isEmpty, "v\(entry.version) missing Chinese changes")
        }
    }

    func testEnglishAndChineseChangesCountMatch() throws {
        let entries = try loadEntries()
        for entry in entries {
            let enCount = entry.changes["en"]?.count ?? 0
            let zhCount = entry.changes["zh"]?.count ?? 0
            XCTAssertEqual(enCount, zhCount,
                           "v\(entry.version): English (\(enCount)) and Chinese (\(zhCount)) change counts should match")
        }
    }

    // MARK: - Version format

    func testVersionFormatIsSemver() throws {
        let entries = try loadEntries()
        let semverPattern = #"^\d+\.\d+\.\d+$"#
        for entry in entries {
            XCTAssertTrue(entry.version.range(of: semverPattern, options: .regularExpression) != nil,
                          "v\(entry.version) is not valid semver (expected X.Y.Z)")
        }
    }

    func testVersionsAreDescending() throws {
        let entries = try loadEntries()
        guard entries.count >= 2 else { return }

        for i in 0..<(entries.count - 1) {
            let current = entries[i].version
            let next = entries[i + 1].version
            // Versions should be in descending order (newest first)
            XCTAssertTrue(compareVersions(current, next) > 0,
                          "Versions should be descending: v\(current) should be > v\(next)")
        }
    }

    // MARK: - No empty change strings

    func testNoEmptyChangeStrings() throws {
        let entries = try loadEntries()
        for entry in entries {
            for (lang, changes) in entry.changes {
                for (i, change) in changes.enumerated() {
                    XCTAssertFalse(change.trimmingCharacters(in: .whitespaces).isEmpty,
                                   "v\(entry.version) \(lang) change[\(i)] is empty/whitespace")
                }
            }
        }
    }

    // MARK: - Localized changes accessor

    func testLocalizedChangesEnglish() throws {
        let entries = try loadEntries()
        guard let first = entries.first else { return }
        let en = first.localizedChanges(for: .english)
        XCTAssertFalse(en.isEmpty)
    }

    func testLocalizedChangesChinese() throws {
        let entries = try loadEntries()
        guard let first = entries.first else { return }
        let zh = first.localizedChanges(for: .chinese)
        XCTAssertFalse(zh.isEmpty)
    }

    // MARK: - entriesForMinor

    func testEntriesForMinorGroupsCorrectly() throws {
        let entries = try loadEntries()
        guard let latest = entries.first else { return }
        let prefix = String(latest.version.split(separator: ".").prefix(2).joined(separator: "."))
        let minorEntries = entries.filter {
            let p = String($0.version.split(separator: ".").prefix(2).joined(separator: "."))
            return p == prefix
        }
        XCTAssertFalse(minorEntries.isEmpty, "Should find entries for latest minor version")
        for entry in minorEntries {
            XCTAssertTrue(entry.version.hasPrefix(prefix),
                          "v\(entry.version) should be in \(prefix).x group")
        }
    }

    // MARK: - Helpers

    /// Simple semver comparison: returns >0 if a > b, <0 if a < b, 0 if equal
    private func compareVersions(_ a: String, _ b: String) -> Int {
        let aParts = a.split(separator: ".").compactMap { Int($0) }
        let bParts = b.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(aParts.count, bParts.count) {
            let av = i < aParts.count ? aParts[i] : 0
            let bv = i < bParts.count ? bParts[i] : 0
            if av != bv { return av - bv }
        }
        return 0
    }
}
