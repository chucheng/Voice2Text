import XCTest
@testable import Voice2Text

final class WordPieceTokenizerTests: XCTestCase {

    // The tokenizer loads vocab.txt from Bundle.main (available via TEST_HOST)
    private var tokenizer: WordPieceTokenizer!

    override func setUpWithError() throws {
        tokenizer = WordPieceTokenizer()
        // If vocab.txt not in bundle, skip all tests
        try XCTSkipIf(tokenizer == nil, "WordPieceTokenizer requires vocab.txt in app bundle")
    }

    // MARK: - Init

    func testVocabLoaded() {
        XCTAssertGreaterThan(tokenizer.vocabSize, 20000, "Vocab should have ~21K tokens")
    }

    // MARK: - Chinese single-character tokenization

    func testChineseSingleChars() {
        let result = tokenizer.encode("你好")
        // Each Chinese char should be its own token (plus [CLS] and [SEP])
        // "你" → 1 token, "好" → 1 token → offsets count = 2
        XCTAssertEqual(result.offsets.count, 2, "Two Chinese chars should produce 2 content tokens")
    }

    func testChineseOffsets() {
        let result = tokenizer.encode("你好世界")
        XCTAssertEqual(result.offsets.count, 4)
        // Each char maps to sequential positions
        XCTAssertEqual(result.offsets[0].start, 0)
        XCTAssertEqual(result.offsets[0].end, 1)
        XCTAssertEqual(result.offsets[1].start, 1)
        XCTAssertEqual(result.offsets[1].end, 2)
        XCTAssertEqual(result.offsets[2].start, 2)
        XCTAssertEqual(result.offsets[2].end, 3)
        XCTAssertEqual(result.offsets[3].start, 3)
        XCTAssertEqual(result.offsets[3].end, 4)
    }

    // MARK: - English tokenization

    func testEnglishWord() {
        let result = tokenizer.encode("hello")
        // "hello" should produce at least 1 token
        XCTAssertGreaterThanOrEqual(result.offsets.count, 1)
    }

    func testEnglishLowercased() {
        // WordPiece tokenizer lowercases input
        let result1 = tokenizer.encode("Hello")
        let result2 = tokenizer.encode("hello")
        // Should produce same tokens (both lowercased)
        XCTAssertEqual(result1.inputIds, result2.inputIds)
    }

    func testEnglishMultipleWords() {
        let result = tokenizer.encode("hello world")
        // "hello" and "world" are separate words → at least 2 groups of tokens
        XCTAssertGreaterThanOrEqual(result.offsets.count, 2)
    }

    // MARK: - Mixed Chinese + English

    func testMixedChineseEnglish() {
        let result = tokenizer.encode("Hello你好")
        // "hello" (lowercased) → some tokens, "你" → 1, "好" → 1
        XCTAssertGreaterThanOrEqual(result.offsets.count, 3)
    }

    func testMixedWithSpaces() {
        let result = tokenizer.encode("你好 World 世界")
        // "你" "好" "world" "世" "界" → at least 5 token groups
        XCTAssertGreaterThanOrEqual(result.offsets.count, 4)
    }

    // MARK: - Empty input

    func testEmptyString() {
        let result = tokenizer.encode("")
        // No content tokens, just [CLS] + [SEP] + padding
        XCTAssertEqual(result.offsets.count, 0)
        // inputIds should start with CLS, then SEP, then padding
        XCTAssertEqual(result.inputIds.count, 512) // default maxLength
        XCTAssertEqual(result.attentionMask.count, 512)
    }

    // MARK: - Padding and attention mask

    func testPaddingToMaxLength() {
        let result = tokenizer.encode("hi", maxLength: 128)
        XCTAssertEqual(result.inputIds.count, 128)
        XCTAssertEqual(result.attentionMask.count, 128)
    }

    func testAttentionMaskCorrect() {
        let result = tokenizer.encode("你好", maxLength: 16)
        // [CLS] + 2 tokens + [SEP] = 4 active → attention mask has 4 ones, rest zeros
        let activeCount = result.attentionMask.filter { $0 == 1 }.count
        XCTAssertEqual(activeCount, 4, "Should have CLS + 2 content tokens + SEP = 4 active")
        let padCount = result.attentionMask.filter { $0 == 0 }.count
        XCTAssertEqual(padCount, 12, "Remaining 12 should be padding")
    }

    // MARK: - MaxLength truncation

    func testTruncationAtMaxLength() {
        // Generate long input that exceeds maxLength
        let longText = String(repeating: "你", count: 600)
        let result = tokenizer.encode(longText, maxLength: 32)

        XCTAssertEqual(result.inputIds.count, 32)
        // Content tokens = maxLength - 2 (for CLS + SEP) = 30
        XCTAssertEqual(result.offsets.count, 30)
    }

    // MARK: - countTokens

    func testCountTokensMatchesEncode() {
        let texts = ["你好世界", "Hello World", "Hello你好", ""]
        for text in texts {
            let count = tokenizer.countTokens(text)
            let encoded = tokenizer.encode(text)
            XCTAssertEqual(count, encoded.offsets.count,
                           "countTokens should match encode offsets count for '\(text)'")
        }
    }

    func testCountTokensChinese() {
        let count = tokenizer.countTokens("你好世界")
        XCTAssertEqual(count, 4, "4 Chinese chars → 4 tokens")
    }

    // MARK: - decode

    func testDecodeKnownToken() {
        // [CLS] is typically token 101 in BERT vocab
        let result = tokenizer.encode("你好")
        let clsId = result.inputIds[0]
        let decoded = tokenizer.decode(clsId)
        XCTAssertEqual(decoded, "[CLS]")
    }

    func testDecodeUnknownId() {
        let decoded = tokenizer.decode(-1)
        XCTAssertEqual(decoded, "[UNK]")
    }

    func testDecodeMaxId() {
        let decoded = tokenizer.decode(Int32(tokenizer.vocabSize + 100))
        XCTAssertEqual(decoded, "[UNK]")
    }

    // MARK: - Special characters

    func testPunctuation() {
        let result = tokenizer.encode("你好！世界。")
        // Should not crash, produce reasonable tokens
        XCTAssertGreaterThan(result.offsets.count, 0)
    }

    func testNumbers() {
        let result = tokenizer.encode("12345")
        XCTAssertGreaterThan(result.offsets.count, 0)
    }

    func testEmoji() {
        // Emoji may produce [UNK] tokens but should not crash
        let result = tokenizer.encode("😀hello")
        XCTAssertGreaterThan(result.offsets.count, 0)
    }

    // MARK: - Unicode normalization

    func testUnicodeNFCNormalization() {
        // é can be represented as single codepoint or decomposed (e + combining accent)
        let composed = "caf\u{00E9}"    // é as single codepoint
        let decomposed = "cafe\u{0301}"  // e + combining acute accent
        let result1 = tokenizer.encode(composed)
        let result2 = tokenizer.encode(decomposed)
        // After NFC normalization, both should produce same tokens
        XCTAssertEqual(result1.inputIds, result2.inputIds,
                       "NFC normalization should make composed and decomposed produce same tokens")
    }

    // MARK: - CLS/SEP structure

    func testCLSSEPStructure() {
        let result = tokenizer.encode("你好", maxLength: 16)
        // First token should be [CLS]
        XCTAssertEqual(tokenizer.decode(result.inputIds[0]), "[CLS]")

        // Find [SEP] — should be after content tokens
        let activeCount = result.attentionMask.filter { $0 == 1 }.count
        let sepIndex = activeCount - 1
        XCTAssertEqual(tokenizer.decode(result.inputIds[sepIndex]), "[SEP]")
    }

    // MARK: - Whitespace handling

    func testMultipleSpaces() {
        let result = tokenizer.encode("hello   world")
        // Multiple spaces treated as whitespace separators
        XCTAssertGreaterThanOrEqual(result.offsets.count, 2)
    }

    func testLeadingTrailingSpaces() {
        let result = tokenizer.encode("  hello  ")
        XCTAssertGreaterThanOrEqual(result.offsets.count, 1)
    }
}
