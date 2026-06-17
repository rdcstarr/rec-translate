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

        // Resolve "Detect language": prefer a confident on-device detection (more reliable than the
        // upstream engine on short text); otherwise pass "auto" through and let the server detect.
        var resolvedSource = sourceCode
        var onDeviceDetectedName: String?
        if sourceCode == Language.auto.code, let detected = LanguageDetector.detect(trimmed) {
            resolvedSource = detected
            onDeviceDetectedName = Languages.name(for: detected)
        }

        let result = try await provider.translate(text: trimmed, source: resolvedSource, target: targetCode)
        // Capitalization + terminal punctuation are matched per line on the server (it has each
        // source line), so the client passes the translation through unchanged.
        let translation = result.translation

        // What to show as "Detected:" — on-device wins, else the server's src when we asked for auto.
        let detectedSourceName: String?
        if let onDeviceDetectedName {
            detectedSourceName = onDeviceDetectedName
        } else if sourceCode == Language.auto.code {
            detectedSourceName = result.detected.map { Languages.name(for: $0) }
        } else {
            detectedSourceName = nil
        }

        let resolvedSourceCode = (resolvedSource != Language.auto.code)
            ? resolvedSource
            : (result.detected ?? sourceCode)

        return TranslationOutcome(
            original: trimmed,
            translation: translation,
            resolvedSourceCode: resolvedSourceCode,
            targetCode: targetCode,
            detectedSourceName: detectedSourceName
        )
    }
}
