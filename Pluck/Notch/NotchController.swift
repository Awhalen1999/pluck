import AppKit

/// Owns the notch: which screen it lives on and where it sits there. Its states
/// (Idle, Peek, Shelf, Preview) will live here too, per the contract in CLAUDE.md.
@Observable final class NotchController {
    private(set) var geometry: NotchGeometry?
    @ObservationIgnored private var panel: NotchPanel!

    init() {
        panel = NotchPanel(rootView: NotchView(controller: self))
        place()
        Task {
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                place()
            }
        }
    }

    /// Puts the panel on the built-in display, centered on its notch, and keeps it
    /// there when displays change. Falls back to the main display when the lid is closed.
    // ponytail: built-in only; "Show on: Main / With mouse" arrives with Settings.
    private func place() {
        guard let screen = NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.main else { return }
        let geometry = NotchGeometry(screen: screen)
        let canvas = Theme.Notch.canvas
        panel.setFrame(CGRect(x: geometry.frame.midX - canvas.width / 2,
                              y: screen.frame.maxY - canvas.height,
                              width: canvas.width,
                              height: canvas.height),
                       display: true)
        self.geometry = geometry
        panel.orderFrontRegardless()
    }
}

private extension NSScreen {
    var isBuiltIn: Bool {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
