import SwiftUI

/// The single hover/press button style for the whole app. `.appIcon` is the fixed 28×24 hit area
/// (menu-bar style icons: swap / history / settings / more / clear-input); `.appHover` is
/// content-sized with padding (language buttons, Copy). Both share the same hover/press fills and
/// animation — only shape and sizing differ.
struct AppButtonStyle: ButtonStyle {
    enum Variant { case icon, hover }

    var variant: Variant
    /// A toggle button that is currently "on" (e.g. History while the list is open) keeps a
    /// persistent accent-tinted background so it reads as active.
    var isActive: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        AppButtonBody(variant: variant, isActive: isActive, configuration: configuration)
    }

    // Named AppButtonBody (not `Body`) to avoid clashing with ButtonStyle's `associatedtype Body`.
    private struct AppButtonBody: View {
        let variant: Variant
        let isActive: Bool
        let configuration: ButtonStyleConfiguration
        @State private var hovering = false

        private var radius: CGFloat {
            variant == .icon ? Theme.Radius.iconButton : Theme.Radius.control
        }

        private var fillStyle: AnyShapeStyle {
            if configuration.isPressed { return AnyShapeStyle(Color.primary.opacity(Theme.Opacity.pressedFill)) }
            if hovering { return AnyShapeStyle(Color.primary.opacity(Theme.Opacity.hoverFill)) }
            if isActive { return AnyShapeStyle(Color.accentColor.opacity(Theme.Opacity.selectedPill)) }
            return AnyShapeStyle(Color.clear)
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
                .background(RoundedRectangle(cornerRadius: radius, style: .continuous).fill(fillStyle))
                .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .onHover { hovering = $0 }
                .animation(Theme.Motion.control, value: hovering)
                .animation(Theme.Motion.control, value: isActive)
        }
    }
}

extension ButtonStyle where Self == AppButtonStyle {
    /// Fixed 28×24 icon button (was `IconButtonStyle`).
    static var appIcon: AppButtonStyle { AppButtonStyle(variant: .icon) }
    /// Fixed 28×24 icon button that shows an active/selected state (e.g. History toggle).
    static func appIcon(active: Bool) -> AppButtonStyle { AppButtonStyle(variant: .icon, isActive: active) }
    /// Content-sized padded hover button (was `HoverButtonStyle`).
    static var appHover: AppButtonStyle { AppButtonStyle(variant: .hover) }
}
