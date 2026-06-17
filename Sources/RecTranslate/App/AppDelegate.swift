import AppKit

/// Bridges AppKit lifecycle into the SwiftUI app: forces the menu-bar-agent activation policy
/// and starts the dependency graph. Re-checks the double-Shift monitor when the app reactivates
/// (e.g. after the user grants Accessibility in System Settings).
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory) // belt-and-suspenders alongside LSUIElement
        AppEnvironment.shared.start()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        AppEnvironment.shared.applyDoubleShiftSetting()
    }
}
