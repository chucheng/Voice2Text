import Foundation

// MARK: - API Check Result

enum APICheckResult: Equatable {
    case unchecked
    case checking
    case valid(latencyMs: Int)
    case invalid(message: String)

    var isValid: Bool {
        if case .valid = self { return true }
        return false
    }
}

// MARK: - AnthropicClient

final class AnthropicClient {
    let baseURL: String
    let authToken: String
    let model: String

    static let defaultModel = "claude-sonnet-4-20250514"

    static let revisePrompt = """
        Revise the following text. Output only the revised text with no preamble, explanation, or commentary. \
        Preserve all markdown formatting, lists, headings, and code blocks exactly as-is. \
        Improve clarity and flow while keeping the original meaning. \
        Handle Chinese-English mixed text naturally:

        """

    /// Validate that a base URL has a valid scheme (http or https).
    static func isValidBaseURL(_ urlString: String) -> Bool {
        guard !urlString.isEmpty else { return false }
        return urlString.hasPrefix("https://") || urlString.hasPrefix("http://")
    }

    /// Returns true if the URL uses plaintext HTTP to a non-localhost host.
    static func isInsecureURL(_ urlString: String) -> Bool {
        guard urlString.hasPrefix("http://") else { return false }
        let isLocalhost = urlString.hasPrefix("http://127.0.0.1") || urlString.hasPrefix("http://localhost")
        return !isLocalhost
    }

    init(baseURL: String, authToken: String, model: String = AnthropicClient.defaultModel) {
        self.baseURL = baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
        self.authToken = authToken
        self.model = model
    }

    /// Lightweight API check: send a tiny message and verify we get a valid response.
    func checkAPI(completion: @escaping (APICheckResult) -> Void) {
        let endpoint = "\(baseURL)/v1/messages"
        guard let url = URL(string: endpoint) else {
            completion(.invalid(message: "Invalid URL"))
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 15

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 1,
            "messages": [
                ["role": "user", "content": "hi"]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        let start = CFAbsoluteTimeGetCurrent()
        URLSession.shared.dataTask(with: request) { data, response, error in
            let latencyMs = Int((CFAbsoluteTimeGetCurrent() - start) * 1000)

            if let error {
                DispatchQueue.main.async {
                    completion(.invalid(message: error.localizedDescription))
                }
                return
            }

            let httpResponse = response as? HTTPURLResponse
            let statusCode = httpResponse?.statusCode ?? 0

            guard let data else {
                DispatchQueue.main.async {
                    completion(.invalid(message: "No data (HTTP \(statusCode))"))
                }
                return
            }

            DispatchQueue.main.async {
                switch statusCode {
                case 200:
                    completion(.valid(latencyMs: latencyMs))
                case 401, 403:
                    completion(.invalid(message: "Invalid API key or unauthorized"))
                case 404:
                    completion(.invalid(message: "Model not found or no access"))
                case 429:
                    completion(.invalid(message: "Rate limited, try again later"))
                case 500...599:
                    completion(.invalid(message: "Server error (HTTP \(statusCode))"))
                default:
                    let raw = String(data: data, encoding: .utf8) ?? ""
                    completion(.invalid(message: "HTTP \(statusCode): \(String(raw.prefix(100)))"))
                }
            }
        }.resume()
    }

    /// Send text through Claude for revision. Returns revised text or nil + error.
    func reviseText(_ text: String, completion: @escaping (String?, String?) -> Void) {
        let endpoint = "\(baseURL)/v1/messages"
        guard let url = URL(string: endpoint) else {
            completion(nil, "Invalid URL")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(authToken, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.timeoutInterval = 30

        let body: [String: Any] = [
            "model": model,
            "max_tokens": 4096,
            "messages": [
                ["role": "user", "content": Self.revisePrompt + text]
            ]
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(nil, "Network error: \(error.localizedDescription)") }
                return
            }

            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? 0

            guard let data else {
                DispatchQueue.main.async { completion(nil, "No data (HTTP \(statusCode))") }
                return
            }

            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                let raw = String(data: data, encoding: .utf8) ?? "<binary>"
                DispatchQueue.main.async { completion(nil, "Invalid JSON (HTTP \(statusCode)): \(String(raw.prefix(200)))") }
                return
            }

            if let errorObj = json["error"] as? [String: Any],
               let message = errorObj["message"] as? String {
                DispatchQueue.main.async { completion(nil, "API error (HTTP \(statusCode)): \(message)") }
                return
            }

            guard let content = json["content"] as? [[String: Any]],
                  let firstBlock = content.first,
                  let text = firstBlock["text"] as? String
            else {
                DispatchQueue.main.async { completion(nil, "Unexpected response format (HTTP \(statusCode))") }
                return
            }

            DispatchQueue.main.async { completion(text.trimmingCharacters(in: .whitespacesAndNewlines), nil) }
        }.resume()
    }
}
