import Foundation
import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    /// The re-bindable global shortcut that opens the popup. No default — the user records their own
    /// in Settings (double-tap Shift is the default trigger instead). Persisted to UserDefaults
    /// automatically by KeyboardShortcuts.
    static let toggleTranslator = Self("toggleTranslator")
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
