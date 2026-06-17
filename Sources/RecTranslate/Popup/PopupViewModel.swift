import AppKit
import Combine

/// Drives the popup: holds input/result state, runs translations, copies, and records history.
@MainActor
final class PopupViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var result: TranslationOutcome?
    @Published var isTranslating = false
    @Published var errorMessage: String?

    private let preferences: Preferences
    private let history: HistoryStore

    init(preferences: Preferences = .shared, history: HistoryStore = .shared) {
        self.preferences = preferences
        self.history = history
    }

    /// Swap source/target (no-op when the source is "auto", which has no concrete counterpart).
    func swapLanguages() {
        guard preferences.sourceCode != Language.auto.code else { return }
        swap(&preferences.sourceCode, &preferences.targetCode)
    }

    func translate() async {
        let text = inputText
        errorMessage = nil

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let baseURL = preferences.baseURL else {
            errorMessage = TranslationError.invalidBaseURL.errorDescription
            return
        }
        guard let apiKey = KeychainStore.apiKey, !apiKey.isEmpty else {
            errorMessage = TranslationError.missingAPIKey.errorDescription
            return
        }

        let service = TranslationService(
            provider: ProxyTranslateProvider(baseURL: baseURL, token: apiKey)
        )
        let source = preferences.sourceCode
        let target = preferences.targetCode

        isTranslating = true
        defer { isTranslating = false }

        do {
            let outcome = try await service.translate(text: text, sourceCode: source, targetCode: target)
            result = outcome
            history.add(
                HistoryEntry(
                    sourceCode: outcome.resolvedSourceCode,
                    targetCode: outcome.targetCode,
                    original: outcome.original,
                    translation: outcome.translation
                ),
                limit: preferences.historyLimit
            )
            if preferences.autoCopy {
                copyToPasteboard(outcome.translation)
            }
        } catch {
            result = nil
            errorMessage = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        }
    }

    func copyResult() {
        guard let translation = result?.translation else { return }
        copyToPasteboard(translation)
    }

    func loadFromHistory(_ entry: HistoryEntry) {
        inputText = entry.original
        preferences.sourceCode = entry.sourceCode
        preferences.targetCode = entry.targetCode
        result = TranslationOutcome(
            original: entry.original,
            translation: entry.translation,
            resolvedSourceCode: entry.sourceCode,
            targetCode: entry.targetCode,
            detectedSourceName: nil
        )
        errorMessage = nil
    }

    private func copyToPasteboard(_ string: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(string, forType: .string)
    }
}
