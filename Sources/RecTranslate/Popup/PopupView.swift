import SwiftUI
import AppKit

/// The ChatGPT "Chat Bar"-style popup: a language bar (flag + name buttons), a large input field
/// (Return translates, ⇧Return = newline, Esc closes), the result with Copy, and history.
/// Tapping a language opens an in-panel searchable chooser (autofocused search, flag list).
///
/// Visuals come from `Theme` tokens and the reusable controls in Support/ (AppButtonStyle,
/// ClearButton, FlagLabelButton, UpdateBannerButton, AccentPill, SectionActionHeader) so the
/// whole UI shares one style system.
struct PopupView: View {
    @EnvironmentObject private var vm: PopupViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore
    @EnvironmentObject private var updater: GitHubUpdater

    @State private var inputFocusTick = 0 // bumped to (re)focus the NSTextView-backed input
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
                UpdateBannerButton(version: version) { updater.installUpdate() }
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
        .padding(Theme.Metrics.cardContentPadding)
        .frame(width: Theme.Metrics.cardWidth, alignment: .leading)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                .strokeBorder(.white.opacity(Theme.Opacity.cardBorder), lineWidth: Theme.Metrics.cardBorderWidth)
        )
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        .shadow(color: .black.opacity(Theme.Opacity.cardShadow), radius: Theme.Metrics.cardShadowRadius, x: 0, y: Theme.Metrics.cardShadowY)
        .padding(Theme.Metrics.cardOuterPadding)
        .onAppear { focusInput() }
        .onReceive(NotificationCenter.default.publisher(for: .focusPopupInput)) { _ in
            if picking == nil { focusInput() }
        }
        .onChange(of: preferences.sourceCode) { _, _ in vm.retranslateForLanguageChange() }
        .onChange(of: preferences.targetCode) { _, _ in vm.retranslateForLanguageChange() }
    }

    // MARK: - Language bar

    private var languageBar: some View {
        HStack(spacing: 8) {
            languageButton(.source)

            Button {
                vm.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
                    .font(Theme.Fonts.icon)
            }
            .buttonStyle(.appIcon)
            .disabled(preferences.sourceCode == Language.auto.code)
            .help(preferences.sourceCode == Language.auto.code ? "Pick a source language to swap" : "Swap languages")

            languageButton(.target)

            Spacer()

            Button {
                if picking != nil {
                    // A language chooser is covering the content — close it and reveal history.
                    picking = nil
                    query = ""
                    showingHistory = true
                } else {
                    showingHistory.toggle()
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.appIcon(active: showingHistory && picking == nil))
            .help("History")
            .disabled(history.entries.isEmpty)

            Button {
                onClose() // hide the popup first so the Settings window reliably comes to the front
                NotificationCenter.default.post(name: .openSettingsRequest, object: nil)
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.appIcon)
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
            .buttonStyle(.appIcon)
            .menuIndicator(.hidden)
            .overlay(alignment: .topTrailing) {
                if updater.availableUpdate != nil {
                    Circle()
                        .fill(.red)
                        .frame(width: Theme.Metrics.updateDot, height: Theme.Metrics.updateDot)
                        .overlay(Circle().strokeBorder(.background, lineWidth: 1))
                        .offset(x: -2, y: 3)
                }
            }
            .help(updater.availableUpdate != nil ? "Update available — open menu to install" : "More")
        }
        .foregroundStyle(.secondary)
    }

    private func languageButton(_ field: PickerField) -> some View {
        let lang = Languages.language(for: code(for: field))
        return FlagLabelButton(
            code: lang.code,
            name: lang.name,
            help: field == .source ? "Source language" : "Target language"
        ) {
            if picking == field {
                closePicker()
            } else {
                picking = field
                query = ""
            }
        }
    }

    // MARK: - Searchable chooser (in-panel, no extra window)

    private func languageChooser(_ field: PickerField) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(field == .source ? "Translate from" : "Translate to")
                    .font(.headline)
                Spacer()
                ClearButton(help: "Close", variant: .borderless) { closePicker() }
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
                    ClearButton(variant: .borderless) { query = "" }
                }
            }
            .padding(Theme.Metrics.fieldPadding)
            .background(.quaternary.opacity(Theme.Opacity.fieldFill), in: RoundedRectangle(cornerRadius: Theme.Radius.field, style: .continuous))

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
                            .padding(.horizontal, Theme.Metrics.rowHPadding)
                            .padding(.vertical, Theme.Metrics.rowVPadding)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .accentPill(.selectedRow(active: isSelected))
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
            .frame(maxHeight: Theme.Metrics.scrollMaxHeight)
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
            ZStack(alignment: .topLeading) {
                if vm.inputText.isEmpty {
                    Text("Type or paste text to translate…")
                        .font(Theme.Fonts.largeBody)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2) // align with the text view's container inset
                        .allowsHitTesting(false)
                }
                // NSTextView-backed: Return translates, Shift+Return = newline at the cursor, Esc closes.
                MultilineTextField(
                    text: $vm.inputText,
                    minHeight: 30,
                    maxHeight: 170,
                    focusTick: inputFocusTick,
                    onSubmit: { vm.requestTranslate() },
                    onEscape: { onClose() }
                )
            }

            if !vm.inputText.isEmpty {
                ClearButton(help: "Clear", variant: .icon) {
                    vm.clearInput()
                    inputFocusTick += 1
                }
            }
        }
    }

    private func resultView(_ result: TranslationOutcome) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Divider()

            // Only shown for auto-detect; no empty row when the source is set explicitly.
            if let detected = result.detectedSourceName {
                Text("Detected: \(detected)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // Copy sits next to the text (top-right), so there's no floating empty header line.
            HStack(alignment: .top, spacing: 8) {
                Text(result.translation)
                    .font(Theme.Fonts.largeBody)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true) // show ALL lines (don't clip to one)
                    .frame(maxWidth: .infinity, alignment: .leading)
                copyButton
            }
        }
    }

    private var copyButton: some View {
        Button {
            vm.copyResult()
        } label: {
            Label(vm.justCopied ? "Copied" : "Copy",
                  systemImage: vm.justCopied ? "checkmark" : "doc.on.doc")
                .foregroundStyle(vm.justCopied ? AnyShapeStyle(.green) : AnyShapeStyle(.secondary))
        }
        .buttonStyle(.appHover)
        .animation(Theme.Motion.copyState, value: vm.justCopied)
        .keyboardShortcut("c", modifiers: .command)
        .help("Copy translation (⌘C)")
    }

    private var historyView: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionActionHeader {
                Text("History")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            } trailing: {
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
                                    FlagImage(code: entry.sourceCode, width: Theme.FlagSize.compact.width, height: Theme.FlagSize.compact.height)
                                    Text(Languages.name(for: entry.sourceCode))
                                    Image(systemName: "arrow.right").font(.caption2)
                                    FlagImage(code: entry.targetCode, width: Theme.FlagSize.compact.width, height: Theme.FlagSize.compact.height)
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
                            .padding(.vertical, Theme.Metrics.historyRowVPadding)
                        }
                        .buttonStyle(.plain)
                        Divider().opacity(Theme.Opacity.rowDivider)
                    }
                }
            }
            .frame(maxHeight: Theme.Metrics.scrollMaxHeight)
        }
    }

    @MainActor private func focusInput() {
        inputFocusTick += 1
    }
}
