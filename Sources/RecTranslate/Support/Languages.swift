import Foundation

/// Curated languages the popup offers. Codes are ISO 639-1 (lowercase) so they line up with the
/// server; the flag is an emoji (regional-indicator) so no image assets need bundling and it stays
/// crisp at any size.
enum Languages {
    static let targets: [Language] = [
        Language(code: "en", name: "English", flag: "🇬🇧"),
        Language(code: "ro", name: "Romanian", flag: "🇷🇴"),
        Language(code: "fr", name: "French", flag: "🇫🇷"),
        Language(code: "de", name: "German", flag: "🇩🇪"),
        Language(code: "es", name: "Spanish", flag: "🇪🇸"),
        Language(code: "it", name: "Italian", flag: "🇮🇹"),
        Language(code: "pt", name: "Portuguese", flag: "🇵🇹"),
        Language(code: "nl", name: "Dutch", flag: "🇳🇱"),
        Language(code: "ru", name: "Russian", flag: "🇷🇺"),
        Language(code: "uk", name: "Ukrainian", flag: "🇺🇦"),
        Language(code: "pl", name: "Polish", flag: "🇵🇱"),
        Language(code: "cs", name: "Czech", flag: "🇨🇿"),
        Language(code: "sk", name: "Slovak", flag: "🇸🇰"),
        Language(code: "hu", name: "Hungarian", flag: "🇭🇺"),
        Language(code: "bg", name: "Bulgarian", flag: "🇧🇬"),
        Language(code: "el", name: "Greek", flag: "🇬🇷"),
        Language(code: "tr", name: "Turkish", flag: "🇹🇷"),
        Language(code: "ar", name: "Arabic", flag: "🇸🇦"),
        Language(code: "he", name: "Hebrew", flag: "🇮🇱"),
        Language(code: "fa", name: "Persian", flag: "🇮🇷"),
        Language(code: "hi", name: "Hindi", flag: "🇮🇳"),
        Language(code: "ja", name: "Japanese", flag: "🇯🇵"),
        Language(code: "ko", name: "Korean", flag: "🇰🇷"),
        Language(code: "zh", name: "Chinese", flag: "🇨🇳"),
        Language(code: "vi", name: "Vietnamese", flag: "🇻🇳"),
        Language(code: "th", name: "Thai", flag: "🇹🇭"),
        Language(code: "id", name: "Indonesian", flag: "🇮🇩"),
        Language(code: "sv", name: "Swedish", flag: "🇸🇪"),
        Language(code: "nb", name: "Norwegian", flag: "🇳🇴"),
        Language(code: "da", name: "Danish", flag: "🇩🇰"),
        Language(code: "fi", name: "Finnish", flag: "🇫🇮"),
    ]

    /// Sources include the "Detect language" option first.
    static let sources: [Language] = [.auto] + targets

    static func language(for code: String) -> Language {
        if code == Language.auto.code { return .auto }
        return targets.first { $0.code == code } ?? Language(code: code, name: code.uppercased(), flag: "🏳️")
    }

    static func name(for code: String) -> String { language(for: code).name }
    static func flag(for code: String) -> String { language(for: code).flag }
}
