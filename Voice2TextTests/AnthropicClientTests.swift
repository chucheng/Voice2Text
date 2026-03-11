import XCTest
@testable import Voice2Text

final class AnthropicClientTests: XCTestCase {

    // MARK: - isValidBaseURL

    func testValidHTTPS() {
        XCTAssertTrue(AnthropicClient.isValidBaseURL("https://api.anthropic.com"))
    }

    func testValidHTTPLocalhost() {
        XCTAssertTrue(AnthropicClient.isValidBaseURL("http://localhost:8080"))
    }

    func testValidHTTPRemote() {
        // isValidBaseURL only checks scheme prefix, not security
        XCTAssertTrue(AnthropicClient.isValidBaseURL("http://example.com"))
    }

    func testInvalidEmpty() {
        XCTAssertFalse(AnthropicClient.isValidBaseURL(""))
    }

    func testInvalidNoScheme() {
        XCTAssertFalse(AnthropicClient.isValidBaseURL("api.anthropic.com"))
    }

    func testInvalidFTP() {
        XCTAssertFalse(AnthropicClient.isValidBaseURL("ftp://files.example.com"))
    }

    func testInvalidRandomString() {
        XCTAssertFalse(AnthropicClient.isValidBaseURL("not a url"))
    }

    // MARK: - isInsecureURL

    func testSecureHTTPS() {
        XCTAssertFalse(AnthropicClient.isInsecureURL("https://api.anthropic.com"))
    }

    func testInsecureHTTPRemote() {
        XCTAssertTrue(AnthropicClient.isInsecureURL("http://evil.com"))
    }

    func testInsecureHTTPIP() {
        XCTAssertTrue(AnthropicClient.isInsecureURL("http://192.168.1.1:8080"))
    }

    func testSecureHTTPLocalhost() {
        XCTAssertFalse(AnthropicClient.isInsecureURL("http://localhost:8080"))
    }

    func testSecureHTTP127() {
        XCTAssertFalse(AnthropicClient.isInsecureURL("http://127.0.0.1:8080"))
    }

    // MARK: - Init trailing slash normalization

    func testInitStripsTrailingSlash() {
        let client = AnthropicClient(baseURL: "https://api.example.com/", authToken: "test")
        XCTAssertEqual(client.baseURL, "https://api.example.com")
    }

    func testInitKeepsCleanURL() {
        let client = AnthropicClient(baseURL: "https://api.example.com", authToken: "test")
        XCTAssertEqual(client.baseURL, "https://api.example.com")
    }

    // MARK: - APICheckResult

    func testAPICheckResultEquality() {
        XCTAssertEqual(APICheckResult.unchecked, APICheckResult.unchecked)
        XCTAssertEqual(APICheckResult.checking, APICheckResult.checking)
        XCTAssertEqual(APICheckResult.valid(latencyMs: 100), APICheckResult.valid(latencyMs: 100))
        XCTAssertNotEqual(APICheckResult.valid(latencyMs: 100), APICheckResult.valid(latencyMs: 200))
        XCTAssertEqual(APICheckResult.invalid(message: "err"), APICheckResult.invalid(message: "err"))
    }

    func testAPICheckResultIsValid() {
        XCTAssertTrue(APICheckResult.valid(latencyMs: 50).isValid)
        XCTAssertFalse(APICheckResult.unchecked.isValid)
        XCTAssertFalse(APICheckResult.checking.isValid)
        XCTAssertFalse(APICheckResult.invalid(message: "fail").isValid)
    }

    // MARK: - revisePrompt content

    func testRevisePromptNonEmpty() {
        XCTAssertFalse(AnthropicClient.revisePrompt.isEmpty)
    }

    func testRevisePromptContainsPunctuationInstruction() {
        let prompt = AnthropicClient.revisePrompt
        XCTAssertTrue(prompt.contains("punctuation"),
                      "Revise prompt should mention punctuation")
    }

    func testRevisePromptContainsCriticalInstruction() {
        let prompt = AnthropicClient.revisePrompt
        XCTAssertTrue(prompt.contains("CRITICAL"),
                      "Revise prompt should contain CRITICAL instruction")
    }

    func testRevisePromptMentionsTranscript() {
        let prompt = AnthropicClient.revisePrompt
        XCTAssertTrue(prompt.lowercased().contains("transcript"),
                      "Revise prompt should mention transcript")
    }

    func testRevisePromptCoversMultipleLanguages() {
        let prompt = AnthropicClient.revisePrompt.lowercased()
        XCTAssertTrue(prompt.contains("english"), "Should cover English")
        XCTAssertTrue(prompt.contains("chinese"),
                      "Should cover Chinese")
        XCTAssertTrue(prompt.contains("mixed"), "Should cover mixed-language text")
    }

    func testDefaultModel() {
        XCTAssertFalse(AnthropicClient.defaultModel.isEmpty)
        XCTAssertTrue(AnthropicClient.defaultModel.contains("claude"),
                      "Default model should be a Claude model")
    }
}
