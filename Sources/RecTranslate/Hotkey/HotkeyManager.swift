import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The re-bindable global shortcut that opens the popup. Defaults to ⌥Space (like ChatGPT).
    /// The user can change it from the Settings recorder; KeyboardShortcuts persists it to
    /// UserDefaults automatically.
    static let toggleTranslator = Self("toggleTranslator", default: .init(.space, modifiers: .option))
}

/// Registers the global combo via KeyboardShortcuts (Carbon `RegisterEventHotKey` under the
/// hood — fires while unfocused and needs no Accessibility permission).
@MainActor
final class HotkeyManager {
    private var handler: (() -> Void)?

    func register(_ handler: @escaping () -> Void) {
        self.handler = handler
        KeyboardShortcuts.onKeyDown(for: .toggleTranslator) { [weak self] in
            guard let self else { return }
            MainActor.assumeIsolated { self.handler?() }
        }
    }
}
