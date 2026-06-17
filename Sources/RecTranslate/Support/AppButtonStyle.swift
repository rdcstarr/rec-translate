import SwiftUI

/// The single hover/press button style for the whole app. `.appIcon` is the fixed 28×24 hit area
/// (menu-bar style icons: swap / history / settings / more / clear-input); `.appHover` is
/// content-sized with padding (language buttons, Copy). Both share the same hover/press fills and
/// animation — only shape and sizing differ.
struct AppButtonStyle: ButtonStyle {
    enum Variant { case icon, hover }

    let variant: Variant

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(variant: variant, configuration: configuration)
    }

    // Named AppButtonBody (not `Body`) to avoid clashing with ButtonStyle's `associatedtype Body`.
    private struct AppButtonBody: View {
        let variant: Variant
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        private var radius: CGFloat {
            variant == .icon ? Theme.Radius.iconButton : Theme.Radius.control
        }

        private var fill: Color {
            Color.primary.opacity(
                configuration.isPressed ? Theme.Opacity.pressedFill
                    : (hovering ? Theme.Opacity.hoverFill : 0)
            )
        }

        @ViewBuilder private var sized: some View {
            switch variant {
            case .icon:
                configuration.label
                    .frame(width: Theme.Metrics.iconButtonWidth, height: Theme.Metrics.iconButtonHeight)
            case .hover:
                configuration.label
                    .padding(.horizontal, Theme.Metrics.hoverButtonHPadding)
                    .padding(.vertical, Theme.Metrics.hoverButtonVPadding)
            }
        }

        var body: some View {
            sized
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fill))
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { hovering = $0 }
                .animation(Theme.Motion.control, value: hovering)
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    /// Fixed 28×24 icon button (was `IconButtonStyle`).
    static var appIcon: AppButtonStyle { AppButtonStyle(variant: .icon) }
    /// Content-sized padded hover button (was `HoverButtonStyle`).
    static var appHover: AppButtonStyle { AppButtonStyle(variant: .hover) }
}
