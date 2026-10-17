import AppKit
import SwiftUI

/// Owns the notch: where it sits, which state it's in, and what the user does
/// with it. The rules live in `NotchMachine`; this class feeds it events from the
/// pointer, clicks and the library, runs its one timer, and carries out actions.
@Observable final class NotchController {
    let library: ShotLibrary
    let preferences: Preferences
    /// Whether new shots open Pluck's Preview. Off when the user chose the macOS
    /// thumbnail, or macOS wouldn't let Pluck turn its own off.
    let showsPreview: Bool

    private(set) var geometry: NotchGeometry?
    private(set) var feedback: Feedback?
    /// The shot under the pointer, for the header's detail line.
    private(set) var hoveredShot: Shot.ID?
    private var machine = NotchMachine()

    @ObservationIgnored private var panel: NotchPanel!
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var monitors: [Any] = []

    init(library: ShotLibrary, preferences: Preferences, showsPreview: Bool) {
        self.library = library
        self.preferences = preferences
        self.showsPreview = showsPreview
        panel = NotchPanel(rootView: NotchView(controller: self))
        place()
        watchScreens()
        watchPointer()
        watchLibrary()
        Thumbnails.prefetch(library.shots.prefix(Theme.Notch.peekTileCount))
    }

    // MARK: Reading

    var state: NotchState { machine.state }

    var frame: NotchLayout.Frame {
        NotchLayout.frame(for: state, content: content, notch: geometry?.frame.size ?? Theme.Notch.referenceSize)
    }

    var content: NotchLayout.Content {
        NotchLayout.Content(shots: library.shots, pinned: library.pinnedShots, feedback: feedback,
                            showsLatest: preferences.showsLatestWhenIdle)
    }

    func previewProgress(at date: Date) -> Double { machine.previewProgress(at: date) }

    /// The Preview's timer is held while the pointer is on it.
    var previewIsHeld: Bool { machine.timer == nil }

    // MARK: Intents

    /// A click on the notch itself opens the Shelf, from any state.
    func clickedNotch() { send(.clicked) }

    func copy(_ id: Shot.ID) {
        library.copy([id])
        send(.finished, feedback: Feedback(kind: .copied))
    }

    func togglePin(_ id: Shot.ID) {
        let pinning = !library.isPinned(id)
        library.togglePin([id])
        send(.finished, feedback: Feedback(kind: pinning ? .pinned : .unpinned))
    }

    func trash(_ id: Shot.ID) {
        library.trash([id])
        send(.finished, feedback: Feedback(kind: .trashed))
    }

    func markup(_ id: Shot.ID) {
        library.openInPreview(id)
        send(.finished)
    }

    func undoTrash() {
        library.undoTrash()
        send(nil, feedback: Feedback(kind: .restored))
    }

    func hover(_ id: Shot.ID, _ inside: Bool) {
        if inside { hoveredShot = id } else if hoveredShot == id { hoveredShot = nil }
    }

    /// From the notch view, for pointer moves that land on the notch's own pixels.
    /// Every other move arrives through the global monitor.
    func pointerMovedInPanel(_ point: CGPoint) {
        let panelFrame = panel.frame
        pointerMoved(to: CGPoint(x: panelFrame.minX + point.x, y: panelFrame.maxY - point.y))
    }

    // MARK: Events

    /// Runs an event through the machine. A change of shape animates on the
    /// opening or closing spring; the machine's one timer is rescheduled whenever
    /// it changes, so a stale timer can never fire.
    private func send(_ event: NotchMachine.Event?, feedback newFeedback: Feedback? = nil) {
        var next = machine
        next.settings = NotchMachine.Settings(opensOnHover: preferences.opensOnHover,
                                              previewDuration: preferences.previewDuration.rawValue)
        if let event { next.handle(event, at: .now) }

        let changesState = next.state != machine.state
        // Collapsing into the notch settles closed; anything that grows opens.
        let opening = changesState ? next.state != .idle : true
        let timerChanged = next.timer != machine.timer
        withAnimation(changesState || newFeedback != nil ? Theme.Motion.reshape(opening: opening) : nil) {
            machine = next
            if let newFeedback { feedback = newFeedback }
        }
        if let newFeedback { endFeedback(after: newFeedback.duration) }
        if timerChanged { schedule(next.timer) }
        if changesState {
            if next.state == .idle { hoveredShot = nil }
            syncPointer()
        }
    }

    private func schedule(_ fireAt: Date?) {
        timerTask?.cancel()
        guard let fireAt else { return }
        timerTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, fireAt.timeIntervalSinceNow)))
            guard !Task.isCancelled else { return }
            self?.send(.timerFired)
        }
    }

    private func endFeedback(after duration: TimeInterval) {
        feedbackTask?.cancel()
        feedbackTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(duration))
            guard !Task.isCancelled, let self else { return }
            withAnimation(Theme.Motion.reshape(opening: false)) { feedback = nil }
            syncPointer()
        }
    }

    // MARK: Pointer

    /// Hover is geometry: the pointer's position against the notch's current
    /// hover zone. No invisible views, so nothing blocks clicks underneath.
    private func pointerMoved(to point: CGPoint) {
        guard let geometry else { return }
        let inside = NotchLayout.hoverZone(for: frame, state: state, geometry: geometry).contains(point)
        if inside != machine.pointerInside { send(inside ? .pointerEntered : .pointerExited) }
    }

    /// Re-checks the pointer without it moving, for when the notch changes shape
    /// under it.
    private func syncPointer() { pointerMoved(to: NSEvent.mouseLocation) }

    private func watchPointer() {
        let moved = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] _ in
            MainActor.assumeIsolated { self?.syncPointer() }
        }
        let clicked = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.clickedOutside) }
        }
        monitors = [moved, clicked].compactMap { $0 }
    }

    // MARK: Library

    private func watchLibrary() {
        library.onArrival = { [weak self] shot in
            Thumbnails.prefetch([shot])
            guard let self, showsPreview else { return }
            send(.shotArrived(shot.id))
        }
        // A Preview whose shot disappears (deleted in Finder, say) closes at once.
        Task { [weak self] in
            for await ids in Observations({ [weak self] in self?.library.shots.map(\.id) ?? [] }) {
                guard let self else { return }
                if case .preview(let id) = state, !ids.contains(id) { send(.shotRemoved(id)) }
            }
        }
    }

    // MARK: Screens

    private func watchScreens() {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.place()
            }
        }
    }

    /// Puts the panel on the built-in display, centered on its notch. Falls back
    /// to the main display when the lid is closed.
    // ponytail: built-in only; "Show on: Main / With mouse" arrives with Settings.
    private func place() {
        guard let screen = NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.main else { return }
        let geometry = NotchGeometry(screen: screen)
        let canvas = Theme.Notch.canvas
        panel.setFrame(CGRect(x: geometry.frame.midX - canvas.width / 2,
                              y: screen.frame.maxY - canvas.height,
                              width: canvas.width,
                              height: canvas.height),
                       display: true)
        self.geometry = geometry
        panel.orderFrontRegardless()
    }
}

private extension NSScreen {
    var isBuiltIn: Bool {
        guard let id = deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID else { return false }
        return CGDisplayIsBuiltin(id) != 0
    }
}
