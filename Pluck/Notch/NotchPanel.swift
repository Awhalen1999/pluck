import AppKit
import SwiftUI

/// The borderless window that holds the notch: a fixed, transparent canvas that
/// never resizes. It ignores the mouse except while the pointer is on the notch's
/// shape; see Platform facts.
final class NotchPanel: NSPanel {
    init() {
        super.init(contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        level = .statusBar
        collectionBehavior = [.canJoinAllSpaces, .stationary, .fullScreenAuxiliary, .ignoresCycle]
        isMovable = false
        hidesOnDeactivate = false
        canHide = false
        ignoresMouseEvents = true
    }

    func host(_ view: some View) {
        contentView = FirstClickHostingView(rootView: AnyView(view))
    }

    /// Only the Shelf takes the keyboard. Being key doesn't activate Pluck, so the
    /// user's app stays frontmost.
    var acceptsKeyboard = false
    override var canBecomeKey: Bool { acceptsKeyboard }

    /// Centers the canvas on the screen's notch, or where the pill goes on a
    /// screen without one.
    func place(on screen: NSScreen) -> NotchGeometry {
        let geometry = NotchGeometry(screen: screen)
        let canvas = Theme.Notch.canvas
        setFrame(CGRect(x: geometry.frame.midX - canvas.width / 2, y: screen.frame.maxY - canvas.height,
                        width: canvas.width, height: canvas.height),
                 display: true)
        orderFrontRegardless()
        return geometry
    }
}

/// Without this, a tap on a non-key panel only focuses it, and needs a second click.
private final class FirstClickHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
