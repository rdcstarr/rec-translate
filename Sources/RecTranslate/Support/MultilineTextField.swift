import SwiftUI
import AppKit

/// Multi-line text input backed by `NSTextView` so **Shift+Return inserts a newline at the cursor**
/// (SwiftUI's `TextField` can only append at the end), plain **Return submits**, and **Esc closes**.
/// Transparent, no scroller chrome, and self-sizing between `minHeight` and `maxHeight`.
struct MultilineTextField: NSViewRepresentable {
    @Binding var text: String
    var fontSize: CGFloat = 18
    var minHeight: CGFloat = 30
    var maxHeight: CGFloat = 170
    /// Bump this to (re)grab keyboard focus — e.g. on show, after clearing, or when the chooser closes.
    var focusTick: Int = 0
    var onSubmit: () -> Void = {}
    var onEscape: () -> Void = {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> NSScrollView {
        let textView = FocusableTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.allowsUndo = true
        textView.font = NSFont.systemFont(ofSize: fontSize)
        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.textColor = .labelColor
        textView.insertionPointColor = .controlAccentColor
        textView.textContainerInset = NSSize(width: 0, height: 2)
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.isAutomaticSpellingCorrectionEnabled = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainer?.widthTracksTextView = true
        textView.string = text

        let scroll = NSScrollView()
        scroll.documentView = textView
        scroll.drawsBackground = false
        scroll.borderType = .noBorder
        scroll.hasVerticalScroller = false   // no scroller bar (the old "black line")
        scroll.hasHorizontalScroller = false
        scroll.verticalScrollElasticity = .none
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        context.coordinator.parent = self
        guard let textView = scroll.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text // external change (e.g. load from history / clear)
        }
        if textView.font?.pointSize != fontSize {
            textView.font = NSFont.systemFont(ofSize: fontSize) // live font-size change
        }
        if context.coordinator.lastFocusTick != focusTick {
            context.coordinator.lastFocusTick = focusTick
            textView.window?.makeFirstResponder(textView)
        }
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView scroll: NSScrollView, context: Context) -> CGSize? {
        guard let textView = scroll.documentView as? NSTextView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer else { return nil }
        let width = proposal.width ?? Theme.Metrics.cardWidth
        // Measure wrapped height at the proposed width (temporarily detach width tracking).
        let tracked = container.widthTracksTextView
        container.widthTracksTextView = false
        container.size = NSSize(width: width, height: .greatestFiniteMagnitude)
        layoutManager.ensureLayout(for: container)
        let used = layoutManager.usedRect(for: container).height + textView.textContainerInset.height * 2
        container.widthTracksTextView = tracked
        let height = min(max(used, minHeight), maxHeight)
        return CGSize(width: width, height: height)
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MultilineTextField
        var lastFocusTick: Int

        init(_ parent: MultilineTextField) {
            self.parent = parent
            self.lastFocusTick = parent.focusTick
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }

        func textView(_ textView: NSTextView, doCommandBy selector: Selector) -> Bool {
            switch selector {
            case #selector(NSResponder.insertNewline(_:)):
                // Return submits; Shift+Return inserts a newline at the insertion point.
                if NSApp.currentEvent?.modifierFlags.contains(.shift) == true {
                    textView.insertNewlineIgnoringFieldEditor(nil)
                } else {
                    parent.onSubmit()
                }
                return true
            case #selector(NSResponder.cancelOperation(_:)):
                parent.onEscape()
                return true
            default:
                return false
            }
        }
    }
}

/// NSTextView that grabs keyboard focus as soon as it's placed in a window (initial autofocus).
private final class FocusableTextView: NSTextView {
    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if window != nil {
            window?.makeFirstResponder(self)
        }
    }
}
