import Foundation
import Testing
@testable import Pluck

/// Pluck first ran a day before `testNow`; every shot below was taken after that.
private let firstRun = testNow - 86_400
private let day: TimeInterval = 86_400

private func shot(_ name: String, age: TimeInterval) -> Shot {
    Shot(url: URL(filePath: "/shots/\(name)"), capturedAt: testNow - age, pixelSize: CGSize(width: 16, height: 10), fileID: nil)
}

private func expired(_ shots: [Shot], _ index: ShotIndex = ShotIndex(), retention: Retention = .sevenDays,
                     removeDraggedOut: Bool = true, now: Date = testNow + 7 * 86_400) -> [String] {
    var index = index
    index.managedSince = index.managedSince ?? firstRun
    return Cleanup.expired(shots, index: index, retention: retention, removeDraggedOut: removeDraggedOut, now: now)
        .map(\.url.lastPathComponent)
}

@Test func shotsExpireOnceOlderThanTheRetention() {
    let shots = [shot("week old", age: 0), shot("newer", age: -60)]
    #expect(expired(shots) == ["week old"])
}

@Test func pinnedShotsNeverExpire() {
    var index = ShotIndex()
    index.pinned = ["/shots/pinned"]
    #expect(expired([shot("pinned", age: 0)], index, now: testNow + 365 * day).isEmpty)
}

@Test func shotsFromBeforePlucksFirstRunNeverExpire() {
    #expect(expired([shot("had it already", age: 2 * day)], now: testNow + 365 * day).isEmpty)
}

@Test func draggedOutShotsGoAnHourAfterTheDrag() {
    var index = ShotIndex()
    index.draggedOut = ["/shots/sent": testNow]
    let shots = [shot("sent", age: 0)]

    #expect(expired(shots, index, now: testNow + 59 * 60).isEmpty)
    #expect(expired(shots, index, now: testNow + 60 * 60) == ["sent"])
    #expect(expired(shots, index, removeDraggedOut: false, now: testNow + 60 * 60).isEmpty)
}

@Test func unpinningRestartsTheClock() {
    var index = ShotIndex()
    index.unpinned = ["/shots/was pinned": testNow + 6 * day]
    #expect(expired([shot("was pinned", age: 0)], index).isEmpty)
}

@Test func neverKeepsEverythingExceptDragOuts() {
    var index = ShotIndex()
    index.draggedOut = ["/shots/sent": testNow]
    let shots = [shot("sent", age: 0), shot("ancient", age: 0)]
    #expect(expired(shots, index, retention: .never, now: testNow + 365 * day) == ["sent"])
}
