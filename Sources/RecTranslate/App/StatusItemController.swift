import AppKit

/// Manages the menu-bar status item directly (instead of SwiftUI's MenuBarExtra) so a **left click**
/// opens the popup and a **right click** (or Control-click) shows the interactive menu.
///
/// Right-clicks are caught by a local `rightMouseDown` event monitor rather than the button's
/// action — some macOS versions don't deliver the action on right-click for a status-item button,
/// which is why the earlier approaches showed nothing. Left-click uses the button action.
@MainActor
final class StatusItemController: NSObject {
    private let statusItem: NSStatusItem
    private let onOpen: () -> Void
    private let onCheckUpdates: () -> Void
    private var rightClickMonitor: Any?

    init(onOpen: @escaping () -> Void, onCheckUpdates: @escaping () -> Void) {
        self.onOpen = onOpen
        self.onCheckUpdates = onCheckUpdates
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        if let button = statusItem.button {
            let image = NSImage(systemSymbolName: "character.bubble.fill", accessibilityDescription: "Rec Translate")
            image?.isTemplate = true
            button.image = image
            button.toolTip = "Rec Translate — click to translate, right-click for menu"
            button.target = self
            button.action = #selector(handleLeftClick)
            button.sendAction(on: [.leftMouseUp]) // left handled here; right handled by the monitor
        }

        // Reliable right-click handling: a status item's button lives in its own window inside our
        // process, so a local rightMouseDown monitor catches clicks on it across macOS versions.
        rightClickMonitor = NSEvent.addLocalMonitorForEvents(matching: [.rightMouseDown]) { [weak self] event in
            guard let self else { return event }
            return MainActor.assumeIsolated {
                if let buttonWindow = self.statusItem.button?.window, event.window === buttonWindow {
                    self.showMenu()
                    return nil // consume
                }
                return event
            }
        }
    }

    @objc private func handleLeftClick() {
        // Control-click also opens the menu (it arrives as a left click with the .control modifier).
        if NSApp.currentEvent?.modifierFlags.contains(.control) == true {
            showMenu()
        } else {
            onOpen()
        }
    }

    private func showMenu() {
        let menu = makeMenu()
        statusItem.menu = menu                 // assigning a menu makes the next click open it…
        statusItem.button?.performClick(nil)   // …and performClick opens it now (blocks until closed)
        statusItem.menu = nil                  // detach so the next left click runs the action again
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
