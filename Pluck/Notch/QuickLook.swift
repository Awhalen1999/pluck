import AppKit
import QuickLookUI

/// The system Quick Look panel, over a list of shots the arrow keys step through.
/// Pluck must be active before it shows, or the panel can't take keys.
final class QuickLook: NSObject, QLPreviewPanelDataSource {
    /// Called with the shot it was showing, once it has closed.
    var onClose: (Shot.ID?) -> Void = { _ in }
    private(set) var isShown = false

    private var shots: [Shot] = []
    private var closeObserver: Any?

    func show(_ shots: [Shot], startingAt index: Int) {
        guard let panel = QLPreviewPanel.shared() else { return }
        self.shots = shots
        isShown = true
        panel.dataSource = self
        panel.reloadData()
        panel.currentPreviewItemIndex = index
        panel.makeKeyAndOrderFront(nil)
        // Showing resets the level.
        panel.level = .aboveNotch
        closeObserver = closeObserver ?? NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification, object: panel, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.closed() }
        }
    }

    private func closed() {
        if let closeObserver { NotificationCenter.default.removeObserver(closeObserver) }
        closeObserver = nil
        isShown = false
        let index = QLPreviewPanel.shared()?.currentPreviewItemIndex ?? -1
        let id = shots.indices.contains(index) ? shots[index].id : nil
        // It's still the key window while it closes.
        Task { onClose(id) }
    }

    func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int { shots.count }

    func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> (any QLPreviewItem)! {
        shots[index].url as NSURL
    }
}
