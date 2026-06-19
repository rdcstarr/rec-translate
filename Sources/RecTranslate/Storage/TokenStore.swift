import Foundation

/// Stores API tokens in user-only (0600) files under Application Support.
///
/// Chosen over the Keychain so ad-hoc (unsigned) builds don't trigger a Keychain access prompt
/// after every update — Keychain ACLs are tied to the app's code signature, which changes on each
/// ad-hoc rebuild. The tokens authorize the user's own services; a user-only file (plus FileVault
/// at rest) is an appropriate trade-off for the free distribution path.
///
/// - `apiKey` / `setAPIKey(_:)`: the proxy123 bearer token (Google engine).
/// - `openAIKey` / `setOpenAIKey(_:)`: the user's OpenAI API key (OpenAI engine).
enum TokenStore {
    private static let directory: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.recweb.rectranslate", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base
    }()

    private static func read(_ name: String) -> String? {
        let url = directory.appendingPathComponent(name)
        guard
            let data = try? Data(contentsOf: url),
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else { return nil }
        return value
    }

    private static func write(_ value: String, to name: String) throws {
        let url = directory.appendingPathComponent(name)
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? FileManager.default.removeItem(at: url)
            return
        }
        try Data(trimmed.utf8).write(to: url, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
    }

    // MARK: proxy123 bearer token (Google engine)

    static var apiKey: String? { read("api-token") }
    static func setAPIKey(_ value: String) throws { try write(value, to: "api-token") }

    // MARK: OpenAI API key (OpenAI engine)

    static var openAIKey: String? { read("openai-token") }
    static func setOpenAIKey(_ value: String) throws { try write(value, to: "openai-token") }

    // MARK: DeepSeek API key (DeepSeek engine)

    static var deepseekKey: String? { read("deepseek-token") }
    static func setDeepseekKey(_ value: String) throws { try write(value, to: "deepseek-token") }
}
