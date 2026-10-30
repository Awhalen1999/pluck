import AppKit
import Foundation
import SwiftUI
import Testing
@testable import Pluck

private func shot(_ name: String, _ width: CGFloat = 1600, _ height: CGFloat = 1000, takenAt: Date = testNow) -> Shot {
    Shot(url: URL(filePath: "/shots/\(name)"), capturedAt: takenAt, pixelSize: CGSize(width: width, height: height), fileID: nil)
}

private let notch = Theme.Notch.referenceSize
private let gap = Theme.Space.s

// MARK: Shelf rows

@Test func fullRowsFillTheWidthExactlyAndKeepEachShotsShape() {
    let shots = (0..<9).map { shot("\($0)", $0.isMultiple(of: 2) ? 1600 : 1000, 1000) }
    let rows = NotchLayout.rows(for: shots)

    for row in rows.dropLast().map(\.tiles) {
        let width = row.reduce(0) { $0 + $1.size.width } + gap * CGFloat(row.count - 1)
        #expect(abs(width - NotchLayout.shelfContentWidth) < 0.5)
        #expect(Set(row.map(\.size.height)).count == 1)
    }
    for tile in rows.flatMap(\.tiles) {
        let aspect = tile.shot.pixelSize.width / tile.shot.pixelSize.height
        #expect(abs(tile.size.width / tile.size.height - aspect) < 0.001)
    }
}

@Test func aShortLastRowIsNotStretched() {
    let rows = NotchLayout.rows(for: [shot("only")])
    #expect(rows.count == 1)
    #expect(rows[0].tiles[0].size.height == Theme.Notch.shelfRowHeight)
}

@Test func veryTallAndVeryWideShotsAreKeptWithinLimits() {
    let rows = NotchLayout.rows(for: [shot("strip", 3000, 80), shot("long page", 1400, 9000)])
    let range = Theme.Tile.aspectRange
    let aspects = rows.flatMap(\.tiles).map { $0.size.width / $0.size.height }
    #expect(aspects.allSatisfy { $0 >= range.lowerBound - 0.001 && $0 <= range.upperBound + 0.001 })
}

// MARK: Shelf sections

@Test func pinnedComeFirstThenShotsByDayWithoutRepeats() {
    let calendar = Calendar(identifier: .gregorian)
    let today = shot("today", takenAt: testNow - 60)
    let yesterday = shot("yesterday", takenAt: calendar.date(byAdding: .day, value: -1, to: testNow)!)
    let old = shot("old", takenAt: calendar.date(byAdding: .day, value: -5, to: testNow)!)
    let pinned = shot("pinned", takenAt: testNow - 120)
    let content = NotchLayout.Content(shots: [today, pinned, yesterday, old], pinned: [pinned], now: testNow, calendar: calendar)

    let sections = NotchLayout.shelfSections(content)

    #expect(sections.map(\.title) == ["Pinned", "Today", "Yesterday", "Earlier"])
    #expect(sections.map { $0.rows.flatMap(\.tiles).map(\.shot.url.lastPathComponent) } == [["pinned"], ["today"], ["yesterday"], ["old"]])
    // Every row in the Shelf has its own identity, across sections too.
    let rowIDs = sections.flatMap { $0.rows.map(\.id) }
    #expect(Set(rowIDs).count == rowIDs.count)
}

@Test func theShelfGrowsWithItsShotsUpToItsLimit() {
    let few = NotchLayout.Content(shots: [shot("a")])
    let many = NotchLayout.Content(shots: (0..<200).map { shot("\($0)") })

    let small = NotchLayout.frame(for: .shelf, content: few, notch: notch).size.height
    let large = NotchLayout.frame(for: .shelf, content: many, notch: notch).size.height

    #expect(small < large)
    #expect(large == Theme.Notch.shelfMaxHeight)
}

// MARK: Arrow keys

@Test func theArrowKeysMoveThroughTheShelfAsItIsDrawn() {
    // Drawn as three rows: [p1 p2] in Pinned, then [t0 t1 t2 t3] and [t4 t5] in Today.
    let pinned = [shot("p1"), shot("p2")]
    let today = (0..<6).map { shot("t\($0)", takenAt: testNow - Double($0)) }
    let sections = NotchLayout.shelfSections(NotchLayout.Content(shots: today + pinned, pinned: pinned, now: testNow))
    #expect(sections.flatMap(\.rows).map { $0.tiles.count } == [2, 4, 2])
    func move(_ name: String?, _ direction: MoveCommandDirection) -> String? {
        NotchLayout.shot(from: name.map { "/shots/\($0)" }, moving: direction, in: sections).map { URL(filePath: $0).lastPathComponent }
    }

    // Nothing focused yet: any arrow starts at the first shot.
    #expect(move(nil, .down) == "p1")
    // Left and right follow reading order across rows and sections, and stop at the ends.
    #expect(move("p2", .right) == "t0")
    #expect(move("t0", .left) == "p2")
    #expect(move("p1", .left) == "p1")
    #expect(move("t5", .right) == "t5")
    // Up and down land on the nearest shot in the next row, and stop at the edges.
    #expect(move("p2", .down) == "t1")
    #expect(move("t3", .down) == "t5")
    #expect(move("t5", .up) == "t1")
    #expect(move("p1", .up) == "p1")
    #expect(move("t4", .down) == "t4")
}

// MARK: Frames and hover

@Test func theIdleNotchGrowsEarsOnlyForWhatItShows() {
    let empty = NotchLayout.frame(for: .idle, content: NotchLayout.Content(), notch: notch)
    #expect(empty.size == notch)
    #expect(empty.offsetX == 0)

    let latest = NotchLayout.frame(for: .idle, content: NotchLayout.Content(shots: [shot("a")]), notch: notch)
    #expect(latest.size.width == notch.width + Theme.Notch.idleEarWidth)
    #expect(latest.offsetX < 0)

    let hidden = NotchLayout.frame(for: .idle, content: NotchLayout.Content(shots: [shot("a")], showsLatest: false), notch: notch)
    #expect(hidden.size == notch)
}

@Test func aCompactPreviewStaysNotchHighAndOnlyOpeningItCoversTheScreen() {
    let capture = shot("a")
    let content = NotchLayout.Content(pending: [capture], showsLatest: false)
    let compact = NotchLayout.frame(for: .preview(capture.id, open: false), content: content, notch: notch)
    #expect(compact.size == CGSize(width: notch.width + Theme.Notch.previewEarWidth, height: notch.height))

    let open = NotchLayout.frame(for: .preview(capture.id, open: true), content: content, notch: notch)
    #expect(open.size.width == Theme.Notch.previewWidth)
    #expect(open.size.height > notch.height)
}

@Test func peeksHeaderFitsAShotsDetailBesideTheCamera() {
    let peek = NotchLayout.frame(for: .peek, content: NotchLayout.Content(shots: [shot("only")]), notch: notch)
    // An ear, less its outer padding and the gap beside the camera housing.
    let ear = (peek.size.width - notch.width) / 2 - Theme.Space.l - Theme.Space.m
    let font = NSFont.preferredFont(forTextStyle: .subheadline)
    let longest = ("12:59 PM · 5120 × 2880" as NSString).size(withAttributes: [.font: font]).width
    #expect(longest <= ear)
}

@Test func thePreviewIsTallEnoughToShowTheWholeShot() {
    let wide = NotchLayout.previewImageHeight(shot("wide", 3000, 500))
    let normal = NotchLayout.previewImageHeight(shot("normal", 1600, 1000))
    let tall = NotchLayout.previewImageHeight(shot("tall", 1000, 3000))

    #expect(wide == Theme.Notch.previewImageHeights.lowerBound)
    #expect(abs(normal - NotchLayout.previewImageWidth * 1000 / 1600) < 0.001)
    #expect(tall == Theme.Notch.previewImageHeights.upperBound)
}

@Test func theIdleHoverZoneReachesBelowTheNotchAndUpToTheTopEdge() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen,
                                 leftArea: CGRect(x: 0, y: 950, width: 663, height: 32),
                                 rightArea: CGRect(x: 848, y: 950, width: 664, height: 32))
    let idle = NotchLayout.frame(for: .idle, content: NotchLayout.Content(), notch: geometry.frame.size)

    let zone = NotchLayout.hoverZone(for: idle, state: .idle, geometry: geometry)

    #expect(zone.maxY == screen.maxY)
    #expect(zone.minY == geometry.frame.minY - Theme.Notch.hoverReach)
    #expect(zone.minX == geometry.frame.minX)
    #expect(zone.width == geometry.frame.width)
}

@Test func anExpandedHoverZoneIsExactlyTheShape() {
    let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
    let geometry = NotchGeometry(screenFrame: screen,
                                 leftArea: CGRect(x: 0, y: 950, width: 663, height: 32),
                                 rightArea: CGRect(x: 848, y: 950, width: 664, height: 32))
    let peek = NotchLayout.frame(for: .peek, content: NotchLayout.Content(shots: [shot("a")]), notch: geometry.frame.size)

    let zone = NotchLayout.hoverZone(for: peek, state: .peek, geometry: geometry)

    #expect(zone.size == peek.size)
    #expect(zone.midX == geometry.frame.midX)
}
