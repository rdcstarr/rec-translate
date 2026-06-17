import Foundation

/// A language the user can pick as a translation source or target.
///
/// `code` is the value sent to the rec-app API (`/api/translate/{source}/{target}`)
/// and must match a row in rec-app's `languages` table. The special `auto` code is
/// resolved on-device (see `LanguageDetector`) before any request is made.
struct Language: Identifiable, Hashable, Sendable {
    let code: String
    let name: String

    var id: String { code }

    /// Source-only sentinel: detect the language on-device, then send the detected code.
    static let auto = Language(code: "auto", name: "Detect language")

    var isAuto: Bool { code == Language.auto.code }
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

/// Successful JSON body returned by rec-app's `TranslateController`.
struct RecAppTranslateResponse: Decodable, Sendable {
    let source: String
    let target: String
    let text: String
    let translation: String
}

/// Error body rec-app returns for 4xx/5xx (`{"message": "..."}`).
/// Internal (not `private`) so `RecAppTranslationProvider` in another file can use it.
struct RecAppErrorResponse: Decodable {
    let message: String?
}

extension RecAppErrorResponse {
    static func message(from data: Data) -> String? {
        (try? JSONDecoder().decode(RecAppErrorResponse.self, from: data))?.message
    }
}

/// Maximum characters accepted by the server (`GoogleTranslateService` throws at `>= 5000`).
let kMaxTranslationCharacters = 5000

/// All failure modes surfaced to the user, with friendly descriptions.
enum TranslationError: LocalizedError, Sendable {
    case emptyText
    case tooLong(limit: Int)
    case couldNotDetectLanguage
    case missingAPIKey
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
