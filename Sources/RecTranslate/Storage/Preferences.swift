import Foundation
import Combine

/// User preferences backed by `UserDefaults`. Non-secret settings only — the API key lives
/// in the Keychain (`KeychainStore`). Implemented as an `ObservableObject` so SwiftUI views
/// get `$`-bindings and non-view code can read `Preferences.shared` directly.
@MainActor
final class Preferences: ObservableObject {
    static let shared = Preferences()

    private let defaults = UserDefaults.standard

    private enum Key {
        static let source = "pref.sourceCode"
        static let target = "pref.targetCode"
        // v2 key so the new proxy123 default applies even for installs that saved the old default.
        static let baseURL = "pref.apiBaseURL.v2"
        static let autoCopy = "pref.autoCopy"
        static let autoTranslate = "pref.autoTranslate"
        static let doubleShift = "pref.doubleShiftEnabled"
        static let autoUpdates = "pref.autoCheckUpdates"
        static let historyLimit = "pref.historyLimit"
        static let engine = "pref.engine"
        static let openAIModel = "pref.openAIModel"
    }

    static let defaultOpenAIModel = "gpt-4o-mini"

    @Published var sourceCode: String { didSet { defaults.set(sourceCode, forKey: Key.source) } }
    @Published var targetCode: String { didSet { defaults.set(targetCode, forKey: Key.target) } }
    @Published var baseURLString: String { didSet { defaults.set(baseURLString, forKey: Key.baseURL) } }
    @Published var autoCopy: Bool { didSet { defaults.set(autoCopy, forKey: Key.autoCopy) } }
    @Published var autoTranslate: Bool { didSet { defaults.set(autoTranslate, forKey: Key.autoTranslate) } }
    @Published var doubleShiftEnabled: Bool { didSet { defaults.set(doubleShiftEnabled, forKey: Key.doubleShift) } }
    @Published var autoCheckUpdates: Bool { didSet { defaults.set(autoCheckUpdates, forKey: Key.autoUpdates) } }
    @Published var historyLimit: Int { didSet { defaults.set(historyLimit, forKey: Key.historyLimit) } }
    @Published var engine: TranslationEngine { didSet { defaults.set(engine.rawValue, forKey: Key.engine) } }
    @Published var openAIModel: String { didSet { defaults.set(openAIModel, forKey: Key.openAIModel) } }

    private init() {
        sourceCode = defaults.string(forKey: Key.source) ?? Language.auto.code
        targetCode = defaults.string(forKey: Key.target) ?? "ro"
        baseURLString = defaults.string(forKey: Key.baseURL) ?? "https://proxy123.click"
        autoCopy = (defaults.object(forKey: Key.autoCopy) as? Bool) ?? true
        autoTranslate = (defaults.object(forKey: Key.autoTranslate) as? Bool) ?? true
        doubleShiftEnabled = (defaults.object(forKey: Key.doubleShift) as? Bool) ?? true
        autoCheckUpdates = (defaults.object(forKey: Key.autoUpdates) as? Bool) ?? true
        historyLimit = (defaults.object(forKey: Key.historyLimit) as? Int) ?? 20
        engine = TranslationEngine(rawValue: defaults.string(forKey: Key.engine) ?? "") ?? .google
        let savedModel = defaults.string(forKey: Key.openAIModel)?.trimmingCharacters(in: .whitespaces)
        openAIModel = (savedModel?.isEmpty == false ? savedModel! : Preferences.defaultOpenAIModel)
    }

    /// Parsed, validated base URL (nil when the string is malformed).
    var baseURL: URL? {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil, url.host != nil else { return nil }
        return url
    }
}
