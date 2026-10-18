import Foundation
import Testing
@testable import Pluck

/// Drives a machine with a clock the test controls.
private struct Driver {
    var machine = NotchMachine()
    var now = testNow

    init(opensOnHover: Bool = true, previewDuration: TimeInterval = 4) {
        machine.settings = NotchMachine.Settings(opensOnHover: opensOnHover, previewDuration: previewDuration)
    }

    var state: NotchState { machine.state }

    mutating func send(_ event: NotchMachine.Event) { machine.handle(event, at: now) }

    mutating func wait(_ seconds: TimeInterval) {
        now += seconds
        if let timer = machine.timer, timer <= now { machine.handle(.timerFired, at: now) }
    }

    /// Hovers long enough for Peek to open.
    mutating func openPeek() {
        send(.pointerEntered)
        wait(Theme.Timing.hoverIntent)
    }
}

// MARK: Hover

@Test func hoveringOpensPeekAfterTheIntentDelay() {
    var d = Driver()
    d.send(.pointerEntered)
    d.wait(Theme.Timing.hoverIntent / 2)
    #expect(d.state == .idle)
    d.wait(Theme.Timing.hoverIntent / 2)
    #expect(d.state == .peek)
}

@Test func aPointerPassingByNeverOpensAnything() {
    var d = Driver()
    d.send(.pointerEntered)
    d.wait(Theme.Timing.hoverIntent / 2)
    d.send(.pointerExited)
    d.wait(10)
    #expect(d.state == .idle)
    #expect(d.machine.timer == nil)
}

@Test func withOpenOnHoverOffOnlyAClickOpens() {
    var d = Driver(opensOnHover: false)
    d.send(.pointerEntered)
    d.wait(10)
    #expect(d.state == .idle)
    d.send(.clicked)
    #expect(d.state == .shelf)
}

@Test func peekClosesAfterTheGracePeriodUnlessThePointerComesBack() {
    var d = Driver()
    d.openPeek()
    d.send(.pointerExited)
    d.wait(Theme.Timing.leaveGrace / 2)
    d.send(.pointerEntered)
    d.wait(10)
    #expect(d.state == .peek)

    d.send(.pointerExited)
    d.wait(Theme.Timing.leaveGrace)
    #expect(d.state == .idle)
}

@Test func leavingPeekWithEscapeDoesNotReopenIt() {
    var d = Driver()
    d.openPeek()
    d.send(.escape)
    d.wait(10)
    #expect(d.state == .idle)
}

// MARK: Shelf

@Test func aClickOpensTheShelfFromAnyState() {
    for setup in [NotchMachine.Event.escape, .shotArrived("/a.png")] {
        var d = Driver()
        d.send(setup)
        d.send(.clicked)
        #expect(d.state == .shelf)
    }
    var d = Driver()
    d.openPeek()
    d.send(.clicked)
    #expect(d.state == .shelf)
}

@Test func theShelfStaysOpenUntilAClickOutsideOrEscape() {
    var d = Driver()
    d.send(.clicked)
    d.send(.pointerEntered)
    d.send(.pointerExited)
    d.wait(60)
    #expect(d.state == .shelf)
    d.send(.clickedOutside)
    #expect(d.state == .idle)

    d.send(.clicked)
    d.send(.escape)
    #expect(d.state == .idle)
}

@Test func aShotTakenWhileTheShelfIsOpenDoesNotInterrupt() {
    var d = Driver()
    d.send(.clicked)
    d.send(.shotArrived("/new.png"))
    #expect(d.state == .shelf)
}

// MARK: Preview

@Test func aNewShotShowsThePreviewForItsDuration() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    #expect(d.state == .preview("/a.png"))
    d.wait(3.9)
    #expect(d.state == .preview("/a.png"))
    d.wait(0.1)
    #expect(d.state == .idle)
}

@Test func hoveringHoldsThePreviewAndLeavingNeverEndsItAtOnce() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    d.wait(3.8)
    d.send(.pointerEntered)
    d.wait(60)
    #expect(d.state == .preview("/a.png"))

    d.send(.pointerExited)
    d.wait(Theme.Timing.previewResumeMinimum - 0.1)
    #expect(d.state == .preview("/a.png"))
    d.wait(0.1)
    #expect(d.state == .idle)
}

@Test func aShotArrivingUnderThePointerIsHeldFromTheStart() {
    var d = Driver()
    d.send(.pointerEntered)
    d.send(.shotArrived("/a.png"))
    d.wait(60)
    #expect(d.state == .preview("/a.png"))
}

@Test func aNewerShotReplacesThePreviewAndRestartsItsTime() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    d.wait(3)
    d.send(.shotArrived("/b.png"))
    d.wait(3)
    #expect(d.state == .preview("/b.png"))
}

@Test func actingOnThePreviewFinishesItButNotPeek() {
    var d = Driver()
    d.send(.shotArrived("/a.png"))
    d.send(.finished)
    #expect(d.state == .idle)

    d.openPeek()
    d.send(.finished)
    #expect(d.state == .peek)
}

@Test func thePreviewClosesIfItsShotDisappears() {
    var d = Driver()
    d.send(.shotArrived("/a.png"))
    d.send(.shotRemoved("/other.png"))
    #expect(d.state == .preview("/a.png"))
    d.send(.shotRemoved("/a.png"))
    #expect(d.state == .idle)
}

@Test func previewProgressRunsDownAndStopsWhileHeld() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    d.wait(1)
    #expect(d.machine.previewProgress(at: d.now) == 0.75)
    d.send(.pointerEntered)
    d.wait(30)
    #expect(d.machine.previewProgress(at: d.now) == 0.75)
}

// MARK: Timers

@Test func aStaleTimerNeverFires() {
    var d = Driver()
    d.send(.pointerEntered)
    let early = d.now
    d.send(.pointerExited)
    d.machine.handle(.timerFired, at: early + 10)
    #expect(d.state == .idle)
}

// MARK: Dragging

@Test func theNotchStepsAsideWhileADragIsAwayAndReturnsWithIt() {
    var d = Driver()
    d.send(.clicked)
    d.send(.pointerEntered)
    d.send(.dragStarted)
    #expect(!d.machine.stepsAside)

    d.send(.pointerExited)
    #expect(d.machine.stepsAside)
    #expect(d.state == .shelf)

    d.send(.pointerEntered)
    #expect(!d.machine.stepsAside)
}

@Test func nothingChangesUnderADrag() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    d.send(.pointerEntered)
    d.send(.dragStarted)
    d.send(.pointerExited)

    d.send(.shotArrived("/b.png"))
    d.send(.clicked)
    d.send(.clickedOutside)
    d.wait(60)

    #expect(d.state == .preview("/a.png"))
}

@Test func droppingAPreviewFinishesItAndCancellingKeepsIt() {
    var d = Driver(previewDuration: 4)
    d.send(.shotArrived("/a.png"))
    d.send(.pointerEntered)
    d.send(.dragStarted)
    d.send(.pointerExited)
    d.send(.dragEnded(dropped: true))
    #expect(d.state == .idle)

    d.send(.shotArrived("/b.png"))
    d.send(.pointerEntered)
    d.send(.dragStarted)
    d.send(.pointerExited)
    d.send(.dragEnded(dropped: false))
    #expect(d.state == .preview("/b.png"))
    // It resumes with the time it had left when the drag began.
    d.wait(3.9)
    #expect(d.state == .preview("/b.png"))
    d.wait(0.1)
    #expect(d.state == .idle)
}

@Test func aDropFinishesTheNotchFromAnyState() {
    var shelf = Driver()
    shelf.send(.clicked)
    shelf.send(.pointerEntered)
    shelf.send(.dragStarted)
    shelf.send(.pointerExited)
    shelf.send(.dragEnded(dropped: true))
    #expect(shelf.state == .idle)
    #expect(!shelf.machine.stepsAside)

    var peek = Driver()
    peek.openPeek()
    peek.send(.dragStarted)
    peek.send(.pointerExited)
    peek.send(.dragEnded(dropped: true))
    #expect(peek.state == .idle)
}

@Test func aCancelledDragFromTheShelfLeavesItOpen() {
    var d = Driver()
    d.send(.clicked)
    d.send(.pointerEntered)
    d.send(.dragStarted)
    d.send(.pointerExited)
    d.send(.dragEnded(dropped: false))
    #expect(d.state == .shelf)
    #expect(!d.machine.stepsAside)
}

@Test func peekClosesAfterACancelledDragEndsAwayFromIt() {
    var d = Driver()
    d.openPeek()
    d.send(.dragStarted)
    d.send(.pointerExited)
    d.send(.dragEnded(dropped: false))
    #expect(d.state == .peek)
    d.wait(Theme.Timing.leaveGrace)
    #expect(d.state == .idle)
}
