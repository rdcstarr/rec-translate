import Foundation

extension Notification.Name {
    /// Posted when the popup is shown so the input field can (re)grab focus.
    static let focusPopupInput = Notification.Name("com.recweb.rectranslate.focusPopupInput")
    /// Posted from the menu bar to drive the macOS 26 Settings-open workaround.
    static let openSettingsRequest = Notification.Name("com.recweb.rectranslate.openSettingsRequest")
}
