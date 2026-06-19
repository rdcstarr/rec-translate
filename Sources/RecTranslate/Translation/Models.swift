import Foundation

/// A language the user can pick as a translation source or target.
///
/// `code` is the value sent to the rec-app API (`/api/translate/{source}/{target}`)
/// and must match a row in rec-app's `languages` table. The special `auto` code is
/// resolved on-device (see `LanguageDetector`) before any request is made.
struct Language: Identifiable, Hashable, Sendable {
    let code: String
    let name: String
    let flag: String

    var id: String { code }

    /// Source-only sentinel: the server detects the language (Google) and returns it.
    static let auto = Language(code: "auto", name: "Detect language", flag: "🌐")

    var isAuto: Bool { code == Language.auto.code }
}

/// Which backend performs the translation.
enum TranslationEngine: String, CaseIterable, Identifiable, Sendable {
    case google
    case openai
    case deepseek

    var id: String { rawValue }

    /// Full label for Settings / menu rows.
    var displayName: String {
        switch self {
        case .google: return "Google · fast & free"
        case .openai: return "OpenAI · higher quality"
        case .deepseek: return "DeepSeek · cost-effective"
        }
    }

    /// Compact label for the in-popup engine pill.
    var shortName: String {
        switch self {
        case .google: return "Google"
        case .openai: return "OpenAI"
        case .deepseek: return "DeepSeek"
        }
    }
}

/// The result of a successful translation, ready for display and history.
struct TranslationOutcome: Hashable, Sendable {
    let original: String
    let translation: String
    /// The concrete source code actually sent (never `auto`).
    let resolvedSourceCode: String
    let targetCode: String
    /// Human-readable detected language name, set only when the source was `auto`.
    let detectedSourceName: String?
}

/// JSON body returned by proxy123.click `/translate/{source}/{target}`.
/// `success` is optional so a generic Laravel error envelope (`{"message": ...}`, e.g. CSRF) still
/// decodes and its text survives.
struct ProxyTranslateResponse: Decodable, Sendable {
    let success: Bool?
    let translation: String?
    let detected: String?
    let error: String?
    let message: String?

    /// Best available human-readable error text.
    var errorText: String? { error ?? message }
}

/// What a `TranslationProvider` returns: the translated text plus an optional detected source code
/// (set by the server when the request used `source = auto`).
struct ProviderResult: Sendable {
    let translation: String
    let detected: String?
}

/// Upper bound on input length. The server now chunks long text across requests (and OpenAI handles
/// long input in one call), so this is a generous sanity cap that matches the server's limit.
let kMaxTranslationCharacters = 20000

/// All failure modes surfaced to the user, with friendly descriptions.
enum TranslationError: LocalizedError, Sendable {
    case emptyText
    case tooLong(limit: Int)
    case couldNotDetectLanguage
    case missingAPIKey
    case missingOpenAIKey
    case missingDeepSeekKey
    case invalidBaseURL
    case unauthorized
    case forbidden
    case invalidInput(String)
    case upstreamFailure(String?)
    case unexpectedStatus(Int, String?)
    case network(String)
    case decoding

    var errorDescription: String? {
        switch self {
        case .emptyText:
            return "Enter some text to translate."
        case .tooLong(let limit):
            return "Text is too long. The limit is \(limit) characters."
        case .couldNotDetectLanguage:
            return "Couldn't detect the language. Pick a source language in Settings."
        case .missingAPIKey:
            return "No API key set. Add your translate API key in Settings."
        case .missingOpenAIKey:
            return "No OpenAI API key set. Add it in Settings (or switch to Google)."
        case .missingDeepSeekKey:
            return "No DeepSeek API key set. Add it in Settings (or switch to Google)."
        case .invalidBaseURL:
            return "The API base URL in Settings is not valid."
        case .unauthorized:
            return "Invalid or missing API key. Check it in Settings."
        case .forbidden:
            return "This API key is not authorized to translate."
        case .invalidInput(let message):
            return message
        case .upstreamFailure(let message):
            return message ?? "Translation service is temporarily unavailable. Try again."
        case .unexpectedStatus(let code, let message):
            return message ?? "Unexpected server response (HTTP \(code))."
        case .network(let message):
            return "Network error: \(message)"
        case .decoding:
            return "Couldn't read the translation response."
        }
    }
}

/// One stored translation, shown in the recent-history list.
struct HistoryEntry: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let date: Date
    let sourceCode: String
    let targetCode: String
    let original: String
    let translation: String

    init(
        id: UUID = UUID(),
        date: Date = Date(),
        sourceCode: String,
        targetCode: String,
        original: String,
        translation: String
    ) {
        self.id = id
        self.date = date
        self.sourceCode = sourceCode
        self.targetCode = targetCode
        self.original = original
        self.translation = translation
    }
}
