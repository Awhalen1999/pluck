import AppKit
import OSLog
import QuickLookUI

private let log = Logger(subsystem: "app.pluck.Pluck", category: "QuickLook")

/// Quick Look for shots, through the system panel. The arrow keys move through
/// every shot, and it zooms out of the shot's tile.
final class QuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    /// Where a shot's tile is on screen, for the zoom.
    var sourceFrame: (Shot.ID) -> CGRect? = { _ in nil }
    var onClose: () -> Void = {}

    private var shots: [Shot] = []
    private var closeObserver: Any?

    func show(_ shots: [Shot], startingAt index: Int) {
        guard let panel = QLPreviewPanel.shared() else { return }
        self.shots = shots
        NSApp.activate()
        panel.dataSource = self
        panel.delegate = self
        // Above the notch, so it isn't covered by an open Shelf.
        panel.level = NSWindow.Level(NSWindow.Level.statusBar.rawValue + 1)
        panel.reloadData()
        panel.currentPreviewItemIndex = index
        panel.makeKeyAndOrderFront(nil)
        log.debug("Shown: app active \(NSApp.isActive), panel visible \(panel.isVisible), key \(panel.isKeyWindow)")
        closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.closed() }
        }
    }

    private func closed() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        onClose()
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { shots.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        shots[index].url as NSURL
    }

    func previewPanel(_ panel: QLPreviewPanel!, sourceFrameOnScreenFor item: (any QLPreviewItem)!) -> NSRect {
        guard let shot = shot(for: item) else { return .zero }
        return sourceFrame(shot.id) ?? .zero
    }

    func previewPanel(_ panel: QLPreviewPanel!, transitionImageFor item: (any QLPreviewItem)!,
                      contentRect: UnsafeMutablePointer<NSRect>!) -> Any! {
        shot(for: item).map(ShotDragSource.image(for:))
    }

    private func shot(for item: (any QLPreviewItem)?) -> Shot? {
        guard let url = item?.previewItemURL else { return nil }
        return shots.first { $0.url == url }
    }
}
