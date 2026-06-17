import Foundation

/// Curated languages the popup offers (the full Google Translate set). Codes are the ones Google
/// accepts; the flag is an emoji fallback (the real flag image is loaded by code via `FlagImage`,
/// rasterized from `Resources/Flags-src/<code>.svg`).
enum Languages {
    static let targets: [Language] = [
        // Common languages first.
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

        // Everything else, alphabetical by name.
        Language(code: "af", name: "Afrikaans", flag: "🇿🇦"),
        Language(code: "sq", name: "Albanian", flag: "🇦🇱"),
        Language(code: "am", name: "Amharic", flag: "🇪🇹"),
        Language(code: "hy", name: "Armenian", flag: "🇦🇲"),
        Language(code: "az", name: "Azerbaijani", flag: "🇦🇿"),
        Language(code: "eu", name: "Basque", flag: "🇪🇸"),
        Language(code: "be", name: "Belarusian", flag: "🇧🇾"),
        Language(code: "bn", name: "Bengali", flag: "🇧🇩"),
        Language(code: "bs", name: "Bosnian", flag: "🇧🇦"),
        Language(code: "my", name: "Burmese", flag: "🇲🇲"),
        Language(code: "ca", name: "Catalan", flag: "🇪🇸"),
        Language(code: "ceb", name: "Cebuano", flag: "🇵🇭"),
        Language(code: "ny", name: "Chichewa", flag: "🇲🇼"),
        Language(code: "co", name: "Corsican", flag: "🇫🇷"),
        Language(code: "hr", name: "Croatian", flag: "🇭🇷"),
        Language(code: "eo", name: "Esperanto", flag: "🏳️"),
        Language(code: "et", name: "Estonian", flag: "🇪🇪"),
        Language(code: "tl", name: "Filipino", flag: "🇵🇭"),
        Language(code: "fy", name: "Frisian", flag: "🇳🇱"),
        Language(code: "gl", name: "Galician", flag: "🇪🇸"),
        Language(code: "ka", name: "Georgian", flag: "🇬🇪"),
        Language(code: "gu", name: "Gujarati", flag: "🇮🇳"),
        Language(code: "ht", name: "Haitian Creole", flag: "🇭🇹"),
        Language(code: "ha", name: "Hausa", flag: "🇳🇬"),
        Language(code: "haw", name: "Hawaiian", flag: "🇺🇸"),
        Language(code: "hmn", name: "Hmong", flag: "🇱🇦"),
        Language(code: "is", name: "Icelandic", flag: "🇮🇸"),
        Language(code: "ig", name: "Igbo", flag: "🇳🇬"),
        Language(code: "ga", name: "Irish", flag: "🇮🇪"),
        Language(code: "jw", name: "Javanese", flag: "🇮🇩"),
        Language(code: "kn", name: "Kannada", flag: "🇮🇳"),
        Language(code: "kk", name: "Kazakh", flag: "🇰🇿"),
        Language(code: "km", name: "Khmer", flag: "🇰🇭"),
        Language(code: "ku", name: "Kurdish", flag: "🇮🇶"),
        Language(code: "ky", name: "Kyrgyz", flag: "🇰🇬"),
        Language(code: "lo", name: "Lao", flag: "🇱🇦"),
        Language(code: "la", name: "Latin", flag: "🇻🇦"),
        Language(code: "lv", name: "Latvian", flag: "🇱🇻"),
        Language(code: "lt", name: "Lithuanian", flag: "🇱🇹"),
        Language(code: "lb", name: "Luxembourgish", flag: "🇱🇺"),
        Language(code: "mk", name: "Macedonian", flag: "🇲🇰"),
        Language(code: "mg", name: "Malagasy", flag: "🇲🇬"),
        Language(code: "ms", name: "Malay", flag: "🇲🇾"),
        Language(code: "ml", name: "Malayalam", flag: "🇮🇳"),
        Language(code: "mt", name: "Maltese", flag: "🇲🇹"),
        Language(code: "mi", name: "Maori", flag: "🇳🇿"),
        Language(code: "mr", name: "Marathi", flag: "🇮🇳"),
        Language(code: "mn", name: "Mongolian", flag: "🇲🇳"),
        Language(code: "ne", name: "Nepali", flag: "🇳🇵"),
        Language(code: "ps", name: "Pashto", flag: "🇦🇫"),
        Language(code: "pa", name: "Punjabi", flag: "🇮🇳"),
        Language(code: "sm", name: "Samoan", flag: "🇼🇸"),
        Language(code: "gd", name: "Scots Gaelic", flag: "🇬🇧"),
        Language(code: "sr", name: "Serbian", flag: "🇷🇸"),
        Language(code: "st", name: "Sesotho", flag: "🇱🇸"),
        Language(code: "sn", name: "Shona", flag: "🇿🇼"),
        Language(code: "sd", name: "Sindhi", flag: "🇵🇰"),
        Language(code: "si", name: "Sinhala", flag: "🇱🇰"),
        Language(code: "sl", name: "Slovenian", flag: "🇸🇮"),
        Language(code: "so", name: "Somali", flag: "🇸🇴"),
        Language(code: "su", name: "Sundanese", flag: "🇮🇩"),
        Language(code: "sw", name: "Swahili", flag: "🇰🇪"),
        Language(code: "tg", name: "Tajik", flag: "🇹🇯"),
        Language(code: "ta", name: "Tamil", flag: "🇮🇳"),
        Language(code: "tt", name: "Tatar", flag: "🇷🇺"),
        Language(code: "te", name: "Telugu", flag: "🇮🇳"),
        Language(code: "ug", name: "Uyghur", flag: "🇨🇳"),
        Language(code: "ur", name: "Urdu", flag: "🇵🇰"),
        Language(code: "uz", name: "Uzbek", flag: "🇺🇿"),
        Language(code: "cy", name: "Welsh", flag: "🇬🇧"),
        Language(code: "xh", name: "Xhosa", flag: "🇿🇦"),
        Language(code: "yi", name: "Yiddish", flag: "🇮🇱"),
        Language(code: "yo", name: "Yoruba", flag: "🇳🇬"),
        Language(code: "zu", name: "Zulu", flag: "🇿🇼"),
    ]

    /// Sources include the "Detect language" option first.
    static let sources: [Language] = [.auto] + targets

    /// Languages the on-device auto-detector is allowed to choose among. Restricted to those with a
    /// distinct script or a large, distinguishable footprint — Latin-script look-alikes (Catalan,
    /// Corsican, Galician, Frisian, …) are still translatable but excluded here, since on short text
    /// they get confused with common languages (e.g. "Salut, ce faci?" mis-tagged as Catalan).
    static let detectableCodes: Set<String> = [
        "en", "ro", "es", "fr", "de", "it", "pt", "nl", "ru", "uk", "pl", "cs", "sk", "hu", "bg",
        "el", "tr", "sv", "nb", "da", "fi",
        "ar", "fa", "he", "hi", "ja", "ko", "zh", "th", "vi", "id", "ms", "tl",
        "bn", "gu", "kn", "ml", "ta", "te", "pa", "mr", "ne", "si", "km", "lo", "my", "ka", "hy",
        "am", "ur", "ps", "ug", "yi",
        "sr", "mk", "be", "kk", "ky", "mn", "tg", "tt",
        "hr", "sl", "lt", "lv", "et", "is", "sq", "sw", "az", "uz",
    ]

    static func language(for code: String) -> Language {
        if code == Language.auto.code { return .auto }
        return targets.first { $0.code == code } ?? Language(code: code, name: code.uppercased(), flag: "🏳️")
    }

    static func name(for code: String) -> String { language(for: code).name }
    static func flag(for code: String) -> String { language(for: code).flag }

    static func isSupported(_ code: String) -> Bool { targets.contains { $0.code == code } }
}
