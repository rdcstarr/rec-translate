import Foundation

/// Stores the proxy123 API token in a user-only (0600) file under Application Support.
///
/// Chosen over the Keychain so ad-hoc (unsigned) builds don't trigger a Keychain access prompt
/// after every update — Keychain ACLs are tied to the app's code signature, which changes on each
/// ad-hoc rebuild. The token is a bearer token to the user's own proxy; a user-only file (plus
/// FileVault at rest) is an appropriate trade-off for the free distribution path.
///
/// Keeps the `apiKey` / `setAPIKey(_:)` surface so call sites are unchanged.
enum TokenStore {
    private static let fileURL: URL = {
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("com.recweb.rectranslate", isDirectory: true)
        try? FileManager.default.createDirectory(at: base, withIntermediateDirectories: true)
        return base.appendingPathComponent("api-token")
    }()

    static var apiKey: String? {
        guard
            let data = try? Data(contentsOf: fileURL),
            let value = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
            !value.isEmpty
        else { return nil }
        return value
    }

    static func setAPIKey(_ value: String) throws {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            try? FileManager.default.removeItem(at: fileURL)
            return
        }
        try Data(trimmed.utf8).write(to: fileURL, options: [.atomic])
        try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: fileURL.path)
    }
}
