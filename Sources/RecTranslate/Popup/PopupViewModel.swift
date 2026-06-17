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
    private var cancellables = Set<AnyCancellable>()
    private var translateTask: Task<Void, Never>?

    init(preferences: Preferences = .shared, history: HistoryStore = .shared) {
        self.preferences = preferences
        self.history = history

        // Auto-translate: translate shortly after the user stops typing/pasting (when enabled).
        $inputText
            .debounce(for: .milliseconds(550), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in self?.autoTranslateIfNeeded(text) }
            .store(in: &cancellables)
    }

    private func autoTranslateIfNeeded(_ text: String) {
        guard preferences.autoTranslate else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        // Stay silent until a token is set, so auto-translate doesn't spam "No API key" while typing.
        guard let key = KeychainStore.apiKey, !key.isEmpty else { return }
        if let current = result, current.original == trimmed { return } // already translated
        requestTranslate()
    }

    /// Start a translation, cancelling any in-flight one. Both Return and auto-translate use this.
    func requestTranslate() {
        translateTask?.cancel()
        translateTask = Task { [weak self] in await self?.translate() }
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
            if Task.isCancelled { return }
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
            if Task.isCancelled { return } // superseded by a newer request
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
