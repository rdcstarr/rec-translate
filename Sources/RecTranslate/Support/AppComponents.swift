import SwiftUI

// MARK: - Optional tooltip

/// Applies `.help` only when text is provided, so call sites without a tooltip stay unchanged.
struct OptionalHelp: ViewModifier {
    let text: String?
    init(_ text: String?) { self.text = text }

    func body(content: Content) -> some View {
        if let text { content.help(text) } else { content }
    }
}

// MARK: - Clear / close button

/// Standard close/clear control: an `xmark.circle.fill` glyph tinted `.secondary`. `variant`
/// selects the hit area so existing per-site behavior is preserved: `.borderless` (chooser close,
/// clear-search) keeps the tight system area; `.icon` (clear-input) keeps the 28×24 hover area.
struct ClearButton: View {
    enum Variant { case borderless, icon }

    var symbol: String = "xmark.circle.fill"
    var help: String? = nil
    var variant: Variant = .borderless
    let action: () -> Void

    var body: some View {
        Group {
            switch variant {
            case .borderless:
                Button(action: action) { glyph }.buttonStyle(.borderless)
            case .icon:
                Button(action: action) { glyph }.buttonStyle(.appIcon)
            }
        }
        .modifier(OptionalHelp(help))
    }

    private var glyph: some View {
        Image(systemName: symbol).foregroundStyle(.secondary)
    }
}

// MARK: - Language picker trigger

/// Language picker trigger used in the language bar: flag + name + chevron, hover style.
struct FlagLabelButton: View {
    let code: String
    let name: String
    var help: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 5) {
                FlagImage(code: code, width: Theme.FlagSize.bar.width, height: Theme.FlagSize.bar.height)
                Text(name).lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .opacity(Theme.Opacity.chevron)
            }
        }
        .buttonStyle(.appHover)
        .modifier(OptionalHelp(help))
    }
}

// MARK: - Accent highlight pill

/// Accent-tinted highlight fill. Two presets keep the existing distinct looks:
/// `.selectedRow` = opacity 0.15 in a continuous RoundedRectangle (radius 7);
/// `.banner` = opacity 0.18 in a Capsule.
struct AccentPill: ViewModifier {
    enum Kind { case selectedRow(active: Bool), banner }

    let kind: Kind

    func body(content: Content) -> some View {
        switch kind {
        case let .selectedRow(active):
            content.background(
                active ? Theme.accentPill(Theme.Opacity.selectedPill) : Color.clear,
                in: RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous)
            )
        case .banner:
            content.background(Theme.accentPill(Theme.Opacity.bannerPill), in: Capsule())
        }
    }
}

extension View {
    func accentPill(_ kind: AccentPill.Kind) -> some View { modifier(AccentPill(kind: kind)) }
}

// MARK: - Update banner CTA

/// Primary accent CTA banner: full-width capsule with leading icon + message + bold "Install".
struct UpdateBannerButton: View {
    let version: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
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
            .accentPill(.banner)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Download and install v\(version)")
    }
}

// MARK: - Section header with trailing action

/// A `Divider()` followed by an `HStack` of leading content, a spacer, and a trailing action.
/// Used by the result header (Detected + Copy) and the history header (History + Clear).
struct SectionActionHeader<Leading: View, Trailing: View>: View {
    private let leading: Leading
    private let trailing: Trailing

    init(@ViewBuilder leading: () -> Leading, @ViewBuilder trailing: () -> Trailing) {
        self.leading = leading()
        self.trailing = trailing()
    }

    var body: some View {
        Divider()
        HStack {
            leading
            Spacer()
            trailing
        }
    }
}
