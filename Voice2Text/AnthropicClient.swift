import Foundation

final class AnthropicClient {
    let baseURL: String
    let authToken: String

    static func fromEnvironment() -> AnthropicClient? {
        guard let token = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"],
              let base = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"],
              !token.isEmpty, !base.isEmpty
        else { return nil }

        // Security: warn if base URL is not HTTPS (credentials sent in cleartext)
        if !base.hasPrefix("https://") {
            print("[AnthropicClient] WARNING: ANTHROPIC_BASE_URL uses plaintext HTTP — API key may be intercepted")
        }

        return AnthropicClient(baseURL: base, authToken: token)
    }

    private init(baseURL: String, authToken: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.authToken = authToken
    }

    /// Ask Claude to reformat whisper output with proper punctuation and sentence breaks.
    /// Completion: (reformatted text or nil, error description or nil)
    func reformatText(_ text: String, completion: @escaping (String?, String?) -> Void) {
        let endpoint = "\(baseURL)/v1/messages"
        guard let url = URL(string: endpoint) else {
            completion(nil, "Invalid URL: \(endpoint)")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-opus-4-6",
            "max_tokens": 4096,
            "messages": [
                [
                    "role": "user",
                    "content": """
                    You are a text reformatter. The following text is raw output from a speech-to-text engine (Whisper). \
                    It may contain Chinese and English mixed together. Your job:
                    1. Add proper punctuation (。，！？for Chinese; .,!? for English)
                    2. Fix sentence boundaries — break into natural sentences
                    3. Do NOT change any words, do NOT translate, do NOT add or remove content
                    4. Keep the original language as-is (Chinese stays Chinese, English stays English)
                    5. Return ONLY the reformatted text, nothing else — no explanation, no markdown

                    Raw text:
                    \(text)
                    """
                ]
            ]
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                completion(nil, "Network error: \(error.localizedDescription)")
                return
            }

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            guard let data else {
                completion(nil, "No data received (HTTP \(statusCode))")
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                completion(nil, "Invalid JSON (HTTP \(statusCode)): \(String(raw.prefix(200)))")
                return
            }

            // Check for API error response
            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                completion(nil, "API error (HTTP \(statusCode)): \(message)")
                return
            }

            guard let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String
            else {
                completion(nil, "Unexpected response format (HTTP \(statusCode)): \(String(String(describing: json).prefix(200)))")
                return
            }

            completion(text.trimmingCharacters(in: .whitespacesAndNewlines), nil)
        }.resume()
    }
}
