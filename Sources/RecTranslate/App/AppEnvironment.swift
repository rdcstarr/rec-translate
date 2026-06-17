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
        observePreferences()
    }

    /// Start/stop the double-Shift monitor according to the setting and current permission.
    /// Does not prompt — prompting is an explicit action in Settings.
    func applyDoubleShiftSetting() {
        if Preferences.shared.doubleShiftEnabled, DoubleShiftMonitor.hasAccessibilityPermission() {
            doubleShiftMonitor.start { [weak self] in
                self?.panelController.toggle()
            }
        } else {
            doubleShiftMonitor.stop()
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
