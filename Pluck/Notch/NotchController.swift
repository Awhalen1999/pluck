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
    /// The shot under the pointer, for the header's detail line.
    private(set) var hoveredShot: Shot.ID?
    /// The shots in the drag under way, shown faded where they came from.
    private(set) var draggedShots: Set<Shot.ID> = []
    private var machine = NotchMachine()

    @ObservationIgnored private var panel: NotchPanel!
    @ObservationIgnored private var timerTask: Task<Void, Never>?
    @ObservationIgnored private var feedbackTask: Task<Void, Never>?
    @ObservationIgnored private var monitors: [Any] = []
    @ObservationIgnored private let dragSource = ShotDragSource()
    @ObservationIgnored private let quickLookPanel = QuickLook()
    /// The views drawing each shot right now, so Quick Look can zoom from them.
    @ObservationIgnored private let shotViews = NSMapTable<NSString, NSView>.strongToWeakObjects()

    init(library: ShotLibrary, preferences: Preferences, showsPreview: Bool) {
        self.library = library
        self.preferences = preferences
        self.showsPreview = showsPreview
        panel = NotchPanel(rootView: NotchView(controller: self))
        place()
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
        NotchLayout.frame(for: shownState, content: content, notch: geometry?.frame.size ?? Theme.Notch.referenceSize)
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

    func clicked(_ id: Shot.ID, modifiers: NSEvent.ModifierFlags) {
        copy([id])
    }

    func copy(_ ids: [Shot.ID]) {
        library.copy(ids)
        send(.finished, feedback: Feedback(kind: .copied, count: ids.count))
    }

    func togglePin(_ ids: [Shot.ID]) {
        let pinning = !ids.allSatisfy(library.isPinned)
        library.togglePin(ids)
        send(.finished, feedback: Feedback(kind: pinning ? .pinned : .unpinned, count: ids.count))
    }

    func trash(_ ids: [Shot.ID]) {
        library.trash(ids)
        send(.finished, feedback: Feedback(kind: .trashed, count: ids.count))
    }

    func move(_ ids: [Shot.ID], to folder: URL) {
        library.move(ids, to: folder)
        send(.finished, feedback: Feedback(kind: .moved, count: ids.count))
    }

    func markup(_ id: Shot.ID) {
        library.openInPreview(id)
        send(.finished)
    }

    func undoTrash() {
        library.undoTrash()
        send(nil, feedback: Feedback(kind: .restored))
    }

    /// Opens Quick Look on a shot, with every shot a keypress away. From the
    /// Preview it counts as acting on it, so the Preview finishes.
    func quickLook(_ id: Shot.ID) {
        let shots = library.shots
        guard let index = shots.firstIndex(where: { $0.id == id }) else {
            log.error("Quick Look: no such shot")
            return
        }
        quickLookPanel.show(shots, startingAt: index)
        if case .preview = state { send(.finished) }
    }

    func hover(_ id: Shot.ID, _ inside: Bool) {
        if inside { hoveredShot = id } else if hoveredShot == id { hoveredShot = nil }
    }

    func register(_ view: NSView, for id: Shot.ID) {
        shotViews.setObject(view, forKey: id as NSString)
    }

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
        let shots = library.shots(withIDs: [id])
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
        draggedShots = Set(shots.map(\.id))
        let session = view.beginDraggingSession(with: items, event: event, source: dragSource)
        session.draggingFormation = items.count > 1 ? .stack : .none
        send(.dragStarted)
    }

    private func watchDrags() {
        dragSource.moved = { [weak self] point in self?.pointerMoved(to: point) }
        dragSource.ended = { [weak self] dropped in
            guard let self else { return }
            if dropped, preferences.removeDraggedOut { library.recordDragOut(Array(draggedShots)) }
            draggedShots = []
            send(.dragEnded(dropped: dropped))
        }
    }

    // MARK: Menu

    /// The right-click menu for a shot: native, with the shortcuts shown.
    func menu(for id: Shot.ID) -> NSMenu {
        let ids = [id]
        let menu = NSMenu()
        menu.addItem(menuItem("Copy", key: "c") { [weak self] in self?.copy(ids) })
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
        NSApp.activate()
        if open.runModal() == .OK, let folder = open.url { move(ids, to: folder) }
        returnFocus()
    }

    // MARK: Focus

    private func watchQuickLook() {
        quickLookPanel.sourceFrame = { [weak self] id in
            guard let view = self?.shotViews.object(forKey: id as NSString), let window = view.window else { return nil }
            return window.convertToScreen(view.convert(view.bounds, to: nil))
        }
        quickLookPanel.onClose = { [weak self] in self?.returnFocus() }
    }

    /// Gives the keyboard back to the app the user was in, after Pluck had to
    /// come forward for Quick Look or a folder picker.
    private func returnFocus() {
        if NSApp.isActive { NSApp.hide(nil) }
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
        if next.state != machine.state {
            // Only the event's name is public; shot IDs are file paths.
            let name = event.map { String(describing: $0).prefix { $0 != "(" } } ?? "feedback"
            log.debug("\(name, privacy: .public) → \(String(describing: next.state))")
        }

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
        if reshapes {
            if next.shownState == .idle { hoveredShot = nil }
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
        let inside = NotchLayout.hoverZone(for: frame, state: shownState, geometry: geometry).contains(point)
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
