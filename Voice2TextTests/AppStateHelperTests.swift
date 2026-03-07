import XCTest
@testable import Voice2Text

final class AppStateHelperTests: XCTestCase {

    // MARK: - textContainsChinese

    func testChineseOnly() {
        XCTAssertTrue(AppState.textContainsChinese("你好世界"))
    }

    func testEnglishOnly() {
        XCTAssertFalse(AppState.textContainsChinese("Hello World"))
    }

    func testMixedChineseEnglish() {
        XCTAssertTrue(AppState.textContainsChinese("Hello你好World"))
    }

    func testEmptyString() {
        XCTAssertFalse(AppState.textContainsChinese(""))
    }

    func testJapaneseKanji() {
        // Japanese Kanji share CJK Unified Ideographs range — should return true
        XCTAssertTrue(AppState.textContainsChinese("漢字"))
    }

    func testJapaneseHiraganaOnly() {
        // Hiragana is NOT in CJK Unified Ideographs
        XCTAssertFalse(AppState.textContainsChinese("ひらがな"))
    }

    func testKoreanOnly() {
        // Hangul is NOT in CJK Unified Ideographs
        XCTAssertFalse(AppState.textContainsChinese("한국어"))
    }

    func testNumbersAndPunctuation() {
        XCTAssertFalse(AppState.textContainsChinese("12345!@#$%"))
    }

    func testCJKExtensionA() {
        // U+3400 is in CJK Extension A
        XCTAssertTrue(AppState.textContainsChinese("\u{3400}"))
    }

    func testCJKCompatibility() {
        // U+F900 is in CJK Compatibility Ideographs
        XCTAssertTrue(AppState.textContainsChinese("\u{F900}"))
    }

    func testEmoji() {
        XCTAssertFalse(AppState.textContainsChinese("😀🎉"))
    }

    // MARK: - containsUnexpectedLanguage

    func testUnexpectedLanguageEmpty() {
        XCTAssertFalse(AppState.containsUnexpectedLanguage(""))
    }

    func testUnexpectedLanguagePureEnglish() {
        // No Chinese chars → false (don't trigger retry)
        XCTAssertFalse(AppState.containsUnexpectedLanguage("Hello World"))
    }

    func testUnexpectedLanguagePureChinese() {
        // All chars in expected range
        XCTAssertFalse(AppState.containsUnexpectedLanguage("你好世界"))
    }

    func testUnexpectedLanguageChineseWithEnglish() {
        // ASCII + CJK are both expected
        XCTAssertFalse(AppState.containsUnexpectedLanguage("Hello你好World"))
    }

    func testUnexpectedLanguageChineseWithJapaneseHiragana() {
        // Has Chinese chars + Hiragana (unexpected) → true
        XCTAssertTrue(AppState.containsUnexpectedLanguage("你好ひらがな"))
    }

    func testUnexpectedLanguageChineseWithKorean() {
        // Has Chinese chars + Hangul (unexpected) → true
        XCTAssertTrue(AppState.containsUnexpectedLanguage("你好한국어"))
    }

    func testUnexpectedLanguageChineseWithFullwidthPunct() {
        // Fullwidth punctuation is in expected range
        XCTAssertFalse(AppState.containsUnexpectedLanguage("你好，世界！"))
    }

    // MARK: - convertScript

    func testConvertToTraditional() {
        let state = AppState.shared
        state.outputScript = .traditional
        let result = state.convertScript("简体中文")
        XCTAssertEqual(result, "簡體中文")
    }

    func testConvertToSimplified() {
        let state = AppState.shared
        state.outputScript = .simplified
        let result = state.convertScript("繁體中文")
        XCTAssertEqual(result, "繁体中文")
    }

    func testConvertEnglishUnchanged() {
        let state = AppState.shared
        state.outputScript = .traditional
        let result = state.convertScript("Hello World")
        XCTAssertEqual(result, "Hello World")
    }

    func testConvertEmptyString() {
        let state = AppState.shared
        state.outputScript = .simplified
        let result = state.convertScript("")
        XCTAssertEqual(result, "")
    }
}
