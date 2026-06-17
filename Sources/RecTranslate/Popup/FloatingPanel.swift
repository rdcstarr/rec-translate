import AppKit

/// A Spotlight-style, non-activating floating panel that can still take keyboard focus.
///
/// `.nonactivatingPanel` makes `canBecomeKey`/`canBecomeMain` default to `false`, which would
/// stop the SwiftUI text field from ever editing — so both are overridden to `true`. The
/// rounded look + shadow are drawn by SwiftUI (window background is clear, `hasShadow=false`),
/// which yields a properly rounded shadow.
final class FloatingPanel: NSPanel {
    var onDismiss: (() -> Void)?

    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        becomesKeyOnlyIfNeeded = false        // input panel must always take keystrokes
        hidesOnDeactivate = false             // we manage dismissal ourselves
        isReleasedWhenClosed = false          // reuse the instance across show/hide
        isMovableByWindowBackground = true    // draggable anywhere

        animationBehavior = .utilityWindow
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false                     // SwiftUI draws the rounded shadow

        // Appear on the active Space and over native-fullscreen apps; stay out of Cmd-Tab.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]

        standardWindowButton(.closeButton)?.isHidden = true
        standardWindowButton(.miniaturizeButton)?.isHidden = true
        standardWindowButton(.zoomButton)?.isHidden = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    /// Esc.
    override func cancelOperation(_ sender: Any?) {
        onDismiss?()
    }

    /// Click-outside / focus moved to another window or app. Deferred and re-checked on the next
    /// run-loop turn so that opening an in-panel pop-up menu (the language Pickers) or a transient
    /// key loss does NOT close the popup — only a genuine focus change to a different window does.
    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                guard !self.isKeyWindow, !(NSApp.keyWindow is FloatingPanel) else { return }
                self.onDismiss?()
            }
        }
    }
}
