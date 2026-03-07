import XCTest
@testable import Voice2Text

final class WhisperBridgeTests: XCTestCase {

    // MARK: - Allowed Languages

    func testAllowedLanguagesContainsCommon() {
        let langs = WhisperBridge.allowedLanguages
        XCTAssertTrue(langs.contains("auto"))
        XCTAssertTrue(langs.contains("zh"))
        XCTAssertTrue(langs.contains("en"))
        XCTAssertTrue(langs.contains("ja"))
        XCTAssertTrue(langs.contains("ko"))
        XCTAssertTrue(langs.contains("fr"))
        XCTAssertTrue(langs.contains("de"))
        XCTAssertTrue(langs.contains("es"))
    }

    func testAllowedLanguagesRejectsInvalid() {
        let langs = WhisperBridge.allowedLanguages
        XCTAssertFalse(langs.contains(""))
        XCTAssertFalse(langs.contains("invalid"))
        XCTAssertFalse(langs.contains("xx"))
        XCTAssertFalse(langs.contains("; rm -rf /"))
    }

    func testAllowedLanguagesCount() {
        // Should have ~99 languages + "auto"
        XCTAssertGreaterThan(WhisperBridge.allowedLanguages.count, 90)
    }
}
