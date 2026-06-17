import AppKit

/// Manages the menu-bar status item directly (instead of SwiftUI's MenuBarExtra) so a **left click**
/// opens the popup and a **right click** (or Control-click) shows the interactive menu.
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void
    private let onCheckUpdates: () -> Void

    init(onOpen: @escaping () -> Void, onCheckUpdates: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onCheckUpdates = onCheckUpdates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "Rec Translate")
            image?.isTemplate = true // adapts to the (transparent, light/dark) menu bar
            button.image = image
            button.toolTip = "Rec Translate — click to translate, right-click for menu"
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
    }

    @objc private func handleClick() {
        let event = NSApp.currentEvent
        let isRightClick = event?.type == .rightMouseUp || (event?.modifierFlags.contains(.control) ?? false)
        if isRightClick {
            // Temporarily attach a menu and click to open it; cleared again in menuDidClose so the
            // next left click triggers the action rather than the menu.
            statusItem.menu = makeMenu()
            statusItem.button?.performClick(nil)
        } else {
            onOpen()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        menu.delegate = self
        addItem(to: menu, title: "Open Rec Translate", action: #selector(openAction))
        addItem(to: menu, title: "Settings…", action: #selector(settingsAction))
        addItem(to: menu, title: "Check for Updates…", action: #selector(updatesAction))
        menu.addItem(.separator())
        addItem(to: menu, title: "Quit Rec Translate", action: #selector(quitAction))
        return menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector, key: String = "") {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = self
        menu.addItem(item)
    }

    @objc private func openAction() { onOpen() }
    @objc private func settingsAction() { NotificationCenter.default.post(name: .openSettingsRequest, object: nil) }
    @objc private func updatesAction() { onCheckUpdates() }
    @objc private func quitAction() { NSApp.terminate(nil) }

    // Detach the menu after it closes so the next left click runs the action, not the menu.
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }
}
