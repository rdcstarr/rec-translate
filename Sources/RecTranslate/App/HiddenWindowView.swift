import SwiftUI
import AppKit

/// Holds the willClose observer token so the @Sendable observer block can remove itself
/// (a mutable `var` / non-Sendable `NSObjectProtocol` can't be captured directly under Swift 6).
private final class ObserverTokenBox: @unchecked Sendable {
    var token: NSObjectProtocol?
}

/// Invisible 1×1 helper window. On macOS 26, `openSettings()` / `SettingsLink` do not reliably
/// open the Settings window from a `MenuBarExtra`. The documented workaround is to call
/// `openSettings()` from a real window's view while temporarily switching the (accessory) app
/// to `.regular`, then revert to `.accessory` when Settings closes.
struct HiddenWindowView: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        Color.clear
            .frame(width: 1, height: 1)
            .onReceive(NotificationCenter.default.publisher(for: .openSettingsRequest)) { _ in
                openSettingsWindow()
            }
    }

    private func openSettingsWindow() {
        Task { @MainActor in
            NSApp.setActivationPolicy(.regular)
            try? await Task.sleep(for: .milliseconds(80))
            NSApp.activate(ignoringOtherApps: true)
            openSettings()
            try? await Task.sleep(for: .milliseconds(150))

            // Prefer SwiftUI's known (private) Settings identifier, then fall back to a structural
            // match so a future identifier change still finds the window.
            let settingsWindow = NSApp.windows.first { $0.identifier?.rawValue == "com.apple.SwiftUI.Settings" }
                ?? NSApp.windows.first { window in
                    window.isVisible && window.canBecomeKey && !(window is FloatingPanel)
                        && window.identifier?.rawValue != "hidden"
                }

            guard let window = settingsWindow else {
                // Never leave a menu-bar agent stuck as a foreground (.regular) app.
                NSApp.setActivationPolicy(.accessory)
                return
            }

            window.makeKeyAndOrderFront(nil)
            window.orderFrontRegardless()

            // Revert to a background agent once the Settings window closes.
            let box = ObserverTokenBox()
            box.token = NotificationCenter.default.addObserver(
                forName: NSWindow.willCloseNotification,
                object: window,
                queue: .main
            ) { _ in
                MainActor.assumeIsolated { NSApp.setActivationPolicy(.accessory) }
                if let token = box.token { NotificationCenter.default.removeObserver(token) }
            }
        }
    }
}
