import AppKit

/// Menu-bar status item: **left click** opens the popup, **right click** (or Control-click) shows
/// the menu. Verified macOS-26 recipe: keep `button.action` with `sendAction(on:[.leftMouseUp,
/// .rightMouseUp])` and pop the menu **directly** via `NSMenu.popUp(...)`. Do NOT assign
/// `statusItem.menu` and do NOT use `performClick` — that dance re-enters the handler and leaves
/// the menu attached, which makes right-click (and then every click) a no-op.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let onOpen: () -> Void
    private let onCheckUpdates: () -> Void

    init(onOpen: @escaping () -> Void, onCheckUpdates: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onCheckUpdates = onCheckUpdates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        addItem(title: "Open Rec Translate", action: #selector(openAction))
        addItem(title: "Settings…", action: #selector(settingsAction))
        addItem(title: "Check for Updates…", action: #selector(updatesAction))
        menu.addItem(.separator())
        addItem(title: "Quit Rec Translate", action: #selector(quitAction))

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "Rec Translate")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Rec Translate — click to translate, right-click for menu"
            button.target = self
            button.action = #selector(handleClick(_:))
            // Receive BOTH mouse-ups so the action fires on right-click too.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // Intentionally NEVER set statusItem.menu (that would hijack left-click and stop the action).
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { onOpen(); return }
        let isRight = event.type == .rightMouseUp
            || (event.type == .leftMouseUp && event.modifierFlags.contains(.control))
        if isRight {
            // Pop the menu directly under the item (no statusItem.menu, no performClick).
            menu.popUp(positioning: nil, at: NSPoint(x: 0, y: sender.bounds.height + 5), in: sender)
        } else {
            onOpen()
        }
    }

    private func addItem(title: String, action: Selector) {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
        item.target = self
        menu.addItem(item)
    }

    @objc private func openAction() { onOpen() }
    @objc private func settingsAction() { NotificationCenter.default.post(name: .openSettingsRequest, object: nil) }
    @objc private func updatesAction() { onCheckUpdates() }
    @objc private func quitAction() { NSApp.terminate(nil) }
}
