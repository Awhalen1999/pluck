import Foundation

/// The notch's state. It is always exactly one of these; see the state contract
/// in CLAUDE.md.
enum NotchState: Equatable {
    case idle
    case peek
    case shelf
    /// The newest waiting capture, in front of any others.
    case preview(Shot.ID)

    var isPreview: Bool {
        if case .preview = self { true } else { false }
    }
}

/// The notch's rules as a plain value: events go in, the state and its one timer
/// come out, so every rule can be tested without a screen.
struct NotchMachine: Equatable {
    enum Event: Equatable {
        case pointerEntered
        case pointerExited
        /// The pointer is on the idle notch but still moving fast.
        case pointerPassing
        /// A click on the notch itself, not on a shot or a button.
        case clicked
        /// A click outside the notch, or ⌘-Tab: the user is in another app now.
        case wentToAnotherApp
        /// The user is done with the notch: Esc, or Return in the Shelf once it has copied.
        case dismissed
        /// A capture is up for the Preview: a new one, or the next in line.
        case shotUp(Shot.ID)
        /// The Preview has no capture left to show.
        case previewEmptied
        case dragStarted
        /// `dropped` is true for a drop into another app; a cancelled drag is false.
        case dragEnded(dropped: Bool)
        /// The feedback slot emptied, so hovering may open Peek again.
        case feedbackEnded
        case timerFired
    }

    struct Settings: Equatable {
        var opensOnHover = true
        var previewDuration: TimeInterval = 4
    }

    var settings = Settings()
    private(set) var state: NotchState = .idle
    /// The current state's one timer. Every transition replaces it, so a timer
    /// can never outlive its state.
    private(set) var timer: Date?
    private(set) var pointerInside = false
    /// Time left on the Preview while the pointer holds it open.
    private(set) var previewRemaining: TimeInterval?
    /// Nothing the notch shows may change under a drag.
    private(set) var isDragging = false
    /// A drag that leaves the notch folds it back to its idle shape, so the user
    /// can see where they're dropping.
    private(set) var stepsAside = false

    /// What the notch's shape shows: its state, or Idle while stepped aside.
    var shownState: NotchState { stepsAside ? .idle : state }

    mutating func handle(_ event: Event, at now: Date) {
        if isDragging {
            handleDuringDrag(event, at: now)
            return
        }
        switch event {
        case .pointerEntered:
            guard !pointerInside else { return }
            pointerInside = true
            switch state {
            case .idle: timer = settings.opensOnHover ? now + Theme.Timing.hoverIntent : nil
            case .peek: timer = nil
            case .preview: pausePreview(at: now)
            case .shelf: break
            }

        case .pointerPassing:
            // Not arriving yet: the hover delay counts from when it slows down.
            if state == .idle, pointerInside, timer != nil { timer = now + Theme.Timing.hoverIntent }

        case .pointerExited:
            guard pointerInside else { return }
            pointerInside = false
            switch state {
            case .idle: timer = nil
            case .peek: timer = now + Theme.Timing.leaveGrace
            case .preview: resumePreview(at: now)
            case .shelf: break
            }

        case .clicked:
            go(.shelf)

        case .wentToAnotherApp:
            if state == .shelf { go(.idle) }

        case .dismissed:
            go(.idle)

        case .shotUp(let id):
            go(.preview(id))
            if pointerInside {
                previewRemaining = settings.previewDuration
            } else {
                timer = now + settings.previewDuration
            }

        case .previewEmptied:
            if state.isPreview { go(.idle) }

        case .dragStarted:
            isDragging = true
            stepsAside = !pointerInside
            if state.isPreview { pausePreview(at: now) }
            timer = nil

        case .dragEnded:
            break

        case .feedbackEnded:
            // A pointer resting on the Undo is now simply resting on the notch.
            if state == .idle, pointerInside, timer == nil, settings.opensOnHover {
                timer = now + Theme.Timing.hoverIntent
            }

        case .timerFired:
            guard let timer, now >= timer else { return }
            self.timer = nil
            switch state {
            case .idle: if pointerInside { go(.peek) }
            case .peek: if !pointerInside { go(.idle) }
            case .preview: go(.idle)
            case .shelf: break
            }
        }
    }

    /// During a drag the pointer only moves the notch aside and back. Arrivals,
    /// clicks and timers are dropped, so nothing changes under it.
    private mutating func handleDuringDrag(_ event: Event, at now: Date) {
        switch event {
        case .pointerEntered:
            pointerInside = true
            stepsAside = false
        case .pointerExited:
            pointerInside = false
            stepsAside = true
        case .dragEnded(let dropped):
            isDragging = false
            stepsAside = false
            // A shot delivered is the job done. A cancelled drag puts everything back.
            // A Preview carries on with the next capture, or closes if none is left.
            if dropped, state.isPreview {
                resumePreview(at: now)
                return
            }
            if dropped {
                go(.idle)
                return
            }
            switch state {
            case .preview:
                if !pointerInside { resumePreview(at: now) }
            case .peek:
                if !pointerInside { timer = now + Theme.Timing.leaveGrace }
            case .idle, .shelf:
                break
            }
        default:
            break
        }
    }

    /// How much of the Preview's time is left, from 1 down to 0.
    func previewProgress(at now: Date) -> Double {
        guard state.isPreview, settings.previewDuration > 0 else { return 0 }
        let left = previewRemaining ?? timer.map { $0.timeIntervalSince(now) } ?? 0
        return min(1, max(0, left / settings.previewDuration))
    }

    private mutating func go(_ next: NotchState) {
        state = next
        timer = nil
        previewRemaining = nil
    }

    private mutating func pausePreview(at now: Date) {
        guard let timer else { return }
        previewRemaining = max(0, timer.timeIntervalSince(now))
        self.timer = nil
    }

    /// Leaving a held Preview never makes it vanish on the spot.
    private mutating func resumePreview(at now: Date) {
        timer = now + max(previewRemaining ?? settings.previewDuration, Theme.Timing.previewResumeMinimum)
        previewRemaining = nil
    }
}
