import SwiftUI

/// The ChatGPT "Chat Bar"-style popup: a language bar (flag + name buttons), a large input field
/// (Return translates, ⇧Return = newline, Esc closes), the result with Copy, and history.
/// Tapping a language opens an in-panel searchable chooser (autofocused search, flag list).
struct PopupView: View {
    @EnvironmentObject private var vm: PopupViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore

    @FocusState private var inputFocused: Bool
    @FocusState private var searchFocused: Bool
    @State private var showingHistory = false
    @State private var picking: PickerField?
    @State private var query = ""

    let onClose: () -> Void

    private enum PickerField { case source, target }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
            }
            .buttonStyle(.borderless)
            .disabled(preferences.sourceCode == Language.auto.code)
            .help("Swap languages")

            languageButton(.target)

            Spacer()

            Button {
                showingHistory.toggle()
            } label: {
                Image(systemName: "clock.arrow.circlepath")
            }
            .buttonStyle(.borderless)
            .help("History")
            .disabled(history.entries.isEmpty)
        }
        .foregroundStyle(.secondary)
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
                Text(lang.flag)
                Text(lang.name).lineLimit(1)
                Image(systemName: "chevron.down").font(.caption2).opacity(0.6)
            }
        }
        .buttonStyle(.borderless)
        .help(field == .source ? "Source language" : "Target language")
    }

    // MARK: - Searchable chooser (in-panel, no extra window)

    private func languageChooser(_ field: PickerField) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Search language…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .onAppear { searchFocused = true }
                .onKeyPress(.escape) {
                    closePicker()
                    return .handled
                }
            Divider()
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filtered(field)) { lang in
                        Button {
                            select(lang, for: field)
                        } label: {
                            HStack(spacing: 8) {
                                Text(lang.flag)
                                Text(lang.name)
                                Spacer()
                                if code(for: field) == lang.code {
                                    Image(systemName: "checkmark").font(.caption).foregroundStyle(.tint)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxHeight: 240)
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
        TextField("Type or paste text, then press Return…", text: $vm.inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 18))
            .lineLimit(1...8)
            .focused($inputFocused)
            .onKeyPress(phases: .down) { press in
                if press.key == .return {
                    if press.modifiers.contains(.shift) { return .ignored }
                    vm.requestTranslate()
                    return .handled
                }
                if press.key == .escape {
                    onClose()
                    return .handled
                }
                return .ignored
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
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .keyboardShortcut("c", modifiers: .command)
                .help("Copy translation (⌘C)")
            }
            Text(result.translation)
                .font(.system(size: 18))
                .textSelection(.enabled)
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
                                Text("\(Languages.flag(for: entry.sourceCode)) \(Languages.name(for: entry.sourceCode)) → \(Languages.flag(for: entry.targetCode)) \(Languages.name(for: entry.targetCode))")
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
