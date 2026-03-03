import Foundation
import AppKit

/// HTTP client for the local Chinese punctuation restoration server.
final class PunctuationClient {
    static let shared = PunctuationClient()

    private let baseURL = URL(string: "http://127.0.0.1:18230")!
    private let session: URLSession

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        session = URLSession(configuration: config)
    }

    /// Check if the punctuation server is running.
    func checkHealth(completion: @escaping (Bool) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("health"))
        request.timeoutInterval = 3
        session.dataTask(with: request) { data, response, error in
            let ok = (response as? HTTPURLResponse)?.statusCode == 200
            DispatchQueue.main.async { completion(ok) }
        }.resume()
    }

    /// Send text to the server for punctuation restoration.
    func restore(_ text: String, completion: @escaping (String?, String?) -> Void) {
        var request = URLRequest(url: baseURL.appendingPathComponent("restore"))
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 30

        let body = ["text": text]
        guard let jsonData = try? JSONSerialization.data(withJSONObject: body) else {
            DispatchQueue.main.async { completion(nil, "Failed to encode request") }
            return
        }
        request.httpBody = jsonData

        session.dataTask(with: request) { data, response, error in
            if let error {
                DispatchQueue.main.async { completion(nil, error.localizedDescription) }
                return
            }
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let restored = json["text"] as? String else {
                DispatchQueue.main.async { completion(nil, "Invalid response") }
                return
            }
            DispatchQueue.main.async { completion(restored, nil) }
        }.resume()
    }

    // MARK: - Server Launch

    /// Installation path inside Application Support (sandbox-safe).
    static let appSupportInstallURL: URL = {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("Voice2Text/PunctuationServer.app")
    }()

    /// Search paths for PunctuationServer.app
    private static let searchPaths: [URL] = {
        var paths: [URL] = []

        // ~/Library/Application Support/Voice2Text/PunctuationServer.app (in-app install)
        paths.append(appSupportInstallURL)

        // /Applications/
        paths.append(URL(fileURLWithPath: "/Applications/PunctuationServer.app"))

        // ~/Applications/
        let home = FileManager.default.homeDirectoryForCurrentUser
        paths.append(home.appendingPathComponent("Applications/PunctuationServer.app"))

        // Same directory as Voice2Text.app
        let bundlePath = Bundle.main.bundleURL.deletingLastPathComponent()
        paths.append(bundlePath.appendingPathComponent("PunctuationServer.app"))

        // scripts/dist/ relative to the Voice2Text.app bundle (dev builds)
        if let resourcePath = Bundle.main.resourceURL?.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent() {
            paths.append(resourcePath.appendingPathComponent("scripts/dist/PunctuationServer.app"))
        }

        return paths
    }()

    /// Find PunctuationServer.app in known locations.
    private static func findServerApp() -> URL? {
        for path in searchPaths {
            if FileManager.default.fileExists(atPath: path.path) {
                return path
            }
        }
        return nil
    }

    /// Verify that the app bundle at the given URL has a valid code signature.
    /// Returns true if signed (ad-hoc or with identity), false if unsigned or tampered.
    private static func isCodeSignatureValid(at url: URL) -> Bool {
        var staticCode: SecStaticCode?
        let createStatus = SecStaticCodeCreateWithPath(url as CFURL, [], &staticCode)
        guard createStatus == errSecSuccess, let code = staticCode else { return false }
        // kSecCSBasicValidateOnly checks that the signature is intact (not tampered)
        let validateStatus = SecStaticCodeCheckValidity(code, SecCSFlags(rawValue: 0), nil)
        return validateStatus == errSecSuccess
    }

    /// Launch PunctuationServer.app if found. Returns true if launch was attempted.
    @discardableResult
    static func launchServer() -> Bool {
        guard let appURL = findServerApp() else { return false }

        // Security: verify code signature before launching external app
        guard isCodeSignatureValid(at: appURL) else {
            print("[PunctuationClient] REJECTED: PunctuationServer.app at \(appURL.path) has invalid or missing code signature")
            return false
        }

        let config = NSWorkspace.OpenConfiguration()
        config.activates = false  // Launch in background
        NSWorkspace.shared.openApplication(at: appURL, configuration: config) { _, error in
            if let error {
                print("[PunctuationClient] Failed to launch server: \(error.localizedDescription)")
            } else {
                print("[PunctuationClient] Launched PunctuationServer.app from \(appURL.path)")
            }
        }
        return true
    }
}
