import AppKit
import Combine

/// Self-contained auto-updater that watches this repo's GitHub Releases — no Sparkle, no signing
/// keys, no manual steps. It checks the latest release on launch and periodically; when a newer
/// version exists it offers to install, reusing the proven `install.sh` (download → install to
/// /Applications → clear quarantine → relaunch).
@MainActor
final class GitHubUpdater: ObservableObject {
    static let repo = "rdcstarr/rec-translate"
    private let installScriptURL = "https://raw.githubusercontent.com/rdcstarr/rec-translate/main/install.sh"
    private let checkInterval: TimeInterval = 6 * 60 * 60 // 6 hours

    @Published private(set) var isChecking = false
    private var timer: Timer?

    private struct Release: Decodable {
        let tagName: String
        let body: String?
        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case body
        }
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// (Re)arm automatic background checks: a few seconds after launch, then every `checkInterval`.
    func startAutomaticChecks(enabled: Bool) {
        timer?.invalidate()
        timer = nil
        guard enabled else { return }

        Task { @MainActor in
            try? await Task.sleep(for: .seconds(6))
            await checkForUpdates(userInitiated: false)
        }
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in await self.checkForUpdates(userInitiated: false) }
        }
    }

    /// Check GitHub for a newer release. `userInitiated` also surfaces "up to date" / errors.
    func checkForUpdates(userInitiated: Bool) async {
        guard !isChecking else { return }
        isChecking = true
        defer { isChecking = false }

        do {
            let latest = try await fetchLatestRelease()
            let latestVersion = latest.tagName.hasPrefix("v") ? String(latest.tagName.dropFirst()) : latest.tagName
            if isVersion(latestVersion, newerThan: currentVersion) {
                presentUpdatePrompt(latestVersion: latestVersion, notes: latest.body)
            } else if userInitiated {
                presentInfo(title: "You're up to date", message: "Rec Translate v\(currentVersion) is the latest version.")
            }
        } catch {
            if userInitiated {
                presentInfo(title: "Couldn't check for updates", message: error.localizedDescription)
            }
        }
    }

    // MARK: - Networking

    private func fetchLatestRelease() async throws -> Release {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("RecTranslate", forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 20

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw NSError(
                domain: "GitHubUpdater",
                code: (response as? HTTPURLResponse)?.statusCode ?? -1,
                userInfo: [NSLocalizedDescriptionKey: "Couldn't reach GitHub releases."]
            )
        }
        return try JSONDecoder().decode(Release.self, from: data)
    }

    /// Dotted-version comparison by numeric components: "0.1.10" > "0.1.2", and "1.0.0" == "1.0"
    /// (so a tag that only adds a trailing ".0" never triggers a spurious update).
    private func isVersion(_ candidate: String, newerThan current: String) -> Bool {
        func components(_ s: String) -> [Int] {
            s.split(separator: ".").map { part in Int(part.prefix(while: { $0.isNumber })) ?? 0 }
        }
        let a = components(candidate)
        let b = components(current)
        for i in 0 ..< max(a.count, b.count) {
            let x = i < a.count ? a[i] : 0
            let y = i < b.count ? b[i] : 0
            if x != y { return x > y }
        }
        return false
    }

    // MARK: - UI

    private func presentUpdatePrompt(latestVersion: String, notes: String?) {
        let alert = NSAlert()
        alert.messageText = "Update available — v\(latestVersion)"
        var info = "You have v\(currentVersion). Install now? Rec Translate will quit, update, and reopen."
        if let notes, !notes.isEmpty {
            info += "\n\n" + String(notes.prefix(500))
        }
        alert.informativeText = info
        alert.addButton(withTitle: "Install & Relaunch")
        alert.addButton(withTitle: "Later")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            installUpdate()
        }
    }

    private func presentInfo(title: String, message: String) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    // MARK: - Install

    /// Run the installer detached (it downloads the latest release, installs to /Applications,
    /// clears quarantine, and reopens the app), then quit so it can replace this bundle.
    private func installUpdate() {
        // Fully detach the installer (nohup + background + disown) so it survives this app's
        // termination, and run curl INSIDE the detached process — not in the parent shell's
        // command substitution — so a quit mid-download can't kill it.
        let detached = "nohup /bin/bash -c 'curl -fsSL \(installScriptURL) | /bin/bash' "
            + ">/tmp/rectranslate-update.log 2>&1 & disown"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = ["-c", detached]
        do {
            try process.run()
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(500))
                NSApp.terminate(nil)
            }
        } catch {
            presentInfo(title: "Update failed to start", message: error.localizedDescription)
        }
    }
}
