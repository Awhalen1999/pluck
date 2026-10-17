import AppKit

/// Where the notch sits on a screen, in global coordinates. On a screen without a
/// notch, this is where the pill goes instead.
struct NotchGeometry: Equatable {
    var frame: CGRect
    var hasNotch: Bool

    /// Gap between the notch (or pill) and the top edge of the screen.
    var topInset: CGFloat { hasNotch ? 0 : Theme.Notch.pillTopInset }

    /// `leftArea` and `rightArea` are the screen's unobscured top corners. Only
    /// their sizes are used, so it doesn't matter which coordinate space they're in.
    init(screenFrame: CGRect, leftArea: CGRect?, rightArea: CGRect?) {
        if let leftArea, let rightArea {
            let height = max(leftArea.height, rightArea.height)
            frame = CGRect(x: screenFrame.minX + leftArea.width,
                           y: screenFrame.maxY - height,
                           width: screenFrame.width - leftArea.width - rightArea.width,
                           height: height)
            hasNotch = true
        } else {
            let pill = Theme.Notch.pillSize
            frame = CGRect(x: screenFrame.midX - pill.width / 2,
                           y: screenFrame.maxY - Theme.Notch.pillTopInset - pill.height,
                           width: pill.width,
                           height: pill.height)
            hasNotch = false
        }
    }

    init(screen: NSScreen) {
        self.init(screenFrame: screen.frame, leftArea: screen.auxiliaryTopLeftArea, rightArea: screen.auxiliaryTopRightArea)
    }
}
