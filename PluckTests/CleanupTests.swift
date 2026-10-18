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
                     now: Date = testNow + 7 * 86_400) -> [String] {
    var index = index
    index.managedSince = index.managedSince ?? firstRun
    return Cleanup.expired(shots, index: index, retention: retention, now: now).map(\.url.lastPathComponent)
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

@Test func unpinningRestartsTheClock() {
    var index = ShotIndex()
    index.unpinned = ["/shots/was pinned": testNow + 6 * day]
    #expect(expired([shot("was pinned", age: 0)], index).isEmpty)
}

@Test func neverKeepsEverything() {
    #expect(expired([shot("ancient", age: 0)], retention: .never, now: testNow + 365 * day).isEmpty)
}
