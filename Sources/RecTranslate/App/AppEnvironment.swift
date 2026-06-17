import AppKit
import Combine

/// Composition root: owns the long-lived objects (popup, hotkeys, updater) and wires them up.
/// A singleton so SwiftUI scenes (MenuBarExtra, Settings) and the AppDelegate share one graph.
@MainActor
final class AppEnvironment: ObservableObject {
    static let shared = AppEnvironment()

    let viewModel: PopupViewModel
    let panelController: PanelController
    let hotkeyManager = HotkeyManager()
    let doubleShiftMonitor = DoubleShiftMonitor()
    let updater = GitHubUpdater()
    private var statusItemController: StatusItemController?

    private var cancellables = Set<AnyCancellable>()

    private init() {
        viewModel = PopupViewModel()
        panelController = PanelController(viewModel: viewModel)
    }

    /// Called once from `applicationDidFinishLaunching`.
    func start() {
        hotkeyManager.register { [weak self] in
            self?.panelController.toggle()
        }
        applyDoubleShiftSetting()
        updater.startAutomaticChecks(enabled: Preferences.shared.autoCheckUpdates)

        // Menu-bar status item: left-click opens the popup, right-click shows the menu.
        statusItemController = StatusItemController(
            onOpen: { [weak self] in self?.panelController.toggle() },
            onCheckUpdates: { [weak self] in
                Task { @MainActor in await self?.updater.checkForUpdates(userInitiated: true) }
            }
        )

        observePreferences()
    }

    /// Start/stop the double-Shift monitor according to the setting and current permission.
    /// Does not prompt — prompting is an explicit action in Settings.
    func applyDoubleShiftSetting() {
        // Re-arm from scratch so the global monitor re-registers (e.g. after the user returns from
        // the Accessibility prompt). Armed whenever enabled; if not yet trusted it simply won't fire
        // until macOS grants the permission (which takes effect on the next launch).
        doubleShiftMonitor.stop()
        guard Preferences.shared.doubleShiftEnabled else { return }
        doubleShiftMonitor.start { [weak self] in
            self?.panelController.toggle()
        }
    }

    private func observePreferences() {
        Preferences.shared.$doubleShiftEnabled
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.applyDoubleShiftSetting() }
            .store(in: &cancellables)

        Preferences.shared.$autoCheckUpdates
            .dropFirst()
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in self?.updater.startAutomaticChecks(enabled: enabled) }
            .store(in: &cancellables)
    }
}
