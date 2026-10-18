import Foundation

/// Every size the notch takes, computed from Theme tokens and the current shots.
/// The view draws these sizes and the controller hit-tests them, so what you see
/// and what responds to the pointer can never disagree.
enum NotchLayout {
    /// What the notch is showing, everything a size depends on.
    struct Content {
        /// Newest first.
        var shots: [Shot] = []
        /// In the user's order.
        var pinned: [Shot] = []
        var feedback: Feedback?
        var showsLatest = true
        var now = Date()
        var calendar = Calendar.current
    }

    struct Frame: Equatable {
        var size: CGSize
        /// The shape's center, relative to the hardware notch's center.
        var offsetX: CGFloat = 0
    }

    struct ShelfSection: Identifiable, Equatable {
        let title: String
        let note: String?
        let rows: [ShelfRow]
        var id: String { title }
    }

    /// Identified by its first shot, which appears nowhere else in the Shelf. (By
    /// position, the first row of two sections would share an ID, and a lazy
    /// stack draws only one of them.)
    struct ShelfRow: Identifiable, Equatable {
        let tiles: [ShelfTile]
        var id: Shot.ID { tiles[0].id }
    }

    struct ShelfTile: Identifiable, Equatable {
        let shot: Shot
        let size: CGSize
        var id: Shot.ID { shot.id }
    }

    static let shelfContentWidth = Theme.Notch.shelfWidth - 2 * Theme.Space.xl
    /// Below the Shelf's last row, which already carries one gap.
    static let shelfBottomPadding = Theme.Space.xl - Theme.Space.s
    static let previewImageWidth = Theme.Notch.previewWidth - 2 * Theme.Space.l

    // MARK: Frames

    static func frame(for state: NotchState, content: Content, notch: CGSize) -> Frame {
        let n = Theme.Notch.self
        let minWidth = notch.width + 2 * n.minExpandedEar
        switch state {
        case .idle:
            let ears = idleEars(content)
            return Frame(size: CGSize(width: notch.width + ears.left + ears.right, height: notch.height),
                         offsetX: (ears.right - ears.left) / 2)

        case .peek:
            let row = content.shots.isEmpty ? n.controlHeight : n.peekTile.height
            return Frame(size: CGSize(width: max(peekRowWidth(count: content.shots.count) + 2 * Theme.Space.l, minWidth),
                                      height: n.headerHeight + row + Theme.Space.l))

        case .preview(let id):
            let shot = content.shots.first { $0.id == id }
            return Frame(size: CGSize(width: n.previewWidth,
                                      height: n.headerHeight + previewImageHeight(shot) + Theme.Space.m + n.controlHeight + Theme.Space.l))

        case .shelf:
            let body = content.shots.isEmpty ? n.controlHeight + shelfBottomPadding : shelfHeight(shelfSections(content))
            return Frame(size: CGSize(width: n.shelfWidth, height: min(n.headerHeight + body, n.shelfMaxHeight)))
        }
    }

    /// The notch's shape on screen, in screen coordinates: the only place the
    /// notch takes the mouse.
    static func shapeRect(for frame: Frame, geometry: NotchGeometry) -> CGRect {
        CGRect(x: geometry.frame.midX + frame.offsetX - frame.size.width / 2,
               y: geometry.frame.maxY - frame.size.height,
               width: frame.size.width, height: frame.size.height)
    }

    /// Where the pointer counts as "on the notch", in screen coordinates. It
    /// always reaches the top edge of the screen, and when idle a little below
    /// the notch too, since the camera housing hides the cursor.
    static func hoverZone(for frame: Frame, state: NotchState, geometry: NotchGeometry) -> CGRect {
        var zone = shapeRect(for: frame, geometry: geometry)
        zone.size.height += geometry.topInset
        if state == .idle {
            zone.origin.y -= Theme.Notch.hoverReach
            zone.size.height += Theme.Notch.hoverReach
        }
        return zone
    }

    /// The idle notch grows a left ear for the latest shot, and a right ear while
    /// it shows feedback.
    static func idleEars(_ content: Content) -> (left: CGFloat, right: CGFloat) {
        let n = Theme.Notch.self
        let left = content.showsLatest && !content.shots.isEmpty ? n.idleEarWidth : 0
        let right = content.feedback.map { $0.canUndo ? n.feedbackUndoEarWidth : n.feedbackEarWidth } ?? 0
        return (left, right)
    }

    // MARK: Peek

    static func peekShots(_ shots: [Shot]) -> [Shot] {
        Array(shots.prefix(Theme.Notch.peekTileCount))
    }

    static func peekRowWidth(count: Int) -> CGFloat {
        let n = Theme.Notch.self
        let tiles = min(count, n.peekTileCount)
        guard tiles > 0 else { return 0 }
        let row = CGFloat(tiles) * n.peekTile.width + CGFloat(tiles - 1) * Theme.Space.s
        return count > tiles ? row + Theme.Space.s + n.peekMoreWidth : row
    }

    // MARK: Preview

    /// Tall enough to show the whole screenshot at the Preview's width, within
    /// the Preview's limits.
    static func previewImageHeight(_ shot: Shot?) -> CGFloat {
        let range = Theme.Notch.previewImageHeights
        guard let shot, shot.pixelSize.width > 0, shot.pixelSize.height > 0 else { return range.lowerBound }
        let natural = previewImageWidth * shot.pixelSize.height / shot.pixelSize.width
        return min(max(natural, range.lowerBound), range.upperBound)
    }

    // MARK: Shelf

    /// Pinned first, in the user's order, then the rest by day, newest first.
    static func shelfSections(_ content: Content) -> [ShelfSection] {
        var sections: [ShelfSection] = []
        if !content.pinned.isEmpty {
            sections.append(ShelfSection(title: "Pinned", note: "Kept until you unpin", rows: rows(for: content.pinned)))
        }
        let pinned = Set(content.pinned.map(\.id))
        let rest = content.shots.filter { !pinned.contains($0.id) }
        let yesterday = content.calendar.date(byAdding: .day, value: -1, to: content.now) ?? content.now
        func day(_ shot: Shot) -> String {
            if content.calendar.isDate(shot.capturedAt, inSameDayAs: content.now) { return "Today" }
            if content.calendar.isDate(shot.capturedAt, inSameDayAs: yesterday) { return "Yesterday" }
            return "Earlier"
        }
        for title in ["Today", "Yesterday", "Earlier"] {
            let shots = rest.filter { day($0) == title }
            if !shots.isEmpty { sections.append(ShelfSection(title: title, note: nil, rows: rows(for: shots))) }
        }
        return sections
    }

    /// Justified rows: each full row fills the width exactly, every tile keeps
    /// its screenshot's shape, and a short last row isn't stretched.
    static func rows(for shots: [Shot], width: CGFloat = shelfContentWidth) -> [ShelfRow] {
        let gap = Theme.Space.s
        let target = Theme.Notch.shelfRowHeight
        var rows: [ShelfRow] = []
        var row: [(shot: Shot, aspect: CGFloat)] = []
        var aspects: CGFloat = 0

        func flush(height: CGFloat) {
            rows.append(ShelfRow(tiles: row.map { ShelfTile(shot: $0.shot, size: CGSize(width: $0.aspect * height, height: height)) }))
            row = []
            aspects = 0
        }

        for shot in shots {
            let aspect = tileAspect(shot)
            row.append((shot, aspect))
            aspects += aspect
            let gaps = gap * CGFloat(row.count - 1)
            if aspects * target + gaps >= width { flush(height: (width - gaps) / aspects) }
        }
        if !row.isEmpty {
            flush(height: min(target, (width - gap * CGFloat(row.count - 1)) / aspects))
        }
        return rows
    }

    /// Everything below the Shelf's header: section names, rows and the bottom padding.
    static func shelfHeight(_ sections: [ShelfSection]) -> CGFloat {
        sections.reduce(shelfBottomPadding) { total, section in
            total + Theme.Notch.sectionHeaderHeight + section.rows.reduce(0) { $0 + ($1.tiles.first?.size.height ?? 0) + Theme.Space.s }
        }
    }

    static func tileAspect(_ shot: Shot) -> CGFloat {
        let range = Theme.Tile.aspectRange
        guard shot.pixelSize.height > 0 else { return range.lowerBound }
        return min(max(shot.pixelSize.width / shot.pixelSize.height, range.lowerBound), range.upperBound)
    }
}
