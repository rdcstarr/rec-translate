import AppKit
import ApplicationServices

/// Detects a double-tap of the Shift key as an alternative trigger.
///
/// This needs a *global* key-event monitor (`.flagsChanged`), which macOS gates behind the
/// Accessibility permission — unlike the KeyboardShortcuts combo, which needs none. The
/// gesture is therefore opt-in (a Settings toggle) and prompts for permission on first enable.
@MainActor
final class DoubleShiftMonitor {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private var handler: (() -> Void)?

    private var shiftIsDown = false
    private var lastShiftPress: TimeInterval = 0
    private let doubleTapWindow: TimeInterval = 0.35

    /// Left/right Shift hardware key codes.
    private let shiftKeyCodes: Set<UInt16> = [56, 60]

    var isRunning: Bool { globalMonitor != nil }

    static func hasAccessibilityPermission() -> Bool {
        AXIsProcessTrusted()
    }

    /// Opens the system Accessibility prompt (once) so the user can grant permission.
    /// The literal key avoids a long-standing `Unmanaged<CFString>` import ambiguity.
    static func requestAccessibilityPermission() {
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func start(handler: @escaping () -> Void) {
        self.handler = handler
        guard globalMonitor == nil else { return }

        // We also watch `.keyDown` so that a real keypress between two Shifts cancels a
        // pending tap — otherwise fast typing (e.g. two capitals) reads as a double-tap.
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return }
            MainActor.assumeIsolated { self.process(event) }
        }
        // Also catch the gesture while our own panel is the key window.
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: [.flagsChanged, .keyDown]) { [weak self] event in
            guard let self else { return event }
            MainActor.assumeIsolated { self.process(event) }
            return event
        }
    }

    func stop() {
        if let globalMonitor { NSEvent.removeMonitor(globalMonitor) }
        if let localMonitor { NSEvent.removeMonitor(localMonitor) }
        globalMonitor = nil
        localMonitor = nil
        shiftIsDown = false
        lastShiftPress = 0
    }

    private func process(_ event: NSEvent) {
        // Any ordinary key pressed between the two Shift taps means this isn't a clean
        // double-tap (the user is typing) — drop the pending first tap.
        if event.type == .keyDown {
            lastShiftPress = 0
            return
        }

        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let onlyShift = flags == .shift
        let isShiftKey = shiftKeyCodes.contains(event.keyCode)

        if onlyShift && isShiftKey && !shiftIsDown {
            // Shift pressed down (with no other modifier).
            shiftIsDown = true
            let now = event.timestamp
            if now - lastShiftPress <= doubleTapWindow {
                lastShiftPress = 0
                handler?()
            } else {
                lastShiftPress = now
            }
        } else if flags.isEmpty {
            // All modifiers released.
            shiftIsDown = false
        } else if !onlyShift {
            // A chord involving other modifiers — don't count it as a Shift tap.
            shiftIsDown = false
            lastShiftPress = 0
        }
    }
}
