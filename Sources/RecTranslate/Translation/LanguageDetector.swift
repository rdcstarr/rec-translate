import Foundation
import NaturalLanguage

/// On-device language detection (Apple's NaturalLanguage). Used to resolve a "Detect language"
/// source: it's more reliable than the upstream engine's guess on short text (e.g. it tags
/// "Salut, ce faci?" as Romanian, not Catalan), and detection is constrained to the languages the
/// app actually supports so it never returns something we can't offer.
enum LanguageDetector {
    /// The supported languages as NLLanguage constraints (excludes everything we don't offer).
    private static let constraints: [NLLanguage] = {
        var languages: [NLLanguage] = []
        for code in Languages.targets.map(\.code) {
            if code == "zh" {
                languages.append(.simplifiedChinese)
                languages.append(.traditionalChinese)
            } else {
                languages.append(NLLanguage(rawValue: code))
            }
        }
        return languages
    }()

    /// Best-effort detection. Returns a supported ISO code, or nil when the recognizer isn't
    /// confident enough (caller then falls back to the server's own auto-detect).
    static func detect(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return nil }

        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = constraints
        recognizer.processString(trimmed)

        guard let (language, confidence) = recognizer.languageHypotheses(withMaximum: 1).first,
              confidence >= 0.5 else { return nil }

        return mapToSupported(language)
    }

    private static func mapToSupported(_ language: NLLanguage) -> String? {
        let code: String
        switch language {
        case .simplifiedChinese, .traditionalChinese: code = "zh"
        default: code = language.rawValue
        }
        return Languages.isSupported(code) ? code : nil
    }
}
