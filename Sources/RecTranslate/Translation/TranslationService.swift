import Foundation

/// Abstraction over a translation backend. One concrete implementation today
/// (`RecAppTranslationProvider`); a future `OpenAIProvider` could drop in here without
/// touching callers.
protocol TranslationProvider: Sendable {
    /// Translate `text` from `source` to `target`. `source` may be `auto` (the server detects it).
    func translate(text: String, source: String, target: String) async throws -> ProviderResult
}

/// Orchestrates a translation: validates input, calls the provider (passing `auto` straight
/// through — the server resolves it), and packages the outcome with the detected language name.
struct TranslationService: Sendable {
    let provider: TranslationProvider

    func translate(text: String, sourceCode: String, targetCode: String) async throws -> TranslationOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyText }
        guard trimmed.count < kMaxTranslationCharacters else {
            throw TranslationError.tooLong(limit: kMaxTranslationCharacters)
        }

        let result = try await provider.translate(text: trimmed, source: sourceCode, target: targetCode)

        let detectedSourceName: String? = (sourceCode == Language.auto.code)
            ? result.detected.map { Languages.name(for: $0) }
            : nil

        return TranslationOutcome(
            original: trimmed,
            translation: result.translation,
            resolvedSourceCode: result.detected ?? sourceCode,
            targetCode: targetCode,
            detectedSourceName: detectedSourceName
        )
    }
}
