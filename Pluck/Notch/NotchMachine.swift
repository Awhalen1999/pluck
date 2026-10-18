import Foundation

/// The notch's state. It is always exactly one of these; see the state contract
/// in CLAUDE.md.
enum NotchState: Equatable {
    case idle
    case peek
    case shelf
    case preview(Shot.ID)
}

/// The notch's rules as a plain value: events go in, the state and its one timer
/// come out. `NotchController` feeds it events and runs the timer; everything
/// else is decided here, which is why every rule can be tested without a screen.
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
        case shotArrived(Shot.ID)
        case shotRemoved(Shot.ID)
        /// The user acted on what the notch was showing: copied it, pinned it, trashed it.
        case finished
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
    /// When the current state's one timer fires, if it has one. Every transition
    /// replaces it, so a timer can never outlive its state.
    private(set) var timer: Date?
    private(set) var pointerInside = false
    /// Time left on the Preview while the pointer holds it open.
    private(set) var previewRemaining: TimeInterval?
    /// A shot is being dragged out of the notch. Nothing it shows may change
    /// until the drag ends.
    private(set) var isDragging = false
    /// During a drag, the notch folds back to its idle shape once the drag
    /// leaves it, so the user can see where they're dropping.
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

        case .shotArrived(let id):
            guard state != .shelf else { return }
            go(.preview(id))
            if pointerInside {
                previewRemaining = settings.previewDuration
            } else {
                timer = now + settings.previewDuration
            }

        case .shotRemoved(let id):
            if state == .preview(id) { go(.idle) }

        case .finished:
            if case .preview = state { go(.idle) }

        case .dragStarted:
            isDragging = true
            stepsAside = !pointerInside
            if case .preview = state { pausePreview(at: now) }
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

    /// While a drag is under way, the pointer only moves the notch aside and back.
    /// Arrivals, clicks and timers wait, so nothing changes under the drag.
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
            // A shot delivered is the job done, from any state. A cancelled drag
            // puts everything back the way it was.
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
        guard case .preview = state, settings.previewDuration > 0 else { return 0 }
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
