import AppKit
import OSLog
import QuickLookUI

private let log = Logger(subsystem: "app.pluck.Pluck", category: "QuickLook")

/// Quick Look for shots, through the system panel. The arrow keys move through
/// every shot, and it zooms out of the shot's tile.
final class QuickLook: NSObject, QLPreviewPanelDataSource, QLPreviewPanelDelegate {
    /// Where a shot's tile is on screen, for the zoom.
    var sourceFrame: (Shot.ID) -> CGRect? = { _ in nil }
    /// Called with the shot it was showing, once it has closed.
    var onClose: (Shot.ID?) -> Void = { _ in }
    private(set) var isShown = false

    private var shots: [Shot] = []
    private var closeObserver: Any?

    /// Pluck must have the keyboard first, or the panel can't take it.
    func show(_ shots: [Shot], startingAt index: Int) {
        guard let panel = QLPreviewPanel.shared() else { return }
        self.shots = shots
        isShown = true
        panel.dataSource = self
        panel.delegate = self
        panel.reloadData()
        panel.currentPreviewItemIndex = index
        panel.makeKeyAndOrderFront(nil)
        // Set after it shows, since showing resets it.
        panel.level = .aboveNotch
        log.debug("Shown: key \(panel.isKeyWindow)")
        if closeObserver == nil {
            closeObserver = NotificationCenter.default.addObserver(forName: NSWindow.willCloseNotification, object: panel, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.closed() }
            }
        }
    }

    private func closed() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        isShown = false
        let index = QLPreviewPanel.shared()?.currentPreviewItemIndex ?? -1
        let id = shots.indices.contains(index) ? shots[index].id : nil
        // Once it has closed: until then it's still the key window.
        Task { onClose(id) }
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
