import AppKit
import SwiftUI

/// The borderless window that holds the notch. It is a fixed, transparent canvas:
/// clicks on its empty pixels fall through to the app underneath, so it never has
/// to resize as the notch changes shape. See Platform facts in CLAUDE.md.
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
        contentView = FirstClickHostingView(rootView: AnyView(rootView))
    }
}

/// Takes the first click. Without this, tapping the notch only focuses the panel
/// and the tap itself needs a second click.
private final class FirstClickHostingView: NSHostingView<AnyView> {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
}
