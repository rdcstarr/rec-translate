import AppKit
import Combine

/// Drives the popup: holds input/result state, runs translations, copies, and records history.
@MainActor
final class PopupViewModel: ObservableObject {
    @Published var inputText = ""
    @Published var result: TranslationOutcome?
    @Published var isTranslating = false
    @Published var errorMessage: String?
    @Published var justCopied = false

    private let preferences: Preferences
    private let history: HistoryStore
    private var cancellables = Set<AnyCancellable>()
    private var translateTask: Task<Void, Never>?
    private var copiedResetTask: Task<Void, Never>?

    init(preferences: Preferences = .shared, history: HistoryStore = .shared) {
        self.preferences = preferences
        self.history = history

        // Auto-translate: translate shortly after the user stops typing/pasting (when enabled).
        $inputText
            .debounce(for: .milliseconds(550), scheduler: RunLoop.main)
            .removeDuplicates()
            .sink { [weak self] text in self?.autoTranslateIfNeeded(text) }
            .store(in: &cancellables)

        // Clear a stale result immediately when the input becomes empty (e.g. select-all + cut),
        // so the old translation doesn't linger.
        $inputText
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .removeDuplicates()
            .sink { [weak self] isEmpty in
                guard isEmpty, let self else { return }
                self.translateTask?.cancel()
                self.result = nil
                self.errorMessage = nil
            }
            .store(in: &cancellables)
    }

    private func autoTranslateIfNeeded(_ text: String) {
        guard preferences.autoTranslate else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return }
        // Stay silent until the active engine's key is set, so auto-translate doesn't spam errors.
        let hasKey = switch preferences.engine {
        case .openai: TokenStore.openAIKey?.isEmpty == false
        case .deepseek: TokenStore.deepseekKey?.isEmpty == false
        case .google: TokenStore.apiKey?.isEmpty == false
        }
        guard hasKey else { return }
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

    /// Re-translate the current input when the user changes source/target (or swaps), so an
    /// already-shown result reflects the new languages instead of going stale.
    func retranslateForLanguageChange() {
        // Refresh when something is already shown — a result OR an error (e.g. switching away from an
        // engine that wasn't configured must clear the error and translate with the new engine).
        guard result != nil || errorMessage != nil else { return }
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        requestTranslate()
    }

    func translate() async {
        let text = inputText
        errorMessage = nil

        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        let provider: TranslationProvider
        switch preferences.engine {
        case .openai:
            guard let openAIKey = TokenStore.openAIKey, !openAIKey.isEmpty else {
                errorMessage = TranslationError.missingOpenAIKey.errorDescription
                return
            }
            let model = preferences.openAIModel.trimmingCharacters(in: .whitespaces)
            provider = OpenAICompatibleProvider(
                endpoint: ChatCompletionsEndpoint.openAI,
                apiKey: openAIKey,
                model: model.isEmpty ? Preferences.defaultOpenAIModel : model
            )
        case .deepseek:
            guard let deepseekKey = TokenStore.deepseekKey, !deepseekKey.isEmpty else {
                errorMessage = TranslationError.missingDeepSeekKey.errorDescription
                return
            }
            let model = preferences.deepseekModel.trimmingCharacters(in: .whitespaces)
            provider = OpenAICompatibleProvider(
                endpoint: ChatCompletionsEndpoint.deepSeek,
                apiKey: deepseekKey,
                model: model.isEmpty ? Preferences.defaultDeepSeekModel : model
            )
        case .google:
            guard let baseURL = preferences.baseURL else {
                errorMessage = TranslationError.invalidBaseURL.errorDescription
                return
            }
            guard let apiKey = TokenStore.apiKey, !apiKey.isEmpty else {
                errorMessage = TranslationError.missingAPIKey.errorDescription
                return
            }
            provider = ProxyTranslateProvider(baseURL: baseURL, token: apiKey)
        }

        let service = TranslationService(provider: provider)
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

    func clearInput() {
        translateTask?.cancel()
        inputText = ""
        result = nil
        errorMessage = nil
    }

    func copyResult() {
        guard let translation = result?.translation else { return }
        copyToPasteboard(translation)

        // Brief "Copied" confirmation on the button.
        justCopied = true
        copiedResetTask?.cancel()
        copiedResetTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(1.6))
            guard !Task.isCancelled else { return }
            self?.justCopied = false
        }
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
