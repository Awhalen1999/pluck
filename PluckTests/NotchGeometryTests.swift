import CoreGraphics
import Testing
@testable import Pluck

/// A 14″ MacBook Pro as macOS reports it: the notch is the 185 pt gap between the
/// two unobscured top areas.
private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)
private let left = CGRect(x: 0, y: 950, width: 663, height: 32)
private let right = CGRect(x: 848, y: 950, width: 664, height: 32)

@Test func notchIsTheGapBetweenTheTopAreas() {
    let g = NotchGeometry(screenFrame: screen, leftArea: left, rightArea: right)
    #expect(g.hasNotch)
    #expect(g.frame == CGRect(x: 663, y: 950, width: 185, height: 32))
    #expect(g.topInset == 0)
}

@Test func notchFollowsTheScreenWhenItIsNotTheMainDisplay() {
    let moved = screen.offsetBy(dx: -246, dy: 1080)
    let g = NotchGeometry(screenFrame: moved, leftArea: left, rightArea: right)
    #expect(g.frame == CGRect(x: 663 - 246, y: 950 + 1080, width: 185, height: 32))
}

@Test func screenWithoutNotchGetsACenteredPillBelowTheTopEdge() {
    let external = CGRect(x: 0, y: 0, width: 1920, height: 1080)
    let g = NotchGeometry(screenFrame: external, leftArea: nil, rightArea: nil)
    #expect(!g.hasNotch)
    #expect(g.frame.midX == external.midX)
    #expect(g.frame.maxY == external.maxY - Theme.Notch.pillTopInset)
    #expect(g.frame.size == Theme.Notch.pillSize)
}
