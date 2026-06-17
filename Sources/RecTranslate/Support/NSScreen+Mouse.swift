import AppKit

extension NSScreen {
    /// The screen currently containing the mouse cursor, with a sensible fallback chain.
    ///
    /// Hit-test against `frame` (not `visibleFrame`) so a cursor sitting in the menu-bar/Dock
    /// band still resolves to the right display. `NSScreen.screens` order is not stable, so we
    /// never index by position.
    static func withMouse() -> NSScreen {
        let location = NSEvent.mouseLocation // global, bottom-left origin
        return NSScreen.screens.first { NSMouseInRect(location, $0.frame, false) }
            ?? NSScreen.main
            ?? NSScreen.screens.first!
    }
}

extension NSWindow {
    /// Place this window on the display under the mouse, horizontally centered and biased
    /// toward the upper third (Spotlight-like). Call on every show — the active screen can
    /// change between presentations.
    ///
    /// - Parameter verticalAnchor: 0 = bottom, 1 = top of the visible area. ~0.7 reads well.
    func positionOnMouseScreen(verticalAnchor: CGFloat = 0.70) {
        let visible = NSScreen.withMouse().visibleFrame // excludes menu bar + Dock
        let size = frame.size

        var origin = NSPoint(
            x: visible.minX + (visible.width - size.width) / 2,
            y: visible.minY + (visible.height - size.height) * verticalAnchor
        )

        // Keep fully on-screen even if the window is larger than the visible area.
        origin.x = max(visible.minX, min(origin.x, visible.maxX - size.width))
        origin.y = max(visible.minY, min(origin.y, visible.maxY - size.height))

        setFrameOrigin(NSPoint(x: origin.x.rounded(), y: origin.y.rounded()))
    }
}
