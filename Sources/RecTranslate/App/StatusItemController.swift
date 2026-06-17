import AppKit

/// Menu-bar status item: **left click** opens the popup, **right click** (or Control-click) shows
/// the menu. Verified production recipe (used by apps like Ice/Stats):
/// keep `statusItem.menu == nil` so the button's action fires; register the button for BOTH
/// mouse-up events; in the action inspect `NSApp.currentEvent` to branch; to show the menu,
/// momentarily attach it and `performClick`, then clear it in `menuDidClose` so the next left
/// click runs the action again. (NSMenu.popUp and NSEvent monitors are unreliable here.)
@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let statusItem: NSStatusItem
    private let menu = NSMenu()
    private let onOpen: () -> Void
    private let onCheckUpdates: () -> Void

    init(onOpen: @escaping () -> Void, onCheckUpdates: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onCheckUpdates = onCheckUpdates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        // Build the right-click menu once.
        menu.delegate = self
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
            // CRITICAL: receive BOTH mouse-ups, or the action never fires on right-click.
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            // CRITICAL: do NOT assign statusItem.menu here — leaving it nil lets the action fire.
        }
    }

    @objc private func handleClick(_ sender: NSStatusBarButton) {
        guard let event = NSApp.currentEvent else { onOpen(); return }
        let isRight = event.type == .rightMouseUp
        let isControlClick = event.type == .leftMouseUp && event.modifierFlags.contains(.control)
        if isRight || isControlClick {
            statusItem.menu = menu            // attach transiently…
            sender.performClick(nil)          // …AppKit shows + positions it, highlights the button
            // menu is detached again in menuDidClose(_:)
        } else {
            onOpen()
        }
    }

    /// Restore left-click behaviour after the menu closes.
    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
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
