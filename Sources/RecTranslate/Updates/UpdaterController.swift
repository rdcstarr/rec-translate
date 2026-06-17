import Foundation
import Combine
import Sparkle

/// Thin wrapper around Sparkle's standard updater. Drives the "Check for Updates…" menu item
/// and reflects whether a check is currently allowed (for enabling/disabling that item).
@MainActor
final class UpdaterController: ObservableObject {
    private let controller: SPUStandardUpdaterController

    @Published var canCheckForUpdates = false

    init(automaticallyChecks: Bool) {
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        controller.updater.automaticallyChecksForUpdates = automaticallyChecks
        controller.updater
            .publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        controller.updater.checkForUpdates()
    }

    func setAutomaticChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }
}
