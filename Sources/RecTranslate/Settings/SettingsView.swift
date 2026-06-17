import SwiftUI
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences

    @State private var apiKeyInput = ""
    @State private var apiKeyStored = false
    @State private var apiKeyStatus = ""
    @State private var permissionRefresh = false // toggled to re-read Accessibility status

    var body: some View {
        TabView {
            translationTab
                .tabItem { Label("Translation", systemImage: "globe") }
            shortcutsTab
                .tabItem { Label("Shortcuts", systemImage: "keyboard") }
            updatesTab
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
        }
        .frame(width: 480)
        .onAppear { apiKeyStored = (KeychainStore.apiKey?.isEmpty == false) }
    }

    // MARK: - Translation

    private var translationTab: some View {
        Form {
            Section("Languages") {
                Picker("Source", selection: $preferences.sourceCode) {
                    ForEach(Languages.sources) { Text($0.name).tag($0.code) }
                }
                Picker("Target", selection: $preferences.targetCode) {
                    ForEach(Languages.targets) { Text($0.name).tag($0.code) }
                }
            }

            Section("Service") {
                TextField("API base URL", text: $preferences.baseURLString, prompt: Text("https://proxy123.click"))
                    .textContentType(.URL)
                    .autocorrectionDisabled()

                SecureField("proxy123 API token", text: $apiKeyInput, prompt: Text(apiKeyStored ? "•••••••• (stored)" : "Paste your token"))
                HStack {
                    Button("Save Token") { saveKey() }
                        .disabled(apiKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                    if apiKeyStored {
                        Button("Remove", role: .destructive) { removeKey() }
                    }
                    Spacer()
                    Text(apiKeyStatus).font(.caption).foregroundStyle(.secondary)
                }
                Text("Use your proxy123 **API_BEARER_TOKEN**. It is stored in your Keychain.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Behavior") {
                Toggle("Copy translation automatically", isOn: $preferences.autoCopy)
                Stepper("Keep last \(preferences.historyLimit) translations", value: $preferences.historyLimit, in: 0...100)
                Button("Clear History") { HistoryStore.shared.clear() }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Shortcuts

    private var shortcutsTab: some View {
        Form {
            Section("Global shortcut") {
                KeyboardShortcuts.Recorder("Open popup:", name: .toggleTranslator)
                Text("Press the field and record any combination. Fires system-wide and needs no extra permission.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Double-tap Shift") {
                Toggle("Also open with a double-tap of Shift", isOn: $preferences.doubleShiftEnabled)
                    .onChange(of: preferences.doubleShiftEnabled) { _, enabled in
                        if enabled, !DoubleShiftMonitor.hasAccessibilityPermission() {
                            DoubleShiftMonitor.requestAccessibilityPermission()
                        }
                        AppEnvironment.shared.applyDoubleShiftSetting()
                        permissionRefresh.toggle()
                    }

                if preferences.doubleShiftEnabled {
                    accessibilityStatusRow
                }
            }
        }
        .formStyle(.grouped)
    }

    private var accessibilityStatusRow: some View {
        let granted = DoubleShiftMonitor.hasAccessibilityPermission()
        return HStack {
            if granted {
                Label("Accessibility permission granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                Spacer()
                Button("Grant…") {
                    DoubleShiftMonitor.requestAccessibilityPermission()
                    permissionRefresh.toggle()
                }
            }
        }
        .font(.callout)
        .id(permissionRefresh)
    }

    // MARK: - Updates

    private var updatesTab: some View {
        Form {
            Section("Updates") {
                Toggle("Automatically check for updates", isOn: $preferences.autoCheckUpdates)
                Button("Check for Updates…") {
                    Task { await AppEnvironment.shared.updater.checkForUpdates(userInitiated: true) }
                }
                Text("Checks this project's GitHub Releases and updates in place — no manual steps.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                LabeledContent("Version", value: appVersion)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Helpers

    private var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private func saveKey() {
        do {
            try KeychainStore.setAPIKey(apiKeyInput)
            apiKeyStored = true
            apiKeyInput = ""
            apiKeyStatus = "Saved."
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try KeychainStore.setAPIKey("")
            apiKeyStored = false
            apiKeyInput = ""
            apiKeyStatus = "Removed."
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }
}
