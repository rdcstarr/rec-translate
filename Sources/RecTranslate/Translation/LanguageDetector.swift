import Foundation
import NaturalLanguage

/// On-device language detection used to resolve the "Detect language" (auto) source
/// without contacting the server. The endpoint rejects `source=auto`, so we detect the
/// dominant language locally and send a concrete code.
enum LanguageDetector {
    /// Returns a normalized ISO 639-1 code for the dominant language, or `nil` if unknown.
    static func detect(_ text: String) -> String? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        guard let language = recognizer.dominantLanguage else { return nil }
        return normalize(language.rawValue)
    }

    /// `NLLanguage.rawValue` is BCP-47 (e.g. "en", "zh-Hans", "pt-BR"). Reduce it to the
    /// base codes our `Languages` list / the server understands.
    private static func normalize(_ raw: String) -> String {
        let lower = raw.lowercased()
        if lower.hasPrefix("zh") { return "zh" }        // zh-Hans / zh-Hant -> zh
        // Strip any region/script subtag: "pt-br" -> "pt".
        if let dash = lower.firstIndex(of: "-") {
            return String(lower[..<dash])
        }
        return lower
    }
}
