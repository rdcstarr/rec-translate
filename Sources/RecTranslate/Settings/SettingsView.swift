import SwiftUI
import AppKit
import KeyboardShortcuts

struct SettingsView: View {
    @EnvironmentObject private var preferences: Preferences

    @State private var apiKeyInput = ""
    @State private var apiKeyStored = false
    @State private var apiKeyStatus = ""
    @State private var openAIKeyInput = ""
    @State private var openAIKeyStored = false
    @State private var openAIKeyStatus = ""
    @State private var deepseekKeyInput = ""
    @State private var deepseekKeyStored = false
    @State private var deepseekKeyStatus = ""
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
        .frame(width: Theme.Metrics.settingsWidth)
        .onAppear {
            apiKeyStored = (TokenStore.apiKey?.isEmpty == false)
            openAIKeyStored = (TokenStore.openAIKey?.isEmpty == false)
            deepseekKeyStored = (TokenStore.deepseekKey?.isEmpty == false)
        }
    }

    private var engineHelpText: String {
        switch preferences.engine {
        case .openai: "OpenAI (your key) gives higher-quality, context-aware translations — it costs per use and is a bit slower."
        case .deepseek: "DeepSeek (your key) is high quality at low cost via its OpenAI-compatible API — costs per use, a bit slower than Google."
        case .google: "Google is fast and free (via your proxy123 server)."
        }
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

            Section("Engine") {
                Picker("Translate with", selection: $preferences.engine) {
                    ForEach(TranslationEngine.allCases) { Text($0.displayName).tag($0) }
                }
                Text(engineHelpText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if preferences.engine == .google {
                Section("Google service") {
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
                    Text("Use your proxy123 **API_BEARER_TOKEN**. It is stored locally in a protected file (only your user can read it).")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else if preferences.engine == .openai {
                Section("OpenAI") {
                    SecureField("OpenAI API key", text: $openAIKeyInput, prompt: Text(openAIKeyStored ? "•••••••• (stored)" : "Paste your sk-… key"))
                    HStack {
                        Button("Save Key") { saveOpenAIKey() }
                            .disabled(openAIKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        if openAIKeyStored {
                            Button("Remove", role: .destructive) { removeOpenAIKey() }
                        }
                        Spacer()
                        Text(openAIKeyStatus).font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Model", text: $preferences.openAIModel, prompt: Text(Preferences.defaultOpenAIModel))
                        .autocorrectionDisabled()
                    Text("Create a key at platform.openai.com. Stored locally in a protected file. `gpt-5.4-mini` is cheap, fast and great for translation; use `gpt-5.4` or `gpt-5.5` for nuanced text. (OpenAI has no dedicated text-translation model — this uses Chat Completions.)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section("DeepSeek") {
                    SecureField("DeepSeek API key", text: $deepseekKeyInput, prompt: Text(deepseekKeyStored ? "•••••••• (stored)" : "Paste your sk-… key"))
                    HStack {
                        Button("Save Key") { saveDeepSeekKey() }
                            .disabled(deepseekKeyInput.trimmingCharacters(in: .whitespaces).isEmpty)
                        if deepseekKeyStored {
                            Button("Remove", role: .destructive) { removeDeepSeekKey() }
                        }
                        Spacer()
                        Text(deepseekKeyStatus).font(.caption).foregroundStyle(.secondary)
                    }
                    TextField("Model", text: $preferences.deepseekModel, prompt: Text(Preferences.defaultDeepSeekModel))
                        .autocorrectionDisabled()
                    Text("Create a key at platform.deepseek.com. Stored locally in a protected file. Uses the OpenAI-compatible Chat Completions API; `deepseek-chat` is the standard model.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Behavior") {
                Toggle("Translate automatically as you type", isOn: $preferences.autoTranslate)
                Toggle("Copy translation automatically", isOn: $preferences.autoCopy)
                Stepper("Text size: \(preferences.fontSizeBody) pt", value: $preferences.fontSizeBody, in: 12 ... 28)
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            // Returning from System Settings after granting: re-read the status and restart the
            // global monitor so the permission can take effect without a relaunch when possible.
            AppEnvironment.shared.applyDoubleShiftSetting()
            permissionRefresh.toggle()
        }
    }

    private var accessibilityStatusRow: some View {
        let granted = DoubleShiftMonitor.hasAccessibilityPermission()
        return VStack(alignment: .leading, spacing: 6) {
            HStack {
                if granted {
                    Label("Accessibility permission granted", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Label("Needs Accessibility permission", systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    Spacer()
                    Button("Open Accessibility Settings") { openAccessibilitySettings() }
                }
            }
            .font(.callout)
            Text("If it still says “Needs permission” after granting, the entry is **stale from a previous update**: free/ad-hoc builds change signature on every update, so macOS keeps showing the old toggle as on but doesn’t actually trust the new build. Fix it in Accessibility — select **Rec Translate**, click **“–”** to remove it, then **“+”** to add it back, and **quit & reopen** the app. The recorded shortcut above always works without this permission.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .id(permissionRefresh)
    }

    private func openAccessibilitySettings() {
        DoubleShiftMonitor.requestAccessibilityPermission()
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
        permissionRefresh.toggle()
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
            try TokenStore.setAPIKey(apiKeyInput)
            apiKeyStored = true
            apiKeyInput = ""
            apiKeyStatus = "Saved."
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }

    private func removeKey() {
        do {
            try TokenStore.setAPIKey("")
            apiKeyStored = false
            apiKeyInput = ""
            apiKeyStatus = "Removed."
        } catch {
            apiKeyStatus = error.localizedDescription
        }
    }

    private func saveOpenAIKey() {
        do {
            try TokenStore.setOpenAIKey(openAIKeyInput)
            openAIKeyStored = true
            openAIKeyInput = ""
            openAIKeyStatus = "Saved."
        } catch {
            openAIKeyStatus = error.localizedDescription
        }
    }

    private func removeOpenAIKey() {
        do {
            try TokenStore.setOpenAIKey("")
            openAIKeyStored = false
            openAIKeyInput = ""
            openAIKeyStatus = "Removed."
        } catch {
            openAIKeyStatus = error.localizedDescription
        }
    }

    private func saveDeepSeekKey() {
        do {
            try TokenStore.setDeepseekKey(deepseekKeyInput)
            deepseekKeyStored = true
            deepseekKeyInput = ""
            deepseekKeyStatus = "Saved."
        } catch {
            deepseekKeyStatus = error.localizedDescription
        }
    }

    private func removeDeepSeekKey() {
        do {
            try TokenStore.setDeepseekKey("")
            deepseekKeyStored = false
            deepseekKeyInput = ""
            deepseekKeyStatus = "Removed."
        } catch {
            deepseekKeyStatus = error.localizedDescription
        }
    }
}
