import Foundation

/// Abstraction over a translation backend. One concrete implementation today
/// (`RecAppTranslationProvider`); a future `OpenAIProvider` could drop in here without
/// touching callers.
protocol TranslationProvider: Sendable {
    /// Translate `text` from `source` to `target` and return only the translated text.
    /// `source`/`target` are concrete codes (never `auto`).
    func translate(text: String, source: String, target: String) async throws -> String
}

/// Orchestrates a translation: validates input, resolves the `auto` source on-device,
/// calls the provider, and packages the outcome (including the detected language name).
struct TranslationService: Sendable {
    let provider: TranslationProvider

    func translate(text: String, sourceCode: String, targetCode: String) async throws -> TranslationOutcome {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw TranslationError.emptyText }
        guard trimmed.count < kMaxTranslationCharacters else {
            throw TranslationError.tooLong(limit: kMaxTranslationCharacters)
        }

        var resolvedSource = sourceCode
        var detectedSourceName: String?
        if sourceCode == Language.auto.code {
            guard let detected = LanguageDetector.detect(trimmed) else {
                throw TranslationError.couldNotDetectLanguage
            }
            resolvedSource = detected
            detectedSourceName = Languages.name(for: detected)
        }

        let translation = try await provider.translate(
            text: trimmed,
            source: resolvedSource,
            target: targetCode
        )

        return TranslationOutcome(
            original: trimmed,
            translation: translation,
            resolvedSourceCode: resolvedSource,
            targetCode: targetCode,
            detectedSourceName: detectedSourceName
        )
    }
}
