import AppKit

/// Takes the keyboard for the notch without bringing Pluck forward, and gives it
/// back exactly where it was: one of Pluck's own windows, or the user's app.
final class KeyboardHandoff {
    /// Another app took the keyboard from the notch, with ⌘-Tab or the Dock.
    var onTakenAway: () -> Void = {}

    private let panel: NotchPanel
    /// Nil while the notch doesn't have the keyboard.
    private var before: (window: NSWindow?, app: NSRunningApplication?)?

    init(panel: NotchPanel) {
        self.panel = panel
        Task { [weak self, panel] in
            for await _ in NotificationCenter.default.notifications(named: NSWindow.didResignKeyNotification, object: panel) {
                // Quick Look and the folder picker take it too, but Pluck stays active.
                if !NSApp.isActive { self?.onTakenAway() }
            }
        }
    }

    func take() {
        if before == nil {
            // AppKit can still call the notch key after it let go.
            let window = NSApp.keyWindow === panel ? nil : NSApp.keyWindow
            let front = NSWorkspace.shared.frontmostApplication
            before = (window, front == .current ? nil : front)
        }
        panel.acceptsKeyboard = true
        panel.makeKey()
    }

    /// For Quick Look and the folder picker, which only take keys in the active
    /// app. macOS refuses the activation unless the notch has the keyboard first.
    func comeForward() {
        take()
        NSApp.activate()
    }

    func giveBack() {
        panel.acceptsKeyboard = false
        // Not while the user is in one of Pluck's own windows, like the folder picker.
        guard let before, NSApp.keyWindow == nil || NSApp.keyWindow === panel else { return }
        self.before = nil
        if let window = before.window, window.isVisible {
            window.makeKey()
        } else {
            // A key notch lets go by deactivating. After Quick Look Pluck is truly
            // active, and only activating the user's app gives the keyboard back.
            NSApp.deactivate()
            before.app?.activate()
        }
    }
}
