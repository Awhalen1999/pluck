import AppKit
import SwiftUI

/// The borderless window that holds the notch. It is a fixed, transparent canvas
/// that ignores the mouse except while the pointer is on the notch's shape, so
/// it never has to resize as the notch changes shape. See Platform facts in
/// CLAUDE.md.
final class NotchPanel: NSPanel {
    init(rootView: some View) {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        // Pluck hides itself to hand focus back after Quick Look; the notch stays.
        canHide = false
        // The controller turns the mouse on while the pointer is on the notch.
        ignoresMouseEvents = true
        contentView = FirstClickHostingView(rootView: AnyView(rootView))
    }

    /// Whether the notch may take the keyboard. Only the Shelf does; Peek and
    /// the Preview never take it from the app the user is typing in. Being key
    /// doesn't activate Pluck, so the user's app stays frontmost.
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }
}

extension NSWindow.Level {
    /// For the system windows Pluck opens from the notch, Quick Look and the
    /// folder picker, so an open Shelf never covers them.
    static let aboveNotch = NSWindow.Level(NSWindow.Level.statusBar.rawValue + 1)
}

/// Takes the first click. Without this, tapping the notch only focuses the panel
/// and the tap itself needs a second click.
private final class FirstClickHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
