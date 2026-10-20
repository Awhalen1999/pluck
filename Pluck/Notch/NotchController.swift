import AppKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "app.pluck.Pluck", category: "Notch")

/// Owns the notch: its state, what the user does with it, and where it sits. The
/// rules are `NotchMachine`'s; this feeds it events and carries out actions.
@Observable final class NotchController {
    let library: ShotLibrary
    let preferences: Preferences

    private(set) var geometry: NotchGeometry?
    private(set) var feedback: Feedback?
    /// The shot under the pointer, or the one the arrow keys reached.
    private(set) var focusedShot: Shot.ID?
    /// ⌘-clicked in the Shelf. While there are any, actions take them all.
    private(set) var selection: Set<Shot.ID> = []
    /// Faded where they came from while they're dragged.
    private(set) var draggedShots: Set<Shot.ID> = []
    private var machine = NotchMachine()

    @ObservationIgnored private let panel: NotchPanel
    @ObservationIgnored private let keyboard: KeyboardHandoff
    @ObservationIgnored private let input = NotchInput()
    @ObservationIgnored private let quickLookPanel = QuickLook()
    @ObservationIgnored private let dragSource = ShotDragSource()
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    /// Waiting captures in the drag under way that the user keeps once dropped.
    @ObservationIgnored private var keeping: Set<Shot.ID> = []
    /// Where the pointer was when the arrow keys last moved the focus. Until it
    /// moves, shots scrolling under it don't take the focus back.
    @ObservationIgnored private var pointerAtKeyboardFocus: CGPoint?

    init(library: ShotLibrary, preferences: Preferences) {
        self.library = library
        self.preferences = preferences
        let panel = NotchPanel()
        self.panel = panel
        keyboard = KeyboardHandoff(panel: panel)
        panel.host(NotchView(controller: self))
        keyboard.onTakenAway = { [weak self] in self?.send(.wentToAnotherApp) }
        input.pointerMoved = { [weak self] point, fast in self?.pointerMoved(to: point, fast: fast) }
        input.clickedInAnotherApp = { [weak self] in self?.send(.wentToAnotherApp) }
        input.keyDown = { [weak self] event in self?.handleKey(event) ?? false }
        input.sampleInterval = { [weak self] in
            self?.isResting ?? true ? Theme.Timing.pointerAtRest : Theme.Timing.pointerOpen
        }
        quickLookPanel.onClose = { [weak self] id in
            guard let self else { return }
            if state == .shelf, let id { focusFromKeyboard(id) }
            updateKeyboard()
        }
        dragSource.moved = { [weak self] point in self?.input.report(point) }
        dragSource.ended = { [weak self] operation in self?.dragEnded(operation) }
        goHome()
        watchScreens()
        watchLibrary()
    }

    // MARK: Reading

    var state: NotchState { machine.state }

    /// The state, or Idle while a drag has the notch stepped aside.
    var shownState: NotchState { machine.shownState }

    /// Hidden, but still in place so the drag's source stays put, while stepped aside.
    var showsContent: Bool { !machine.stepsAside }

    var frame: NotchLayout.Frame {
        // Stepped aside for a drag, the notch is bare: no ears.
        NotchLayout.frame(for: shownState, content: machine.stepsAside ? NotchLayout.Content() : content,
                          notch: geometry?.frame.size ?? Theme.Notch.referenceSize)
    }

    var content: NotchLayout.Content {
        NotchLayout.Content(shots: library.shots, pinned: library.pinnedShots, pending: library.pending,
                            feedback: feedback, showsLatest: preferences.showsLatestWhenIdle)
    }

    /// The Preview's captures, the one in front first.
    var previewStack: [Shot] {
        guard case .preview(let id) = state, let front = library.pending.first(where: { $0.id == id }) else { return [] }
        return [front] + library.pending.filter { $0.id != id }
    }

    func previewProgress(at date: Date) -> Double { machine.previewProgress(at: date) }

    var previewIsHeld: Bool { machine.timer == nil }

    /// The arrow keys moved the focus, so the Shelf keeps it in view.
    var focusFollowsKeyboard: Bool { pointerAtKeyboardFocus != nil }

    // MARK: Intents

    /// Opens the Shelf from any state. In the Shelf it clears the selection, as a
    /// click on empty space does in Finder.
    func clickedNotch() {
        selection = []
        send(.clicked)
    }

    func clicked(_ id: Shot.ID, modifiers: NSEvent.ModifierFlags) {
        if state == .shelf, modifiers.contains(.command) {
            select(selection.symmetricDifference([id]))
        } else {
            selection = []
            copy([id])
        }
    }

    func clearSelection() { selection = [] }

    func copy(_ ids: [Shot.ID]) {
        act("Copy", on: ids, Feedback(kind: .copied)) { library.copy($0) }
    }

    /// The menu bar's Copy Latest Screenshot: the capture in the Preview, if there is one.
    func copyLatest() {
        if let latest = library.pending.first ?? library.shots.first { copy([latest.id]) }
    }

    func togglePin(_ ids: [Shot.ID]) {
        let pinning = !ids.allSatisfy(library.isPinned)
        act(pinning ? "Pin" : "Unpin", on: ids, Feedback(kind: pinning ? .pinned : .unpinned)) {
            library.togglePin($0)
        }
    }

    func trash(_ ids: [Shot.ID]) {
        act("Trash", on: ids, Feedback(kind: .trashed), saving: false) { library.trash($0) }
    }

    func markup(_ id: Shot.ID) {
        act("Markup", on: [id]) { library.openInPreview($0[0]) }
    }

    func reveal(_ ids: [Shot.ID]) {
        act("Show in Finder", on: ids) { library.revealInFinder($0) }
    }

    func undoTrash() {
        log.debug("Undo trash")
        library.undoTrash()
        send(nil, feedback: Feedback(kind: .restored))
    }

    /// Every shot in the Shelf's order, or just the selection when the shot is in one.
    func quickLook(_ id: Shot.ID) {
        let ids = targets(id)
        act("Quick Look", on: ids) { saved in
            let order = NotchLayout.shelfSections(content).flatMap(\.rows).flatMap(\.tiles).map(\.shot)
            let shots = saved.count > 1 ? order.filter { saved.contains($0.id) } : order
            let start = saved[ids.firstIndex(of: id) ?? 0]
            guard let index = shots.firstIndex(where: { $0.id == start }) else { return }
            keyboard.comeForward()
            quickLookPanel.show(shots, startingAt: index)
        }
    }

    /// Every action on shots goes through here. A waiting capture is saved first,
    /// unless it's going to the Trash, so it never flashes onto the Desktop on its way.
    /// Shots already gone, to a click the notch hadn't caught up with or a menu
    /// left open, are left out; with none left, nothing happens.
    private func act(_ name: String, on ids: [Shot.ID], _ feedback: Feedback? = nil, saving: Bool = true,
                     _ action: ([Shot.ID]) -> Void) {
        let ids = ids.filter { library.shot($0) != nil }
        guard !ids.isEmpty else { return }
        log.debug("\(name, privacy: .public) \(ids.count, privacy: .public)")
        action(saving ? library.save(ids) : ids)
        followPending()
        if var feedback {
            feedback.count = ids.count
            send(nil, feedback: feedback)
        }
    }

    func hover(_ id: Shot.ID, _ inside: Bool) {
        if let point = pointerAtKeyboardFocus {
            guard NSEvent.mouseLocation != point else { return }
            pointerAtKeyboardFocus = nil
        }
        if inside { focusedShot = id } else if focusedShot == id { focusedShot = nil }
    }

    /// The pointer left the notch's own pixels, maybe for another app's window,
    /// whose moves the global monitor may not see.
    func pointerLeftShape() { syncPointer() }

    func pointerMovedInPanel(_ point: CGPoint) {
        input.report(CGPoint(x: panel.frame.minX + point.x, y: panel.frame.maxY - point.y))
    }

    /// Selecting is newer than whatever the header last said, so it takes the
    /// feedback slot ("3 selected") at once.
    private func select(_ ids: Set<Shot.ID>) {
        selection = ids
        if !ids.isEmpty { feedback = nil }
    }

    /// What an action on `id` applies to: the selection when it's part of one.
    private func targets(_ id: Shot.ID) -> [Shot.ID] {
        selection.contains(id) ? library.shots(withIDs: Array(selection)).map(\.id) : [id]
    }

    // MARK: Dragging

    /// A drag hands shots off: their files go to the drop by way of the hand-off
    /// folder, and they leave Pluck. Pinned shots, and everything when the user keeps
    /// what they drag out, go as themselves. A waiting capture always goes by way of
    /// the hand-off folder, since it isn't saved anywhere yet.
    func beginDrag(_ id: Shot.ID, from view: NSView, event: NSEvent) {
        let shots = targets(id).compactMap(library.shot)
        guard !shots.isEmpty else { return }
        let point = view.convert(event.locationInWindow, from: nil)
        let images = shots.map { ShotDragSource.image(for: $0) }
        let away = library.handOff(shots.filter { library.isPending($0.id) || handsOff($0.id) }.map(\.id))
        keeping = Set(shots.filter { library.isPending($0.id) && !handsOff($0.id) }.map(\.id))
        let items = zip(shots, images).map { shot, image in
            let item = NSDraggingItem(pasteboardWriter: (away[shot.id] ?? shot.url) as NSURL)
            item.setDraggingFrame(CGRect(x: point.x - image.size.width / 2, y: point.y - image.size.height / 2,
                                         width: image.size.width, height: image.size.height),
                                  contents: image)
            return item
        }
        log.debug("Drag began with \(shots.count, privacy: .public)")
        draggedShots = Set(shots.map(\.id))
        let session = view.beginDraggingSession(with: items, event: event, source: dragSource)
        session.draggingFormation = items.count > 1 ? .stack : .none
        send(.dragStarted)
    }

    private func dragEnded(_ operation: NSDragOperation) {
        log.debug("Drag ended with operation \(operation.rawValue, privacy: .public)")
        let shots = Array(draggedShots)
        draggedShots = []
        // The Trash takes a drag as a delete, which leaves the file to its source:
        // the shots go back where they were, then to the Trash as the button sends them.
        let trashed = operation.contains(.delete)
        let dropped = !operation.isEmpty && !trashed
        send(.dragEnded(dropped: dropped))
        // A move is Finder putting the file where the user dropped it: that's where
        // it's kept. Otherwise an app took it, and a capture the user keeps is saved.
        library.finishHandOff(dropped: dropped, keeping: operation == .move ? [] : keeping)
        keeping = []
        if trashed { trash(shots) }
        followPending()
    }

    private func handsOff(_ id: Shot.ID) -> Bool {
        preferences.removeDraggedOut && !library.isPinned(id)
    }

    // MARK: Menu

    /// For a shot, or the selection it's part of, with the Shelf's shortcuts shown.
    func menu(for id: Shot.ID) -> NSMenu {
        let ids = targets(id)
        let menu = NSMenu()
        menu.addItem(menuItem(ids.count > 1 ? "Copy \(ids.count) Shots" : "Copy", key: "c") { [weak self] in self?.copy(ids) })
        menu.addItem(menuItem("Quick Look") { [weak self] in self?.quickLook(id) })
        menu.addItem(menuItem("Show in Finder") { [weak self] in self?.reveal(ids) })
        menu.addItem(.separator())
        menu.addItem(menuItem(ids.allSatisfy(library.isPinned) ? "Unpin" : "Pin", key: "p") { [weak self] in self?.togglePin(ids) })
        menu.addItem(menuItem("Move to Trash", key: "\u{8}") { [weak self] in self?.trash(ids) })
        return menu
    }

    // MARK: Keyboard

    /// The Shelf has the keyboard while it's open, and Quick Look while it shows.
    /// Otherwise it's back where it was, so typing never lands in Pluck.
    private func updateKeyboard() {
        guard !quickLookPanel.isShown else { return }
        if state == .shelf { keyboard.take() } else { keyboard.giveBack() }
    }

    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window === panel, let key = ShelfKey(event) else { return false }
        guard key.repeats || !event.isARepeat else { return true }
        let ids = selection.isEmpty ? focusedShot.map { [$0] } ?? [] : library.shots(withIDs: Array(selection)).map(\.id)
        switch key {
        case .move(let direction):
            focusFromKeyboard(NotchLayout.shot(from: focusedShot, moving: direction, in: NotchLayout.shelfSections(content)))
        case .escape:
            if selection.isEmpty { send(.dismissed) } else { selection = [] }
        case .close:
            send(.dismissed)
        case .copyAndClose:
            guard !ids.isEmpty else { return false }
            copy(ids)
            send(.dismissed)
        case .copy:
            guard !ids.isEmpty else { return false }
            copy(ids)
        case .quickLook:
            guard let id = ids.first else { return false }
            quickLook(id)
        case .trash:
            guard !ids.isEmpty else { return false }
            trashFromKeyboard(ids)
        case .undo:
            guard !library.lastTrashed.isEmpty else { return false }
            undoTrash()
        case .pin:
            guard !ids.isEmpty else { return false }
            togglePin(ids)
        case .selectAll:
            select(Set(library.shots.map(\.id)))
        }
        return true
    }

    private func focusFromKeyboard(_ id: Shot.ID?) {
        pointerAtKeyboardFocus = NSEvent.mouseLocation
        focusedShot = id
    }

    /// The focus moves on to the next shot, so pressing ⌫ again trashes that one.
    private func trashFromKeyboard(_ ids: [Shot.ID]) {
        guard selection.isEmpty, let id = focusedShot else { return trash(ids) }
        let sections = NotchLayout.shelfSections(content)
        let after = NotchLayout.shot(from: id, moving: .right, in: sections)
        let next = after != id ? after : NotchLayout.shot(from: id, moving: .left, in: sections)
        trash(ids)
        focusFromKeyboard(next != id ? next : nil)
    }

    // MARK: Events

    /// Runs an event through the machine. Its one timer is rescheduled whenever it
    /// changes, so a stale timer can never fire.
    private func send(_ event: NotchMachine.Event?, feedback newFeedback: Feedback? = nil) {
        var next = machine
        // Hovering an Undo doesn't turn the notch into Peek under the pointer.
        next.settings = NotchMachine.Settings(opensOnHover: preferences.opensOnHover && feedback?.canUndo != true,
                                              previewDuration: preferences.previewDuration.rawValue)
        if let event { next.handle(event, at: .now) }
        let previous = machine.state
        let stateChanged = next.state != previous
        if stateChanged {
            // Only the event's name is public; shot IDs are file paths.
            let name = event.map { String(describing: $0).prefix { $0 != "(" } } ?? "feedback"
            log.debug("\(name, privacy: .public) → \(next.state.name, privacy: .public)")
        }
        let old = frame
        let timerChanged = next.timer != machine.timer
        machine = next
        if let newFeedback {
            feedback = newFeedback
            endFeedback(after: newFeedback.duration)
        }
        if timerChanged { schedule(next.timer) }
        if stateChanged {
            // Focus and selection belong to the state that had them.
            focusedShot = nil
            selection = []
            pointerAtKeyboardFocus = nil
            // Leaving the Preview saves whatever it still holds.
            if previous.isPreview, !next.state.isPreview { library.savePending() }
            updateKeyboard()
        }
        if frame != old { syncPointer() }
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
            feedback = nil
            syncPointer()
            send(.feedbackEnded)
        }
    }

    // MARK: Pointer

    /// The panel takes the mouse exactly while the pointer is on the shape, so a
    /// click always lands where the user sees it; hover uses the hover zone.
    private func pointerMoved(to point: CGPoint, fast: Bool) {
        guard let geometry else { return }
        let onShape = NotchLayout.shapeRect(for: frame, geometry: geometry).contains(point)
        if panel.ignoresMouseEvents == onShape { panel.ignoresMouseEvents = !onShape }
        let inside = NotchLayout.hoverZone(for: frame, state: shownState, geometry: geometry).contains(point)
        if inside != machine.pointerInside { send(inside ? .pointerEntered : .pointerExited) }
        if inside, fast, shownState == .idle { send(.pointerPassing) }
    }

    /// For when the notch changes shape under a pointer that hasn't moved.
    private func syncPointer() { input.report(NSEvent.mouseLocation) }

    // MARK: Library

    private func watchLibrary() {
        Task { [weak self] in
            for await _ in Observations({ [weak self] in self?.library.pending.map(\.id) ?? [] }) {
                guard let self else { return }
                Thumbnails.prefetch(library.pending)
                followPending()
            }
        }
        // Peek opens with its thumbnails in place.
        Task { [weak self] in
            for await shots in Observations({ [weak self] in Array(self?.library.shots.prefix(Theme.Notch.peekTileCount) ?? []) }) {
                Thumbnails.prefetch(shots)
            }
        }
        // A shot that's gone leaves the focus and the selection.
        Task { [weak self] in
            for await ids in Observations({ [weak self] in Set(self?.library.shots.map(\.id) ?? []) }) {
                guard let self else { return }
                if let focusedShot, !ids.contains(focusedShot) { self.focusedShot = nil }
                if !selection.isSubset(of: ids) { selection.formIntersection(ids) }
            }
        }
    }

    /// The Preview shows the newest waiting capture. When that changes, the next
    /// one comes up (a new capture, or the one behind); when none is left, the
    /// Preview closes. Mid-drag the machine holds off, and the drag's end asks again.
    private func followPending() {
        let front = library.pending.first?.id
        if case .preview(let shown) = state, shown == front { return }
        if let front {
            send(.shotUp(front))
        } else if state.isPreview {
            send(.previewEmptied)
        }
    }

    // MARK: Displays

    private func watchScreens() {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.goHome()
            }
        }
        // "Show on" changed in Settings.
        Task { [weak self] in
            for await _ in Observations({ [weak self] in self?.preferences.notchDisplay }) {
                self?.goHome()
            }
        }
    }

    /// Idle with nothing to show, when the pointer needs watching least.
    private var isResting: Bool {
        shownState == .idle && feedback == nil && !machine.isDragging
    }

    /// The display "Show on" names. Without a built-in display (a closed lid),
    /// that's the main one.
    private func goHome() {
        let screens = NSScreen.screens
        let home = preferences.notchDisplay == .builtIn ? screens.first(where: \.isBuiltIn) : nil
        if let home = home ?? screens.first { geometry = panel.place(on: home) }
    }
}

private extension NotchState {
    /// Without its shot, safe to log.
    var name: String {
        switch self {
        case .idle: "idle"
        case .peek: "peek"
        case .shelf: "shelf"
        case .preview: "preview"
        }
    }
}

private extension NSScreen {
    /// Stable across `NSScreen` objects, which macOS recreates as displays change.
    var displayID: CGDirectDisplayID? {
        deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
    }

    var isBuiltIn: Bool {
        displayID.map { CGDisplayIsBuiltin($0) != 0 } ?? false
    }
}
