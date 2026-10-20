import AppKit
import SwiftUI

/// The mouse on a shot: click, double-click, right-click and drag. AppKit,
/// because SwiftUI's drag never says how a drag ended, and what happens to the
/// file depends on it.
struct ShotInteraction: NSViewRepresentable {
    var onClick: (NSEvent.ModifierFlags) -> Void
    /// Nil where a double-click would make every single click wait.
    var onDoubleClick: (() -> Void)?
    var onDrag: (NSView, NSEvent) -> Void
    var menu: () -> NSMenu

    func makeNSView(context: Context) -> ShotInteractionView { ShotInteractionView() }

    func updateNSView(_ view: ShotInteractionView, context: Context) {
        view.handlers = self
    }
}

final class ShotInteractionView: NSView {
    var handlers: ShotInteraction?
    private var press: NSEvent?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

    override func mouseDown(with event: NSEvent) {
        if event.modifierFlags.contains(.control), let handlers {
            NSMenu.popUpContextMenu(handlers.menu(), with: event, for: self)
            return
        }
        press = event
    }

    override func mouseDragged(with event: NSEvent) {
        guard let press else { return }
        let start = press.locationInWindow
        let now = event.locationInWindow
        guard hypot(now.x - start.x, now.y - start.y) >= Theme.Drag.threshold else { return }
        self.press = nil
        handlers?.onDrag(self, event)
    }

    override func mouseUp(with event: NSEvent) {
        guard press != nil else { return }
        press = nil
        if event.clickCount >= 2, let onDoubleClick = handlers?.onDoubleClick {
            onDoubleClick()
        } else if event.clickCount == 1 {
            handlers?.onClick(event.modifierFlags)
        }
    }

    override func menu(for event: NSEvent) -> NSMenu? { handlers?.menu() }
}

/// Reports where a drag of shots is and how it ended.
final class ShotDragSource: NSObject, NSDraggingSource {
    var moved: (NSPoint) -> Void = { _ in }
    var ended: (NSDragOperation) -> Void = { _ in }

    /// What Finder offers for a file, and the destination picks: editors and chat
    /// apps copy (TextEdit only takes generic), Finder moves within a disk, and
    /// the Trash deletes.
    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        [.copy, .move, .generic, .delete]
    }

    func draggingSession(_ session: NSDraggingSession, movedTo screenPoint: NSPoint) { moved(screenPoint) }

    func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
        ended(operation)
    }

    /// The shot under the cursor during a drag: its thumbnail, rounded like a tile.
    static func image(for shot: Shot) -> NSImage {
        guard let thumbnail = Thumbnails.cached(shot) else {
            return NSWorkspace.shared.icon(forFile: shot.url.path(percentEncoded: false))
        }
        let box = Theme.Drag.imageSize
        let scale = min(box.width / CGFloat(thumbnail.width), box.height / CGFloat(thumbnail.height))
        let size = CGSize(width: CGFloat(thumbnail.width) * scale, height: CGFloat(thumbnail.height) * scale)
        return NSImage(size: size, flipped: false) { rect in
            NSBezierPath(roundedRect: rect, xRadius: Theme.Radius.tile, yRadius: Theme.Radius.tile).addClip()
            NSImage(cgImage: thumbnail, size: rect.size).draw(in: rect)
            return true
        }
    }
}

/// A menu item that runs a closure. The shortcut is only shown, as context
/// menus show them.
func menuItem(_ title: String, key: String = "", _ handler: @escaping () -> Void) -> NSMenuItem {
    let action = MenuAction(handler)
    let item = NSMenuItem(title: title, action: #selector(MenuAction.run), keyEquivalent: key)
    item.target = action
    // The item holds its target weakly; this keeps the action alive with it.
    item.representedObject = action
    return item
}

private final class MenuAction: NSObject {
    let handler: () -> Void
    init(_ handler: @escaping () -> Void) { self.handler = handler }
    @objc func run() { handler() }
}
