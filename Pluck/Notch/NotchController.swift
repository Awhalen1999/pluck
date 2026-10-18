import AppKit
import OSLog
import SwiftUI

private let log = Logger(subsystem: "app.pluck.Pluck", category: "Notch")

/// Owns the notch: where it sits, which state it's in, and what the user does
/// with it. The rules live in `NotchMachine`; this class feeds it events from the
/// pointer, clicks, drags and the library, runs its one timer, and carries out
/// actions.
@Observable final class NotchController {
    let library: ShotLibrary
    let preferences: Preferences
    /// Whether new shots open Pluck's Preview. Off when the user chose the macOS
    /// thumbnail, or macOS wouldn't let Pluck turn its own off.
    let showsPreview: Bool

    private(set) var geometry: NotchGeometry?
    private(set) var feedback: Feedback?
    /// The shot the user is on: under the pointer, or reached with the arrow
    /// keys. The header describes it, and the Shelf's keys act on it.
    private(set) var focusedShot: Shot.ID?
    /// Shots ⌘-clicked in the Shelf. While there are any, actions take them all.
    private(set) var selection: Set<Shot.ID> = []
    /// The shots in the drag under way, shown faded where they came from.
    private(set) var draggedShots: Set<Shot.ID> = []
    private var machine = NotchMachine()

    @ObservationIgnored private var panel: NotchPanel!
    /// The display the notch is on right now: its home, or the display a
    /// Preview's shot was taken on.
    @ObservationIgnored private var screen: NSScreen?
    @ObservationIgnored private var homeTask: Task<Void, Never>?
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private var pointerTask: Task<Void, Never>?
    @ObservationIgnored private let dragSource = ShotDragSource()
    @ObservationIgnored private let quickLookPanel = QuickLook()
    /// The views drawing each shot right now, so Quick Look can zoom from them.
    @ObservationIgnored private let shotViews = NSMapTable<NSString, NSView>.strongToWeakObjects()
    /// Where the pointer was when the arrow keys last moved the focus. Until it
    /// moves, shots scrolling under it don't take the focus back.
    @ObservationIgnored private var pointerAtKeyboardFocus: CGPoint?

    init(library: ShotLibrary, preferences: Preferences, showsPreview: Bool) {
        self.library = library
        self.preferences = preferences
        self.showsPreview = showsPreview
        panel = NotchPanel(rootView: NotchView(controller: self))
        goHome()
        watchScreens()
        watchPointer()
        watchLibrary()
        watchDrags()
        watchQuickLook()
        Thumbnails.prefetch(library.shots.prefix(Theme.Notch.peekTileCount))
    }

    // MARK: Reading

    var state: NotchState { machine.state }

    /// What the shape shows: the state, or Idle while a drag has it stepped aside.
    var shownState: NotchState { machine.shownState }

    /// Whether the state's content is visible. Hidden, but still in place, while
    /// a drag has the notch stepped aside, so the drag's source stays put.
    var showsContent: Bool { !machine.stepsAside }

    var frame: NotchLayout.Frame {
        // Stepped aside for a drag, the notch is bare: no ears, nothing to look at.
        let content = machine.stepsAside ? NotchLayout.Content() : self.content
        return NotchLayout.frame(for: shownState, content: content, notch: geometry?.frame.size ?? Theme.Notch.referenceSize)
    }

    var content: NotchLayout.Content {
        NotchLayout.Content(shots: library.shots, pinned: library.pinnedShots, feedback: feedback,
                            showsLatest: preferences.showsLatestWhenIdle)
    }

    func previewProgress(at date: Date) -> Double { machine.previewProgress(at: date) }

    /// The Preview's timer is held while the pointer is on it.
    var previewIsHeld: Bool { machine.timer == nil }

    /// The arrow keys moved the focus, so the Shelf keeps it in view.
    var focusFollowsKeyboard: Bool { pointerAtKeyboardFocus != nil }

    // MARK: Intents

    /// A click on the notch itself opens the Shelf, from any state. In the Shelf
    /// it clears the selection, as a click on empty space does in Finder.
    func clickedNotch() {
        selection = []
        send(.clicked)
    }

    /// A click copies the shot. In the Shelf, ⌘-click adds it to the selection
    /// or takes it out.
    func clicked(_ id: Shot.ID, modifiers: NSEvent.ModifierFlags) {
        if state == .shelf, modifiers.contains(.command) {
            select(selection.symmetricDifference([id]))
            return
        }
        selection = []
        copy([id])
    }

    func clearSelection() { selection = [] }

    /// Selecting is newer than whatever the header last said, so it takes the
    /// feedback slot ("3 selected") at once.
    private func select(_ ids: Set<Shot.ID>) {
        withAnimation(Theme.Motion.hover) {
            selection = ids
            if !ids.isEmpty { feedback = nil }
        }
    }

    func copy(_ ids: [Shot.ID]) {
        log.debug("Copy \(ids.count, privacy: .public)")
        library.copy(ids)
        send(.finished, feedback: Feedback(kind: .copied, count: ids.count))
    }

    func togglePin(_ ids: [Shot.ID]) {
        let pinning = !ids.allSatisfy(library.isPinned)
        log.debug("\(pinning ? "Pin" : "Unpin", privacy: .public) \(ids.count, privacy: .public)")
        library.togglePin(ids)
        send(.finished, feedback: Feedback(kind: pinning ? .pinned : .unpinned, count: ids.count))
    }

    func trash(_ ids: [Shot.ID]) {
        log.debug("Trash \(ids.count, privacy: .public)")
        library.trash(ids)
        send(.finished, feedback: Feedback(kind: .trashed, count: ids.count))
    }

    func move(_ ids: [Shot.ID], to folder: URL) {
        log.debug("Move \(ids.count, privacy: .public)")
        library.move(ids, to: folder)
        send(.finished, feedback: Feedback(kind: .moved, count: ids.count))
    }

    func markup(_ id: Shot.ID) {
        library.openInPreview(id)
        send(.finished)
    }

    func undoTrash() {
        log.debug("Undo trash")
        library.undoTrash()
        send(nil, feedback: Feedback(kind: .restored))
    }

    /// Opens Quick Look on a shot, with every shot a keypress away in the
    /// Shelf's order, or just the selection when the shot is part of one. From
    /// the Preview it counts as acting on it, so the Preview finishes.
    func quickLook(_ id: Shot.ID) {
        let ids = targets(id)
        let order = NotchLayout.shelfSections(content).flatMap(\.rows).flatMap(\.tiles).map(\.shot)
        let shots = ids.count > 1 ? order.filter { ids.contains($0.id) } : order
        guard let index = shots.firstIndex(where: { $0.id == id }) else { return }
        log.debug("Quick Look")
        comeForward()
        quickLookPanel.show(shots, startingAt: index)
        if case .preview = state { send(.finished) }
    }

    func hover(_ id: Shot.ID, _ inside: Bool) {
        if let point = pointerAtKeyboardFocus {
            guard NSEvent.mouseLocation != point else { return }
            pointerAtKeyboardFocus = nil
        }
        if inside { focusedShot = id } else if focusedShot == id { focusedShot = nil }
    }

    func register(_ view: NSView, for id: Shot.ID) {
        shotViews.setObject(view, forKey: id as NSString)
    }

    /// The pointer left the notch's own pixels. Where it went, the global monitor
    /// may never say (macOS only sends moves to the active app), so check now.
    func pointerLeftShape() { syncPointer() }

    /// From the notch view, for pointer moves that land on the notch's own pixels.
    /// Every other move arrives through the global monitor.
    func pointerMovedInPanel(_ point: CGPoint) {
        let panelFrame = panel.frame
        pointerMoved(to: CGPoint(x: panelFrame.minX + point.x, y: panelFrame.maxY - point.y))
    }

    // MARK: Dragging

    /// Starts dragging a shot out of the notch. The image under the cursor is the
    /// shot itself, and other apps receive the file.
    func beginDrag(_ id: Shot.ID, from view: NSView, event: NSEvent) {
        let shots = library.shots(withIDs: targets(id))
        guard !shots.isEmpty else { return }
        let point = view.convert(event.locationInWindow, from: nil)
        let items = shots.map { shot in
            let item = NSDraggingItem(pasteboardWriter: shot.url as NSURL)
            let image = ShotDragSource.image(for: shot)
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

    private func watchDrags() {
        dragSource.moved = { [weak self] point in self?.pointerMoved(to: point) }
        dragSource.ended = { [weak self] operation in
            guard let self else { return }
            log.debug("Drag ended with operation \(operation.rawValue, privacy: .public)")
            // Anything but a move leaves the file behind for the one-hour cleanup.
            // A move took it somewhere else, and the library lets it go on its own.
            if !operation.isEmpty, operation != .move, preferences.removeDraggedOut {
                library.recordDragOut(Array(draggedShots))
            }
            draggedShots = []
            send(.dragEnded(dropped: !operation.isEmpty))
        }
    }

    // MARK: Menu

    /// The right-click menu for a shot, or for the selection it's part of:
    /// native, with the Shelf's shortcuts shown.
    func menu(for id: Shot.ID) -> NSMenu {
        let ids = targets(id)
        let menu = NSMenu()
        menu.addItem(menuItem(ids.count > 1 ? "Copy \(ids.count) Shots" : "Copy", key: "c") { [weak self] in self?.copy(ids) })
        menu.addItem(menuItem("Quick Look") { [weak self] in self?.quickLook(id) })
        menu.addItem(menuItem("Show in Finder") { [weak self] in self?.library.revealInFinder(ids) })
        menu.addItem(.separator())
        menu.addItem(moveMenuItem(for: ids))
        menu.addItem(menuItem(ids.allSatisfy(library.isPinned) ? "Unpin" : "Pin", key: "p") { [weak self] in self?.togglePin(ids) })
        menu.addItem(menuItem("Move to Trash", key: "\u{8}") { [weak self] in self?.trash(ids) })
        return menu
    }

    /// "Move To": the usual folders, then any folder at all.
    private func moveMenuItem(for ids: [Shot.ID]) -> NSMenuItem {
        let submenu = NSMenu()
        let folders: [URL] = [.desktopDirectory, .documentsDirectory, .downloadsDirectory, .picturesDirectory]
        for folder in folders where folder.standardizedFileURL != library.folder {
            submenu.addItem(menuItem(FileManager.default.displayName(atPath: folder.path(percentEncoded: false))) { [weak self] in
                self?.move(ids, to: folder)
            })
        }
        submenu.addItem(.separator())
        submenu.addItem(menuItem("Other…") { [weak self] in self?.chooseFolder(for: ids) })
        let item = NSMenuItem(title: "Move To", action: nil, keyEquivalent: "")
        item.submenu = submenu
        return item
    }

    private func chooseFolder(for ids: [Shot.ID]) {
        let open = NSOpenPanel()
        open.canChooseDirectories = true
        open.canChooseFiles = false
        open.canCreateDirectories = true
        open.prompt = "Move"
        comeForward()
        open.begin { [weak self] response in
            if response == .OK, let folder = open.url { self?.move(ids, to: folder) }
            self?.updateKeyboard()
        }
        // Above the notch, set once it shows, since showing resets it.
        open.level = .aboveNotch
    }

    /// What an action on `id` applies to: the whole selection when it's part of
    /// one, in the library's order, or just that shot.
    private func targets(_ id: Shot.ID) -> [Shot.ID] {
        selection.contains(id) ? library.shots(withIDs: Array(selection)).map(\.id) : [id]
    }

    // MARK: Keyboard

    /// Who has the keyboard. The Shelf takes it while it's open, and Quick Look
    /// while it shows; otherwise it goes straight back to the app the user was
    /// in, so typing there never lands in Pluck.
    private func updateKeyboard() {
        let shelf = state == .shelf
        panel.acceptsKeyboard = shelf
        // Quick Look has it; this runs again when it closes.
        guard !quickLookPanel.isShown else { return }
        if shelf {
            panel.makeKey()
        } else if NSApp.isActive, NSApp.keyWindow == nil || NSApp.keyWindow === panel {
            // Unless the user is in one of Pluck's own windows. A key notch lets
            // go by deactivating; after Quick Look, Pluck is truly active and
            // lets go by hiding. Each does nothing in the other case.
            NSApp.deactivate()
            NSApp.hide(nil)
        }
    }

    /// Makes Pluck the active app, for Quick Look and the folder picker: neither
    /// takes keys otherwise. The notch takes the keyboard first, or macOS
    /// refuses the activation; see Platform facts.
    private func comeForward() {
        panel.acceptsKeyboard = true
        panel.makeKey()
        NSApp.activate()
    }

    private func watchQuickLook() {
        quickLookPanel.sourceFrame = { [weak self] id in
            guard let view = self?.shotViews.object(forKey: id as NSString), let window = view.window else { return nil }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
        quickLookPanel.onClose = { [weak self] id in
            guard let self else { return }
            // Back in the Shelf, the focus is on the shot Quick Look ended on.
            if state == .shelf, let id { focusFromKeyboard(id) }
            updateKeyboard()
        }
    }

    /// The Shelf's keys, as Finder and Photos have them. Only the Shelf takes the
    /// keyboard, so none of these can fire while the user types in another app.
    /// Returns false for any other key, which AppKit then handles as usual.
    private func handleKey(_ event: NSEvent) -> Bool {
        guard event.window === panel else { return false }
        let flags = event.modifierFlags.intersection([.command, .shift, .option, .control])
        let plain = flags.isEmpty
        let command = flags == .command
        let key = event.charactersIgnoringModifiers?.lowercased()
        let special = event.specialKey
        let ids = selection.isEmpty ? focusedShot.map { [$0] } ?? [] : library.shots(withIDs: Array(selection)).map(\.id)

        if plain, let direction = special.flatMap({ Self.arrows[$0] }) {
            focusFromKeyboard(NotchLayout.shot(from: focusedShot, moving: direction, in: NotchLayout.shelfSections(content)))
            return true
        }
        // Holding a key repeats only the arrows.
        if event.isARepeat { return true }

        if plain, key == "\u{1b}" {
            // Esc goes back one level: the selection first, then the Shelf.
            if selection.isEmpty { send(.dismissed) } else { selection = [] }
        } else if plain, special == .carriageReturn || special == .enter, !ids.isEmpty {
            // Return copies and closes, so the next ⌘V lands in the user's app.
            copy(ids)
            send(.dismissed)
        } else if command, key == "c", !ids.isEmpty {
            copy(ids)
        } else if plain, key == " ", let id = ids.first {
            quickLook(id)
        } else if plain || command, special == .delete || special == .deleteForward, !ids.isEmpty {
            trashFromKeyboard(ids)
        } else if command, key == "z", !library.lastTrashed.isEmpty {
            undoTrash()
        } else if plain || command, key == "p", !ids.isEmpty {
            togglePin(ids)
        } else if command, key == "a" {
            select(Set(library.shots.map(\.id)))
        } else {
            return false
        }
        return true
    }

    private static let arrows: [NSEvent.SpecialKey: MoveCommandDirection] = [
        .leftArrow: .left, .rightArrow: .right, .upArrow: .up, .downArrow: .down,
    ]

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

    /// Runs an event through the machine. A change of shape animates on the
    /// opening or closing spring; the machine's one timer is rescheduled whenever
    /// it changes, so a stale timer can never fire.
    private func send(_ event: NotchMachine.Event?, feedback newFeedback: Feedback? = nil) {
        var next = machine
        // Feedback is something to read or press (Undo), so hovering it doesn't
        // turn the notch into Peek under the pointer.
        next.settings = NotchMachine.Settings(opensOnHover: preferences.opensOnHover && feedback == nil,
                                              previewDuration: preferences.previewDuration.rawValue)
        if let event { next.handle(event, at: .now) }
        if next.state != machine.state {
            // Only the event's name is public; shot IDs are file paths.
            let name = event.map { String(describing: $0).prefix { $0 != "(" } } ?? "feedback"
            log.debug("\(name, privacy: .public) → \(next.state.name, privacy: .public)")
        }

        let stateChanges = next.state != machine.state
        let reshapes = next.shownState != machine.shownState
        // Collapsing into the notch settles closed; anything that grows opens.
        let opening = reshapes ? next.shownState != .idle : true
        let timerChanged = next.timer != machine.timer
        withAnimation(reshapes || newFeedback != nil ? Theme.Motion.reshape(opening: opening) : nil) {
            machine = next
            if let newFeedback { feedback = newFeedback }
        }
        if let newFeedback { endFeedback(after: newFeedback.duration) }
        if timerChanged { schedule(next.timer) }
        if stateChanges {
            // The selection belongs to the Shelf, and leaves with it.
            if next.state != .shelf { selection = [] }
            updateKeyboard()
        }
        if reshapes {
            if next.shownState == .idle {
                focusedShot = nil
                pointerAtKeyboardFocus = nil
                goHomeWhenSettled()
            }
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
            goHomeWhenSettled()
        }
    }

    // MARK: Pointer

    /// The pointer is tracked as geometry, against the notch's current shape.
    /// Hover uses the hover zone. The panel takes the mouse exactly while the
    /// pointer is on the shape and lets it pass through everywhere else, so a
    /// click always lands where the user sees it. macOS's own pass-through of
    /// transparent pixels goes stale when content appears without the pointer
    /// on it, as a Preview does; see Platform facts.
    private func pointerMoved(to point: CGPoint) {
        guard let geometry else { return }
        let onShape = NotchLayout.shapeRect(for: frame, geometry: geometry).contains(point)
        if panel.ignoresMouseEvents == onShape { panel.ignoresMouseEvents = !onShape }
        let inside = NotchLayout.hoverZone(for: frame, state: shownState, geometry: geometry).contains(point)
        if inside != machine.pointerInside { send(inside ? .pointerEntered : .pointerExited) }
    }

    /// Re-checks the pointer without it moving, for when the notch changes shape
    /// under it.
    private func syncPointer() { pointerMoved(to: NSEvent.mouseLocation) }

    /// With "Show on: With mouse", a resting notch follows the pointer to its display.
    private func followPointer(to point: CGPoint) {
        guard preferences.notchDisplay == .withMouse, isResting,
              let target = Self.screen(containing: point), target.displayID != screen?.displayID else { return }
        place(on: target)
    }

    private func watchPointer() {
        // The event's own location, not NSEvent.mouseLocation: when the pointer
        // jumps, the monitor can run before the current location catches up.
        let moved = NSEvent.addGlobalMonitorForEvents(matching: .mouseMoved) { [weak self] event in
            let point = Self.screenLocation(of: event)
            MainActor.assumeIsolated {
                self?.followPointer(to: point)
                self?.pointerMoved(to: point)
            }
        }
        let clicked = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            MainActor.assumeIsolated { self?.send(.clickedOutside) }
        }
        // Ahead of the app's menus, which would otherwise take ⌘C and ⌘Z.
        let keys = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            let handled = MainActor.assumeIsolated { self?.handleKey(event) ?? false }
            return handled ? nil : event
        }
        monitors = [moved, clicked, keys].compactMap { $0 }

        // macOS only sends pointer moves to the active app, so the monitor misses
        // moves over other apps' windows. Sampling the position guarantees none
        // is missed: often while the notch is open, rarely at rest.
        // ponytail: sampling; an event tap would be event-driven, but needs Input Monitoring.
        pointerTask = Task { [weak self] in
            var last: CGPoint?
            while !Task.isCancelled {
                guard let self else { return }
                let point = NSEvent.mouseLocation
                if point != last {
                    last = point
                    pointerMoved(to: point)
                }
                let interval = isResting ? Theme.Timing.pointerAtRest : Theme.Timing.pointerOpen
                try? await Task.sleep(for: .seconds(interval), tolerance: .seconds(interval / 4))
            }
        }
    }

    // MARK: Library

    private func watchLibrary() {
        library.onArrival = { [weak self] shot in
            Thumbnails.prefetch([shot])
            guard let self, showsPreview, !machine.isDragging, state != .shelf else { return }
            if let target = Self.screen(for: shot), target.displayID != screen?.displayID { place(on: target) }
            send(.shotArrived(shot.id))
        }
        // A shot that disappears (trashed, or deleted in Finder) leaves the focus
        // and the selection, and a Preview of it closes at once.
        Task { [weak self] in
            for await ids in Observations({ [weak self] in Set(self?.library.shots.map(\.id) ?? []) }) {
                guard let self else { return }
                if let focusedShot, !ids.contains(focusedShot) { self.focusedShot = nil }
                if !selection.isSubset(of: ids) { selection.formIntersection(ids) }
                if case .preview(let id) = state, !ids.contains(id) { send(.shotRemoved(id)) }
            }
        }
    }

    // MARK: Displays

    private func watchScreens() {
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didChangeScreenParametersNotification) {
                self?.goHome()
            }
        }
    }

    /// Idle with nothing to show: the only time the notch may change display, so
    /// it never jumps while the user is looking at it.
    private var isResting: Bool {
        shownState == .idle && feedback == nil && !machine.isDragging
    }

    /// The display the notch lives on, from "Show on".
    private var home: NSScreen? {
        switch preferences.notchDisplay {
        case .builtIn: NSScreen.screens.first(where: \.isBuiltIn) ?? NSScreen.screens.first
        case .main: NSScreen.screens.first
        case .withMouse: Self.screen(containing: NSEvent.mouseLocation) ?? NSScreen.screens.first
        }
    }

    private func goHome() {
        if let home { place(on: home) }
    }

    /// Back home once a Preview elsewhere has closed and its feedback is gone.
    private func goHomeWhenSettled() {
        homeTask?.cancel()
        homeTask = Task { [weak self] in
            // Let the closing spring finish where the user saw it.
            try? await Task.sleep(for: .seconds(Theme.Timing.settle))
            guard let self, !Task.isCancelled, isResting, let home, home.displayID != screen?.displayID else { return }
            place(on: home)
        }
    }

    /// Puts the panel on a display, centered on its notch, or on the pill where
    /// it has none.
    private func place(on screen: NSScreen) {
        let geometry = NotchGeometry(screen: screen)
        let canvas = Theme.Notch.canvas
        panel.setFrame(CGRect(x: geometry.frame.midX - canvas.width / 2,
                              y: screen.frame.maxY - canvas.height,
                              width: canvas.width,
                              height: canvas.height),
                       display: true)
        self.screen = screen
        self.geometry = geometry
        panel.orderFrontRegardless()
    }

    /// The display a shot was taken on: where its selection was, or, for a
    /// whole-display capture, where the pointer is.
    private static func screen(for shot: Shot) -> NSScreen? {
        guard let rect = shot.captureRect, let primary = NSScreen.screens.first else {
            return screen(containing: NSEvent.mouseLocation)
        }
        // The rect is in global display coordinates, which run top-down from the
        // primary display's top-left; screens are laid out bottom-up.
        let center = CGPoint(x: rect.midX, y: primary.frame.maxY - rect.midY)
        return screen(containing: center) ?? screen(containing: NSEvent.mouseLocation)
    }

    /// Where a monitored event happened, in screen coordinates. Not its
    /// `locationInWindow`: a global event can still name one of Pluck's windows,
    /// and then that is in the window's coordinates. The Quartz event's location
    /// is always global, measured down from the top of the primary display.
    private static func screenLocation(of event: NSEvent) -> CGPoint {
        guard let point = event.cgEvent?.location, let primary = NSScreen.screens.first else { return NSEvent.mouseLocation }
        return CGPoint(x: point.x, y: primary.frame.maxY - point.y)
    }

    private static func screen(containing point: CGPoint) -> NSScreen? {
        NSScreen.screens.first { NSMouseInRect(point, $0.frame, false) }
    }
}

private extension NotchState {
    /// The state without its shot, safe to log.
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
