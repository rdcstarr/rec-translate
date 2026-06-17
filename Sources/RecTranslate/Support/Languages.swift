import Foundation

/// Curated list of languages the popup offers. Codes are ISO 639-1 (lowercase) so they
/// line up with rec-app's `languages` table; if the server rejects one it returns a 422
/// that the UI surfaces gracefully.
enum Languages {
    /// Valid translation targets (and explicit sources).
    static let targets: [Language] = [
        Language(code: "en", name: "English"),
        Language(code: "ro", name: "Romanian"),
        Language(code: "fr", name: "French"),
        Language(code: "de", name: "German"),
        Language(code: "es", name: "Spanish"),
        Language(code: "it", name: "Italian"),
        Language(code: "pt", name: "Portuguese"),
        Language(code: "nl", name: "Dutch"),
        Language(code: "ru", name: "Russian"),
        Language(code: "uk", name: "Ukrainian"),
        Language(code: "pl", name: "Polish"),
        Language(code: "cs", name: "Czech"),
        Language(code: "sk", name: "Slovak"),
        Language(code: "hu", name: "Hungarian"),
        Language(code: "bg", name: "Bulgarian"),
        Language(code: "el", name: "Greek"),
        Language(code: "tr", name: "Turkish"),
        Language(code: "ar", name: "Arabic"),
        Language(code: "he", name: "Hebrew"),
        Language(code: "fa", name: "Persian"),
        Language(code: "hi", name: "Hindi"),
        Language(code: "ja", name: "Japanese"),
        Language(code: "ko", name: "Korean"),
        Language(code: "zh", name: "Chinese"),
        Language(code: "vi", name: "Vietnamese"),
        Language(code: "th", name: "Thai"),
        Language(code: "id", name: "Indonesian"),
        Language(code: "sv", name: "Swedish"),
        Language(code: "nb", name: "Norwegian"),
        Language(code: "da", name: "Danish"),
        Language(code: "fi", name: "Finnish"),
    ]

    /// Sources include the on-device "Detect language" option first.
    static let sources: [Language] = [.auto] + targets

    /// Friendly name for a code (falls back to the uppercased code).
    static func name(for code: String) -> String {
        if code == Language.auto.code { return Language.auto.name }
        return targets.first { $0.code == code }?.name ?? code.uppercased()
    }

    static func language(for code: String) -> Language {
        if code == Language.auto.code { return .auto }
        return targets.first { $0.code == code } ?? Language(code: code, name: code.uppercased())
    }
}
