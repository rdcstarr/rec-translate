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

        MenuBarExtra("RecTranslate", systemImage: "character.bubble.fill") {
            Button("Open RecTranslate") {
                AppEnvironment.shared.panelController.show()
            }
            Button("Settings…") {
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Check for Updates…") {
                Task { await AppEnvironment.shared.updater.checkForUpdates(userInitiated: true) }
            }

            Divider()

            Button("Quit RecTranslate") {
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(Preferences.shared)
        }
    }
}
