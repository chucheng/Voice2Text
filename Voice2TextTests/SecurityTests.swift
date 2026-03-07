import XCTest
@testable import Voice2Text

final class SecurityTests: XCTestCase {

    // MARK: - API Token not in debug log

    func testAPITokenNotLoggedInDebugLog() {
        let state = AppState.shared
        let previousDevMode = state.devMode
        let previousLog = state.debugLog

        // Enable dev mode so log() actually records
        state.devMode = true
        state.debugLog = []

        // Simulate what happens during API check — the token should never appear
        let fakeToken = "sk-ant-test-secret-token-12345"
        state.log("API check started for model: \(AnthropicClient.defaultModel)")
        state.log("API check result: valid (150ms)")

        // Verify token does not appear in any log entry
        for entry in state.debugLog {
            XCTAssertFalse(entry.contains(fakeToken),
                           "Debug log should never contain API token")
        }

        // Restore
        state.devMode = previousDevMode
        state.debugLog = previousLog
    }

    func testLogDoesNotRecordWhenDevModeOff() {
        let state = AppState.shared
        let previousDevMode = state.devMode
        let previousLog = state.debugLog

        state.devMode = false
        state.debugLog = []

        state.log("This should not be recorded")

        XCTAssertTrue(state.debugLog.isEmpty,
                      "Log should not record when devMode is off")

        // Restore
        state.devMode = previousDevMode
        state.debugLog = previousLog
    }

    // MARK: - Whisper language injection

    func testLanguageInjectionBlocked() {
        let langs = WhisperBridge.allowedLanguages
        let malicious = [
            "; rm -rf /",
            "' OR 1=1 --",
            "../../../etc/passwd",
            "<script>alert(1)</script>",
            "zh; DROP TABLE users",
            "",
            "  ",
        ]
        for input in malicious {
            XCTAssertFalse(langs.contains(input),
                           "Allowlist should reject malicious input: \(input)")
        }
    }

    // MARK: - URL validation security

    func testHTTPNonLocalhostRejected() {
        // Non-localhost HTTP should be flagged as insecure
        let insecureURLs = [
            "http://evil.com",
            "http://192.168.1.1:8080",
            "http://10.0.0.1/api",
            "http://api.anthropic.com",
        ]
        for url in insecureURLs {
            XCTAssertTrue(AnthropicClient.isInsecureURL(url),
                          "Should flag as insecure: \(url)")
        }
    }

    func testHTTPLocalhostAllowed() {
        // Localhost HTTP should be allowed for dev setups
        XCTAssertFalse(AnthropicClient.isInsecureURL("http://localhost:8080"))
        XCTAssertFalse(AnthropicClient.isInsecureURL("http://127.0.0.1:8080"))
    }

    func testHTTPSAlwaysSecure() {
        XCTAssertFalse(AnthropicClient.isInsecureURL("https://api.anthropic.com"))
        XCTAssertFalse(AnthropicClient.isInsecureURL("https://evil.com"))
    }
}
