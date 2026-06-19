import SwiftUI

/// Central design tokens for RecTranslate. Every radius / opacity / padding / font size / color
/// that was duplicated across the UI lives here, so the button style, the card, the chooser, the
/// banner, etc. all reference one source of truth. Values are the EXACT current literals —
/// adopting tokens does not change any pixels.
enum Theme {

    // MARK: Corner radii
    enum Radius {
        static let flag: CGFloat = 2        // FlagImage clip
        static let iconButton: CGFloat = 6   // fixed icon button
        static let control: CGFloat = 7      // hover button + selected row + accent pill
        static let field: CGFloat = 9        // search box container
        static let card: CGFloat = 22        // popup panel
    }

    // MARK: Opacities
    enum Opacity {
        static let hoverFill: Double = 0.09     // hover background (button style)
        static let pressedFill: Double = 0.16   // pressed background (button style)
        static let selectedPill: Double = 0.15  // selected language row accent fill
        static let bannerPill: Double = 0.18    // update banner accent fill
        static let cardBorder: Double = 0.10    // popup white overlay border
        static let cardShadow: Double = 0.30    // popup shadow
        static let fieldFill: Double = 0.6      // search box .quaternary fill
        static let chevron: Double = 0.6        // chevron.down on language buttons
        static let rowDivider: Double = 0.35    // history row divider
    }

    // MARK: Paddings / sizes
    enum Metrics {
        static let iconButtonWidth: CGFloat = 28
        static let iconButtonHeight: CGFloat = 24
        static let hoverButtonHPadding: CGFloat = 8
        static let hoverButtonVPadding: CGFloat = 5
        static let cardContentPadding: CGFloat = 18
        static let cardOuterPadding: CGFloat = 24
        static let fieldPadding: CGFloat = 8
        static let rowHPadding: CGFloat = 8
        static let rowVPadding: CGFloat = 7
        static let historyRowVPadding: CGFloat = 6
        static let cardWidth: CGFloat = 600
        static let scrollMaxHeight: CGFloat = 260
        static let resultMaxHeight: CGFloat = 320 // long translations scroll instead of growing the window
        static let settingsWidth: CGFloat = 480
        static let cardShadowRadius: CGFloat = 26
        static let cardShadowY: CGFloat = 12
        static let cardBorderWidth: CGFloat = 1
        static let updateDot: CGFloat = 7
    }

    // MARK: Flag sizes
    enum FlagSize {
        static let standard = CGSize(width: 22, height: 16) // chooser rows (FlagImage default)
        static let bar = CGSize(width: 20, height: 14)      // language bar buttons
        static let compact = CGSize(width: 16, height: 12)  // history rows
    }

    // MARK: Fonts
    enum Fonts {
        static let largeBody = Font.system(size: 18)               // input + result text
        static let icon = Font.system(size: 12, weight: .semibold) // swap icon
    }

    // MARK: Animation
    enum Motion {
        static let control = Animation.easeOut(duration: 0.12)   // hover/press (button style)
        static let copyState = Animation.easeOut(duration: 0.15) // Copy justCopied
    }

    /// Accent-tinted highlight fill (selected row / banner share the idea, distinct opacities).
    static func accentPill(_ opacity: Double) -> Color { Color.accentColor.opacity(opacity) }
}
