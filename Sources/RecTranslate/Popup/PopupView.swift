import SwiftUI

/// The ChatGPT "Chat Bar"-style popup contents: a language bar, a large input field
/// (Return translates, ⇧Return inserts a newline, Esc closes), the result with a Copy
/// action, and a compact recent-history list.
struct PopupView: View {
    @EnvironmentObject private var vm: PopupViewModel
    @EnvironmentObject private var preferences: Preferences
    @EnvironmentObject private var history: HistoryStore

    @FocusState private var inputFocused: Bool

    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            languageBar
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

            if !history.entries.isEmpty {
                recentView
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
        .padding(24) // room for the shadow inside the clear window
        .onAppear { focusInput() }
        .onReceive(NotificationCenter.default.publisher(for: .focusPopupInput)) { _ in focusInput() }
    }

    // MARK: - Sections

    private var languageBar: some View {
        HStack(spacing: 8) {
            Picker("", selection: $preferences.sourceCode) {
                ForEach(Languages.sources) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Button {
                vm.swapLanguages()
            } label: {
                Image(systemName: "arrow.left.arrow.right")
            }
            .buttonStyle(.borderless)
            .disabled(preferences.sourceCode == Language.auto.code)
            .help("Swap languages")

            Picker("", selection: $preferences.targetCode) {
                ForEach(Languages.targets) { lang in
                    Text(lang.name).tag(lang.code)
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .fixedSize()

            Spacer()
        }
        .foregroundStyle(.secondary)
    }

    private var inputField: some View {
        TextField("Type or paste text, then press Return…", text: $vm.inputText, axis: .vertical)
            .textFieldStyle(.plain)
            .font(.system(size: 18))
            .lineLimit(1...8)
            .focused($inputFocused)
            .onKeyPress(phases: .down) { press in
                if press.key == .return {
                    if press.modifiers.contains(.shift) { return .ignored }
                    Task { await vm.translate() }
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

    private var recentView: some View {
        VStack(alignment: .leading, spacing: 6) {
            Divider()
            Text("Recent")
                .font(.caption.bold())
                .foregroundStyle(.secondary)
            ForEach(history.entries.prefix(4)) { entry in
                Button {
                    vm.loadFromHistory(entry)
                } label: {
                    HStack(spacing: 6) {
                        Text(entry.original)
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        Image(systemName: "arrow.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(entry.translation)
                            .lineLimit(1)
                        Spacer()
                    }
                    .font(.caption)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    @MainActor private func focusInput() {
        inputFocused = true
    }
}
