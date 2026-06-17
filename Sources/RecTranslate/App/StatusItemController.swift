import AppKit

/// Manages the menu-bar status item directly (instead of SwiftUI's MenuBarExtra) so a **left click**
/// opens the popup and a **right click** (or Control-click) shows the interactive menu.
///
/// The menu is shown with `NSMenu.popUp(...)` rather than by temporarily assigning `statusItem.menu`
/// (the latter is fragile and can swallow the next left click). We never set `statusItem.menu`, so
/// the button's action fires for both mouse buttons and we route on the event type.
@MainActor
final class StatusItemController: NSObject {
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
        if isRightClick, let button = statusItem.button {
            let menu = makeMenu()
            // Drop the menu just below the status item.
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.height + 4), in: button)
        } else {
            onOpen()
        }
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()
        addItem(to: menu, title: "Open Rec Translate", action: #selector(openAction))
        addItem(to: menu, title: "Settings…", action: #selector(settingsAction))
        addItem(to: menu, title: "Check for Updates…", action: #selector(updatesAction))
        menu.addItem(.separator())
        addItem(to: menu, title: "Quit Rec Translate", action: #selector(quitAction))
        return menu
    }

    private func addItem(to menu: NSMenu, title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func openAction() { onOpen() }
    @objc private func settingsAction() { NotificationCenter.default.post(name: .openSettingsRequest, object: nil) }
    @objc private func updatesAction() { onCheckUpdates() }
    @objc private func quitAction() { NSApp.terminate(nil) }
}
