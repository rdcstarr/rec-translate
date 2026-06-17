import AppKit
import SwiftUI

/// Owns the floating popup: builds it lazily, shows it centered on the display under the mouse,
/// and hides it. Driven imperatively (from the hotkey / menu) rather than via a SwiftUI scene.
@MainActor
final class PanelController {
    private var panel: FloatingPanel?
    private let viewModel: PopupViewModel

    /// Fixed popup width; height tracks SwiftUI content via the hosting controller.
    private let initialSize = NSSize(width: 640, height: 140)

    init(viewModel: PopupViewModel) {
        self.viewModel = viewModel
    }

    var isVisible: Bool { panel?.isVisible ?? false }

    func toggle() {
        if isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        let panel = panel ?? makePanel()
        self.panel = panel

        panel.positionOnMouseScreen()
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        panel.orderFrontRegardless()
        panel.positionOnMouseScreen() // re-center now that the content size is known

        // The SwiftUI content height settles on the next layout pass; re-center once more so the
        // first show doesn't visibly jump. (self is @MainActor → safe to capture in the Task.)
        Task { @MainActor [weak self] in
            self?.panel?.positionOnMouseScreen()
        }

        // Re-focus the input on every show (onAppear only fires the first time).
        NotificationCenter.default.post(name: .focusPopupInput, object: nil)
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func makePanel() -> FloatingPanel {
        let panel = FloatingPanel(contentRect: NSRect(origin: .zero, size: initialSize))
        panel.onDismiss = { [weak self] in self?.hide() }

        let root = PopupView(onClose: { [weak self] in self?.hide() })
            .environmentObject(viewModel)
            .environmentObject(Preferences.shared)
            .environmentObject(HistoryStore.shared)

        let hostingController = NSHostingController(rootView: root)
        hostingController.sizingOptions = [.preferredContentSize]
        panel.contentViewController = hostingController
        return panel
    }
}
