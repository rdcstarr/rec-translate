import SwiftUI

@main
struct RecTranslateApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        // Hidden 1×1 window — declared FIRST so the macOS 26 openSettings() workaround works.
        Window("RecTranslate", id: "hidden") {
            HiddenWindowView()
        }
        .windowResizability(.contentSize)
        .defaultSize(width: 1, height: 1)
        .windowStyle(.hiddenTitleBar)

        // The menu-bar item is managed in AppKit (StatusItemController) so left-click opens the
        // popup and right-click shows the menu — behaviour MenuBarExtra can't express.

        Settings {
            SettingsView()
                .environmentObject(Preferences.shared)
        }
    }
}
