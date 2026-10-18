import AppKit
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "app.pluck.Pluck", category: "ShotLibrary")

/// The screenshots Pluck manages, and what it remembers about them. Shots come
/// from the screenshot folder, which stays the source of truth; pins and
/// drag-outs live in the index. This is the one owner of both, and every action
/// on a shot goes through it.
@Observable final class ShotLibrary {
    /// Every screenshot in the folder, newest first.
    private(set) var shots: [Shot] = []

    /// Saved to disk on every change.
    private(set) var index: ShotIndex {
        didSet { if index != oldValue { saveIndex() } }
    }

    /// The last batch the user trashed, until it's put back or replaced.
    private(set) var lastTrashed: [Trashed] = []

    /// Called for each fresh screenshot that lands while Pluck is running.
    @ObservationIgnored var onArrival: ((Shot) -> Void)?

    @ObservationIgnored let folder: URL
    @ObservationIgnored private let indexURL: URL
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let moveToTrash: (URL) throws -> URL
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var watcher: FolderWatcher?
    /// Names already checked and found not to be screenshots, so a busy Desktop
    /// isn't re-read on every change.
    @ObservationIgnored private var ignored: Set<String> = []

    /// A file counts as a new arrival, rather than an old file moved in, if it was
    /// captured this recently.
    static let arrivalWindow: TimeInterval = 60

    struct Trashed {
        let shot: Shot
        let trashURL: URL
        let entry: ShotIndex.Entry
    }

    init(folder: URL,
         preferences: Preferences,
         indexURL: URL = ShotIndex.defaultURL,
         now: @escaping () -> Date = Date.init,
         moveToTrash: @escaping (URL) throws -> URL = moveToSystemTrash,
         pasteboard: NSPasteboard = .general) {
        self.folder = folder.standardizedFileURL
        self.preferences = preferences
        self.indexURL = indexURL
        self.now = now
        self.moveToTrash = moveToTrash
        self.pasteboard = pasteboard

        let saved = ShotIndex.load(from: indexURL)
        var index = saved
        index.prune { FileManager.default.fileExists(atPath: $0) }
        if index.managedSince == nil { index.managedSince = now() }
        self.index = index
        if index != saved { saveIndex() }
    }

    /// Reads the folder, then keeps up with it and runs cleanup for as long as
    /// Pluck is open.
    func start() {
        reconcile(announcing: false)
        watcher = FolderWatcher(folder: folder) { [weak self] in self?.reconcile() }
        if watcher == nil { log.error("Can't watch \(self.folder.path(percentEncoded: false))") }
        Task { [weak self] in
            repeat {
                self?.cleanUp()
                try? await Task.sleep(for: Cleanup.interval)
            } while self != nil
        }
    }

    // MARK: - Reading

    var pinnedShots: [Shot] {
        index.pinned.compactMap { id in shots.first { $0.id == id } }
    }

    func isPinned(_ id: Shot.ID) -> Bool { index.pinned.contains(id) }

    /// The shots with these IDs, in library order (newest first).
    func shots(withIDs ids: [Shot.ID]) -> [Shot] {
        let wanted = Set(ids)
        return shots.filter { wanted.contains($0.id) }
    }

    /// Brings `shots` in line with the folder. New screenshots are added, and
    /// announced when they're fresh. A shot renamed in Finder keeps its pin.
    /// A shot whose file is gone is forgotten. If the folder can't be read,
    /// nothing changes, so a lost permission never wipes pins.
    func reconcile(announcing: Bool = true) {
        let names: Set<String>
        do {
            names = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))
        } catch {
            log.error("Can't read the screenshot folder: \(error)")
            return
        }

        var index = self.index
        var current = shots.filter { names.contains($0.url.lastPathComponent) }
        var gone = shots.filter { !names.contains($0.url.lastPathComponent) }
        let known = Set(current.map(\.url.lastPathComponent))
        var arrivals: [Shot] = []

        for name in names.subtracting(known).subtracting(ignored).sorted() where !name.hasPrefix(".") {
            guard let shot = Shot(screenshotAt: folder.appending(path: name)) else {
                ignored.insert(name)
                continue
            }
            current.append(shot)
            if let renamed = gone.first(where: { $0.fileID != nil && $0.fileID == shot.fileID }) {
                index.rename(renamed.id, to: shot.id)
                gone.removeAll { $0 == renamed }
            } else if announcing, now().timeIntervalSince(shot.capturedAt) < Self.arrivalWindow {
                arrivals.append(shot)
            }
        }
        for shot in gone { index.forget(shot.id) }
        ignored.formIntersection(names)

        current.sort(by: Shot.newestFirst)
        if current != shots {
            log.debug("Folder changed: \(current.count) shots, \(arrivals.count) new, \(gone.count) gone")
            shots = current
        }
        self.index = index
        for shot in arrivals.sorted(by: Shot.newestFirst).reversed() { onArrival?(shot) }
    }

    // MARK: - Actions

    /// Puts shots on the pasteboard as both a file and an image, so pasting works
    /// in Finder, chat apps and image editors alike.
    func copy(_ ids: [Shot.ID]) {
        let items = shots(withIDs: ids).compactMap { shot -> NSPasteboardItem? in
            guard let data = try? Data(contentsOf: shot.url),
                  let type = UTType(filenameExtension: shot.url.pathExtension) else { return nil }
            let item = NSPasteboardItem()
            item.setString(shot.url.absoluteString, forType: .fileURL)
            item.setData(data, forType: NSPasteboard.PasteboardType(type.identifier))
            return item
        }
        guard !items.isEmpty else { return }
        pasteboard.clearContents()
        pasteboard.writeObjects(items)
    }

    /// Pins the shots, or unpins them if they're all pinned already. Newly pinned
    /// shots go to the front.
    func togglePin(_ ids: [Shot.ID]) {
        var index = self.index
        if ids.allSatisfy(index.pinned.contains) {
            index.pinned.removeAll(where: ids.contains)
            for id in ids { index.unpinned[id] = now() }
        } else {
            let newPins = ids.filter { !index.pinned.contains($0) }
            index.pinned = newPins + index.pinned
            for id in newPins {
                index.draggedOut[id] = nil
                index.unpinned[id] = nil
            }
        }
        self.index = index
    }

    /// Records a drag into another app. Unless the user turned it off, cleanup
    /// removes the shot an hour later. Pinned shots are exempt.
    func recordDragOut(_ ids: [Shot.ID]) {
        var index = self.index
        for id in ids where !index.pinned.contains(id) { index.draggedOut[id] = now() }
        self.index = index
    }

    /// Moves shots to the Trash. The batch can be put back with `undoTrash()`
    /// until the next trash.
    func trash(_ ids: [Shot.ID]) {
        lastTrashed = discard(ids)
    }

    /// Puts the last trashed batch back where it was, pins included.
    func undoTrash() {
        var index = self.index
        var restored: [Shot] = []
        // Restore pins in their original order so each lands at its old position.
        for item in lastTrashed.sorted(by: { ($0.entry.pinPosition ?? .max) < ($1.entry.pinPosition ?? .max) }) {
            do {
                try FileManager.default.moveItem(at: item.trashURL, to: item.shot.url)
            } catch {
                log.error("Couldn't put back \(item.shot.url.lastPathComponent): \(error)")
                continue
            }
            restored.append(item.shot)
            index.restore(item.entry, for: item.shot.id)
        }
        lastTrashed = []
        shots = (shots + restored).sorted(by: Shot.newestFirst)
        self.index = index
    }

    /// Moves shots into `destination` and lets go of them. A shot the user filed
    /// away is theirs now, so cleanup must never touch it.
    func move(_ ids: [Shot.ID], to destination: URL) {
        guard destination.standardizedFileURL != folder else { return }
        var index = self.index
        var moved: Set<Shot.ID> = []
        for shot in shots(withIDs: ids) {
            do {
                try FileManager.default.moveItem(at: shot.url, to: availableURL(for: shot.url.lastPathComponent, in: destination))
            } catch {
                log.error("Couldn't move \(shot.url.lastPathComponent): \(error)")
                continue
            }
            moved.insert(shot.id)
            index.forget(shot.id)
        }
        shots.removeAll { moved.contains($0.id) }
        self.index = index
    }

    /// A copy of the shot outside the folder, for a drag off the Preview. Like
    /// macOS's own thumbnail, the Preview doesn't keep a shot dragged off it: the
    /// drop gets the copy, which outlives it (a path dropped in a terminal still
    /// works), and `letGo` removes the original. APFS clones it, so it's free.
    func dragCopy(of id: Shot.ID) -> URL? {
        guard let shot = shots(withIDs: [id]).first else { return nil }
        let folder = URL.temporaryDirectory.appending(path: "Pluck/\(UUID().uuidString)")
        let copy = folder.appending(path: shot.url.lastPathComponent)
        do {
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try FileManager.default.copyItem(at: shot.url, to: copy)
            return copy
        } catch {
            log.error("Couldn't copy \(shot.url.lastPathComponent) for a drag: \(error)")
            return nil
        }
    }

    /// Removes a shot whose copy went out with a drag. Not to the Trash: the drop
    /// has it.
    func letGo(_ id: Shot.ID) {
        guard let shot = shots(withIDs: [id]).first else { return }
        do {
            try FileManager.default.removeItem(at: shot.url)
        } catch {
            log.error("Couldn't remove \(shot.url.lastPathComponent): \(error)")
            return
        }
        var index = self.index
        index.forget(id)
        self.index = index
        shots.removeAll { $0.id == id }
    }

    func revealInFinder(_ ids: [Shot.ID]) {
        NSWorkspace.shared.activateFileViewerSelecting(shots(withIDs: ids).map(\.url))
    }

    /// Markup: Pluck has no editor of its own, so the shot opens in Preview.
    func openInPreview(_ id: Shot.ID) {
        guard let shot = shots(withIDs: [id]).first,
              let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else { return }
        NSWorkspace.shared.open([shot.url], withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Trashes whatever `Cleanup.expired` says has expired. It never replaces the
    /// user's own undo.
    func cleanUp() {
        let expired = Cleanup.expired(shots, index: index, retention: preferences.retention,
                                      removeDraggedOut: preferences.removeDraggedOut, now: now())
        // Check the tag again right before trashing, in case the file was swapped.
        let ids = expired.filter { Shot.isScreenshot($0.url) }.map(\.id)
        if !ids.isEmpty { _ = discard(ids) }
    }

    // MARK: - Private

    /// Moves shots to the Trash and forgets them, returning what's needed to put
    /// them back.
    private func discard(_ ids: [Shot.ID]) -> [Trashed] {
        var index = self.index
        var trashed: [Trashed] = []
        for shot in shots(withIDs: ids) {
            do {
                trashed.append(Trashed(shot: shot, trashURL: try moveToTrash(shot.url), entry: index.entry(for: shot.id)))
            } catch {
                log.error("Couldn't trash \(shot.url.lastPathComponent): \(error)")
            }
        }
        let gone = Set(trashed.map(\.shot.id))
        for id in gone { index.forget(id) }
        shots.removeAll { gone.contains($0.id) }
        self.index = index
        return trashed
    }

    private func saveIndex() {
        do { try index.save(to: indexURL) } catch { log.error("Couldn't save the index: \(error)") }
    }
}

/// The real Trash, so Finder's Put Back works.
nonisolated func moveToSystemTrash(_ url: URL) throws -> URL {
    var result: NSURL?
    try FileManager.default.trashItem(at: url, resultingItemURL: &result)
    guard let result else { throw CocoaError(.fileNoSuchFile) }
    return result as URL
}

/// `name` in `folder`, or "name 2", "name 3" and so on if it's taken, as Finder does.
func availableURL(for name: String, in folder: URL) -> URL {
    let base = (name as NSString).deletingPathExtension
    let ext = (name as NSString).pathExtension
    var candidate = folder.appending(path: name)
    var n = 2
    while FileManager.default.fileExists(atPath: candidate.path(percentEncoded: false)) {
        candidate = folder.appending(path: ext.isEmpty ? "\(base) \(n)" : "\(base) \(n).\(ext)")
        n += 1
    }
    return candidate
}
