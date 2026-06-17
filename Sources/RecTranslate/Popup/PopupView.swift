import SwiftUI
import AppKit

/// The ChatGPT "Chat Bar"-style popup: a language bar (flag + name buttons), a large input field
/// (Return translates, ⇧Return = newline, Esc closes), the result with Copy, and history.
/// Tapping a language opens an in-panel searchable chooser (autofocused search, flag list).
struct PopupView: View {
    @EnvironmentObject private var vm: PopupViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var updater: GitHubUpdater

    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var showingHistory = false
    @State private var picking: PickerField?
    @State private var query = ""
    @State private var focusRequested = false

    let onClose: () -> Void

    private enum PickerField { case source, target }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let version = updater.availableUpdate {
                updateBanner(version)
            }

            languageBar

            if let picking {
                languageChooser(picking)
            } else {
                inputField

                if vm.isTranslating {
                    HStack(spacing: 8) {
                        ProgressView().controlSize(.small)
                        Text("Translating…").foregroundStyle(.secondary)
                    }
                    .font(.callout)
                }

                if let error = vm.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.callout)
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let result = vm.result {
                    resultView(result)
                }

                if showingHistory, !history.entries.isEmpty {
                    historyView
                }
            }
        }
        .padding(18)
        .frame(width: 600, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: .black.opacity(0.30), radius: 26, x: 0, y: 12)
        .padding(24)
        .onAppear { focusInput() }
        .onReceive(NotificationCenter.default.publisher(for: .focusPopupInput)) { _ in
            if picking == nil { focusInput() }
        }
    }

    // MARK: - Language bar

    private var languageBar: some View {
        HStack(spacing: 8) {
            languageButton(.source)

            Button {
                vm.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(.system(size: 12, weight: .semibold))
            }
            .buttonStyle(IconButtonStyle())
            .disabled(preferences.sourceCode == Language.auto.code)
            .help(preferences.sourceCode == Language.auto.code ? "Pick a source language to swap" : "Swap languages")

            languageButton(.target)

            Spacer()

            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(IconButtonStyle())
            .help("History")
            .disabled(history.entries.isEmpty)

            Button {
                onClose() // hide the popup first so the Settings window reliably comes to the front
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(IconButtonStyle())
            .help("Settings")

            Menu {
                Button("Check for Updates…") {
                    Task { await AppEnvironment.shared.updater.checkForUpdates(userInitiated: true) }
                }
                Divider()
                Button("Quit Rec Translate") { NSApp.terminate(nil) }
            } label: {
                Image(systemName: "ellipsis").foregroundStyle(.secondary)
            }
            .menuStyle(.button)
            .buttonStyle(IconButtonStyle())
            .menuIndicator(.hidden)
            .overlay(alignment: .topTrailing) {
                if updater.availableUpdate != nil {
                    Circle()
                        .fill(.red)
                        .frame(width: 7, height: 7)
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                        .offset(x: -2, y: 3)
                }
            }
            .help(updater.availableUpdate != nil ? "Update available — open menu to install" : "More")
        }
        .foregroundStyle(.secondary)
    }

    private func updateBanner(_ version: String) -> some View {
        Button {
            updater.installUpdate()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "arrow.down.circle.fill")
                Text("Update available — v\(version)")
                Spacer()
                Text("Install").fontWeight(.semibold)
            }
            .font(.callout)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
            .background(Color.accentColor.opacity(0.18), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Download and install v\(version)")
    }

    private func languageButton(_ field: PickerField) -> some View {
        let lang = Languages.language(for: code(for: field))
        return Button {
            if picking == field {
                closePicker()
            } else {
                picking = field
                query = ""
            }
        } label: {
            HStack(spacing: 5) {
                FlagImage(code: lang.code, width: 20, height: 14)
                Text(lang.name).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2).opacity(0.6)
            }
        }
        .buttonStyle(HoverButtonStyle())
        .help(field == .source ? "Source language" : "Target language")
    }

    // MARK: - Searchable chooser (in-panel, no extra window)

    private func languageChooser(_ field: PickerField) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(field == .source ? "Translate from" : "Translate to")
                    .font(.headline)
                Spacer()
                Button { closePicker() } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(.borderless)
                .help("Close")
            }

            // Search box (icon + clear button). Autofocus is deferred one state cycle so it lands
            // after the field is committed into the focus tree (the panel is key via canBecomeKey).
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
                TextField("Search language…", text: $query)
                    .textFieldStyle(.plain)
                    .focused($searchFocused)
                    .onAppear { focusRequested = true }
                    .onChange(of: focusRequested) { _, requested in
                        if requested {
                            searchFocused = true
                            focusRequested = false
                        }
                    }
                    .onKeyPress(.escape) {
                        closePicker()
                        return .handled
                    }
                if !query.isEmpty {
                    Button { query = "" } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(8)
            .background(.quaternary.opacity(0.6), in: RoundedRectangle(cornerRadius: 9, style: .continuous))

            ScrollView {
                VStack(spacing: 2) {
                    let matches = filtered(field)
                    ForEach(matches) { lang in
                        let isSelected = code(for: field) == lang.code
                        Button {
                            select(lang, for: field)
                        } label: {
                            HStack(spacing: 10) {
                                FlagImage(code: lang.code)
                                Text(lang.name)
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark").foregroundStyle(.tint)
                                }
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 7)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.15) : Color.clear,
                                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
                            )
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    if matches.isEmpty {
                        Text("No matches")
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 10)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    private func options(for field: PickerField) -> [Language] {
        field == .source ? Languages.sources : Languages.targets
    }

    private func filtered(_ field: PickerField) -> [Language] {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        let all = options(for: field)
        guard !q.isEmpty else { return all }
        return all.filter { $0.name.lowercased().contains(q) || $0.code.lowercased().contains(q) }
    }

    private func code(for field: PickerField) -> String {
        field == .source ? preferences.sourceCode : preferences.targetCode
    }

    @MainActor private func select(_ lang: Language, for field: PickerField) {
        switch field {
        case .source: preferences.sourceCode = lang.code
        case .target: preferences.targetCode = lang.code
        }
        closePicker()
    }

    @MainActor private func closePicker() {
        picking = nil
        query = ""
        focusInput()
    }

    // MARK: - Input + result

    private var inputField: some View {
        HStack(alignment: .top, spacing: 6) {
            // TextField (not TextEditor) so there's no scroll-view chrome / black scroller line.
            TextField("Type or paste text — Return translates, ⇧Return = new line", text: $vm.inputText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: 18))
                .lineLimit(1 ... 8)
                .focused($inputFocused)
                .onKeyPress(phases: .down) { press in
                    if press.key == .return {
                        // TextField(axis:.vertical) doesn't insert a newline on its own, so do it
                        // explicitly for Shift+Return; plain Return translates.
                        if NSEvent.modifierFlags.contains(.shift) {
                            vm.inputText += "\n"
                            return .handled
                        }
                        vm.requestTranslate()
                        return .handled
                    }
                    if press.key == .escape {
                        onClose()
                        return .handled
                    }
                    return .ignored
                }

            if !vm.inputText.isEmpty {
                Button {
                    vm.clearInput()
                    inputFocused = true
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
                .buttonStyle(IconButtonStyle())
                .help("Clear")
            }
        }
    }

    private func resultView(_ result: TranslationOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                if let detected = result.detectedSourceName {
                    Text("Detected: \(detected)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    vm.copyResult()
                } label: {
                    Label(vm.justCopied ? "Copied" : "Copy",
                          systemImage: vm.justCopied ? "checkmark" : "doc.on.doc")
                        .foregroundStyle(vm.justCopied ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
                }
                .buttonStyle(HoverButtonStyle())
                .animation(.easeOut(duration: 0.15), value: vm.justCopied)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy translation (⌘C)")
            }
            Text(result.translation)
                .font(.system(size: 18))
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true) // show ALL lines (don't clip to one)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()
            HStack {
                Text("History")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Clear") {
                    history.clear()
                    showingHistory = false
                }
                .buttonStyle(.borderless)
                .font(.caption)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(history.entries) { entry in
                        Button {
                            vm.loadFromHistory(entry)
                            showingHistory = false
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    FlagImage(code: entry.sourceCode, width: 16, height: 12)
                                    Text(Languages.name(for: entry.sourceCode))
                                    Image(systemName: "arrow.right").font(.caption2)
                                    FlagImage(code: entry.targetCode, width: 16, height: 12)
                                    Text(Languages.name(for: entry.targetCode))
                                }
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                                Text(entry.original)
                                    .lineLimit(1)
                                    .foregroundStyle(.secondary)
                                Text(entry.translation)
                                    .lineLimit(2)
                            }
                            .font(.callout)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                            .padding(.vertical, 6)
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(0.35)
                    }
                }
            }
            .frame(maxHeight: 260)
        }
    }

    @MainActor private func focusInput() {
        inputFocused = true
    }
}
