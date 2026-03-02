import Foundation

final class AnthropicClient {
    let baseURL: String
    let authToken: String

    static func fromEnvironment() -> AnthropicClient? {
        guard let token = ProcessInfo.processInfo.environment["ANTHROPIC_AUTH_TOKEN"],
              let base = ProcessInfo.processInfo.environment["ANTHROPIC_BASE_URL"],
              !token.isEmpty, !base.isEmpty
        else { return nil }
        return AnthropicClient(baseURL: base, authToken: token)
    }

    private init(baseURL: String, authToken: String) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.authToken = authToken
    }

    /// Ask Claude to reformat whisper output with proper punctuation and sentence breaks.
    func reformatText(_ text: String, completion: @escaping (String?) -> Void) {
        let endpoint = "\(baseURL)/v1/messages"
        guard let url = URL(string: endpoint) else {
            completion(nil)
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": "claude-haiku-4-5-20251001",
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
            guard let data, error == nil,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String
            else {
                completion(nil)
                return
            }
            completion(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }.resume()
    }
}
