import AppKit
import OSLog
import UniformTypeIdentifiers

private let log = Logger(subsystem: "dev.awln.pluck", category: "ShotLibrary")

/// The screenshots Pluck manages, and what it remembers about them: the one owner
/// of every shot file, and every action on a shot goes through it.
///
/// A capture lands in `incoming` first and waits there, pending, while its Preview
/// shows, as macOS holds one behind its thumbnail. Once the Preview is done with it,
/// it's saved into `folder`, which stays the source of truth. A drag hands a shot
/// off instead: its file goes to the drop by way of `handedOff`, and it leaves.
@Observable final class ShotLibrary {
    /// Every screenshot in the folder, newest first.
    private(set) var shots: [Shot] = []
    /// Captures waiting for their Preview, newest first.
    private(set) var pending: [Shot] = []

    /// Saved to disk on every change.
    private(set) var index: ShotIndex {
        didSet { if index != oldValue { saveIndex() } }
    }

    /// The last batch the user trashed, until it's put back or replaced.
    private(set) var lastTrashed: [Trashed] = []

    private(set) var folder: URL
    /// Whether macOS lets Pluck read the folder: nil until Pluck has looked,
    /// false when the user denied access.
    private(set) var canReadFolder: Bool?
    @ObservationIgnored let incoming: URL
    /// Files drags carried into apps, kept an hour so the app that took one can
    /// read it (a path dropped in a terminal, say).
    @ObservationIgnored let handedOff: URL
    /// Shots a drag is carrying, and where their files are meanwhile. They stay
    /// listed until it ends, so nothing changes under the drag.
    @ObservationIgnored private var inFlight: [Shot.ID: URL] = [:]
    @ObservationIgnored private let indexURL: URL
    @ObservationIgnored private let preferences: Preferences
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private let moveToTrash: (URL) throws -> URL
    @ObservationIgnored private let pasteboard: NSPasteboard
    @ObservationIgnored private var watchers: [FolderWatcher] = []
    @ObservationIgnored private var started = false
    /// Names already checked and found not to be screenshots, so a busy Desktop
    /// isn't re-read on every change.
    @ObservationIgnored private var ignored: Set<String> = []

    /// Where macOS saves captures while Pluck's Preview is on. ⇧⌘5's Options show
    /// it by name, so it's called "Pluck".
    static let holdingFolder = URL.applicationSupportDirectory.appending(path: "Pluck/Pluck")

    struct Trashed {
        let shot: Shot
        let trashURL: URL
        let entry: ShotIndex.Entry
    }

    init(folder: URL,
         preferences: Preferences,
         incoming: URL = ShotLibrary.holdingFolder,
         handedOff: URL = URL.temporaryDirectory.appending(path: "Pluck"),
         indexURL: URL = ShotIndex.defaultURL,
         now: @escaping () -> Date = Date.init,
         moveToTrash: @escaping (URL) throws -> URL = moveToSystemTrash,
         pasteboard: NSPasteboard = .general) {
        self.folder = folder.standardizedFileURL
        self.incoming = incoming
        self.handedOff = handedOff
        self.preferences = preferences
        self.indexURL = indexURL
        self.now = now
        self.moveToTrash = moveToTrash
        self.pasteboard = pasteboard
        try? FileManager.default.createDirectory(at: incoming, withIntermediateDirectories: true)

        let saved = ShotIndex.load(from: indexURL)
        var index = saved
        index.prune { FileManager.default.fileExists(atPath: $0) }
        if index.managedSince == nil { index.managedSince = now() }
        self.index = index
        if index != saved { saveIndex() }
    }

    /// Reads the folders, then keeps up with them and runs cleanup for as long as
    /// Pluck is open. Captures an earlier run left waiting (a crash, say) are saved.
    /// Pluck doesn't look in the folder before this, so the macOS access prompt
    /// comes when onboarding says it will. Only the first call does anything.
    func start() {
        guard !started else { return }
        started = true
        reconcile()
        reconcilePending()
        savePending()
        watch()
        Task { [weak self] in
            repeat {
                self?.cleanUp()
                try? await Task.sleep(for: Cleanup.interval)
            } while self != nil
        }
        // Access allowed in System Settings counts once the user is back in Pluck.
        Task { [weak self] in
            for await _ in NotificationCenter.default.notifications(named: NSApplication.didBecomeActiveNotification) {
                guard let self, canReadFolder == false else { continue }
                reconcile()
                watch()
            }
        }
    }

    /// Asks macOS for the folder, then starts. The first read of a protected folder
    /// shows the access prompt and blocks the thread that asked until it's
    /// answered, so it's asked off the main thread and Pluck stays responsive.
    func requestAccess() async {
        let path = folder.path(percentEncoded: false)
        _ = await Task.detached { try? FileManager.default.contentsOfDirectory(atPath: path) }.value
        start()
    }

    /// Shelves another folder's screenshots. What the index knows about the old
    /// folder's shots is kept, so switching back brings back their pins.
    func change(folder newFolder: URL) {
        let newFolder = newFolder.standardizedFileURL
        guard newFolder != folder else { return }
        folder = newFolder
        shots = []
        ignored = []
        canReadFolder = nil
        guard started else { return }
        reconcile()
        watch()
    }

    private func watch() {
        watchers = [folder, incoming].compactMap { folder in
            let watcher = FolderWatcher(folder: folder) { [weak self] in
                folder == self?.incoming ? self?.reconcilePending() : self?.reconcile()
            }
            if watcher == nil { log.error("Can't watch \(folder.path(percentEncoded: false))") }
            return watcher
        }
    }

    // MARK: - Reading

    var pinnedShots: [Shot] {
        index.pinned.compactMap { id in shots.first { $0.id == id } }
    }

    func isPinned(_ id: Shot.ID) -> Bool { index.pinned.contains(id) }

    func isPending(_ id: Shot.ID) -> Bool { pending.contains { $0.id == id } }

    /// A shot, saved or waiting.
    func shot(_ id: Shot.ID) -> Shot? {
        pending.first { $0.id == id } ?? shots.first { $0.id == id }
    }

    /// The saved shots with these IDs, in library order (newest first).
    func shots(withIDs ids: [Shot.ID]) -> [Shot] {
        let wanted = Set(ids)
        return shots.filter { wanted.contains($0.id) }
    }

    /// Brings `shots` in line with the folder. A shot renamed in Finder keeps its
    /// pin; one whose file is gone is forgotten. If the folder can't be read,
    /// nothing changes, so a lost permission never wipes pins.
    func reconcile() {
        let names: Set<String>
        do {
            names = Set(try FileManager.default.contentsOfDirectory(atPath: folder.path(percentEncoded: false)))
        } catch {
            log.error("Can't read the screenshot folder: \(error)")
            if canReadFolder != false { canReadFolder = false }
            return
        }
        if canReadFolder != true { canReadFolder = true }

        var index = self.index
        var current = shots.filter { names.contains($0.url.lastPathComponent) || inFlight[$0.id] != nil }
        var gone = shots.filter { !names.contains($0.url.lastPathComponent) && inFlight[$0.id] == nil }
        let known = Set(current.map(\.url.lastPathComponent))

        for name in names.subtracting(known).subtracting(ignored).sorted() where !name.hasPrefix(".") {
            guard let shot = Shot(screenshotAt: folder.appending(path: name)) else {
                ignored.insert(name)
                continue
            }
            current.append(shot)
            if let renamed = gone.first(where: { $0.fileID != nil && $0.fileID == shot.fileID }) {
                index.rename(renamed.id, to: shot.id)
                gone.removeAll { $0 == renamed }
            }
        }
        for shot in gone { index.forget(shot.id) }
        ignored.formIntersection(names)

        current.sort(by: Shot.newestFirst)
        if current != shots {
            log.debug("Folder changed: \(current.count) shots, \(gone.count) gone")
            shots = current
        }
        self.index = index
    }

    /// Brings `pending` in line with the holding folder. Anything else macOS saves
    /// there, a screen recording say, goes straight on to the folder.
    func reconcilePending() {
        guard let names = try? FileManager.default.contentsOfDirectory(atPath: incoming.path(percentEncoded: false)) else { return }
        var current = pending.filter { inFlight[$0.id] != nil }
        for name in names where !name.hasPrefix(".") {
            let url = incoming.appending(path: name)
            if let shot = pending.first(where: { $0.url == url }) ?? Shot(screenshotAt: url) {
                current.append(shot)
            } else {
                try? FileManager.default.moveItem(at: url, to: availableURL(for: name, in: folder))
            }
        }
        current.sort(by: Shot.newestFirst)
        if current != pending { pending = current }
    }

    // MARK: - Actions

    /// Saves waiting captures into the folder; shots already there pass through.
    /// Returns where each one is now.
    @discardableResult
    func save(_ ids: [Shot.ID]) -> [Shot.ID] {
        if ids.contains(where: isPending) { makeFolderIfGone() }
        return ids.map { id in
            guard let shot = pending.first(where: { $0.id == id }) else { return id }
            let destination = availableURL(for: shot.url.lastPathComponent, in: folder)
            do {
                try FileManager.default.moveItem(at: shot.url, to: destination)
            } catch {
                log.error("Couldn't save \(shot.url.lastPathComponent): \(error)")
                return id
            }
            let saved = shot.at(destination)
            pending.removeAll { $0.id == id }
            shots = (shots + [saved]).sorted(by: Shot.newestFirst)
            return saved.id
        }
    }

    func savePending() {
        save(pending.map(\.id))
    }

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
            for id in newPins { index.unpinned[id] = nil }
        }
        self.index = index
    }

    /// Moves shots to the Trash, waiting captures straight from the holding folder.
    /// The batch can be put back with `undoTrash()` until the next trash.
    func trash(_ ids: [Shot.ID]) {
        let trashed = discard(ids)
        if !trashed.isEmpty { lastTrashed = trashed }
    }

    /// Puts the last trashed batch back where it was, pins included.
    func undoTrash() {
        var index = self.index
        var restored: [Shot] = []
        // Restore pins in their original order so each lands at its old position.
        for item in lastTrashed.sorted(by: { ($0.entry.pinPosition ?? .max) < ($1.entry.pinPosition ?? .max) }) {
            let shot = item.shot.at(availableURL(for: item.shot.url.lastPathComponent, in: item.shot.url.deletingLastPathComponent()))
            do {
                try FileManager.default.moveItem(at: item.trashURL, to: shot.url)
            } catch {
                log.error("Couldn't put back \(shot.url.lastPathComponent): \(error)")
                continue
            }
            restored.append(shot)
            index.restore(item.entry, for: shot.id)
        }
        lastTrashed = []
        shots = (shots + restored).sorted(by: Shot.newestFirst)
        self.index = index
    }

    /// Moves shots' files into the hand-off folder for a drag to carry, returning
    /// where each one is now.
    // ponytail: a crash mid-drag strands the file there, and cleanup deletes it an hour on; record flights on disk if that ever shows up.
    func handOff(_ ids: [Shot.ID]) -> [Shot.ID: URL] {
        var carried: [Shot.ID: URL] = [:]
        for shot in anywhere(ids) {
            let url = handedOff.appending(path: UUID().uuidString).appending(path: shot.url.lastPathComponent)
            do {
                try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                try FileManager.default.moveItem(at: shot.url, to: url)
            } catch {
                log.error("Couldn't hand off \(shot.url.lastPathComponent): \(error)")
                continue
            }
            carried[shot.id] = url
        }
        inFlight.merge(carried) { $1 }
        return carried
    }

    /// The drag ended. A cancelled one puts the files back. A drop has them: the
    /// shots leave, and a file the drop left in the hand-off folder stays its hour.
    /// `keeping` are waiting captures the user keeps, saved as a copy.
    func finishHandOff(dropped: Bool, keeping: Set<Shot.ID>) {
        let flights = inFlight
        inFlight = [:]
        for (id, url) in flights {
            guard let home = shot(id)?.url else { continue }
            if !dropped {
                try? FileManager.default.moveItem(at: url, to: availableURL(for: home.lastPathComponent, in: home.deletingLastPathComponent()))
                try? FileManager.default.removeItem(at: url.deletingLastPathComponent())
            } else if keeping.contains(id) {
                try? FileManager.default.copyItem(at: url, to: availableURL(for: home.lastPathComponent, in: folder))
            }
        }
        reconcile()
        reconcilePending()
    }

    func revealInFinder(_ ids: [Shot.ID]) {
        NSWorkspace.shared.activateFileViewerSelecting(shots(withIDs: ids).map(\.url))
    }

    /// Pluck has no viewer or editor of its own: shots open in Preview, Markup
    /// and all, several at once in one window.
    func openInPreview(_ ids: [Shot.ID]) {
        guard let preview = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.Preview") else { return }
        NSWorkspace.shared.open(shots(withIDs: ids).map(\.url), withApplicationAt: preview, configuration: NSWorkspace.OpenConfiguration())
    }

    /// Trashes whatever `Cleanup.expired` says has expired, and deletes what drags
    /// left in the hand-off folder an hour ago. It never replaces the user's own undo.
    func cleanUp() {
        let expired = Cleanup.expired(shots, index: index, retention: preferences.retention, now: now())
        // Check the tag again right before trashing, in case the file was swapped.
        let ids = expired.filter { Shot.isScreenshot($0.url) }.map(\.id)
        if !ids.isEmpty { _ = discard(ids) }

        let left = (try? FileManager.default.contentsOfDirectory(at: handedOff, includingPropertiesForKeys: [.creationDateKey])) ?? []
        for folder in left {
            let made = (try? folder.resourceValues(forKeys: [.creationDateKey]).creationDate) ?? .distantPast
            if now().timeIntervalSince(made) >= Cleanup.handOffGrace { try? FileManager.default.removeItem(at: folder) }
        }
    }

    // MARK: - Private

    /// Moves shots to the Trash and forgets them, returning what's needed to put
    /// them back.
    private func discard(_ ids: [Shot.ID]) -> [Trashed] {
        var index = self.index
        var trashed: [Trashed] = []
        var gone: Set<Shot.ID> = []
        for shot in anywhere(ids) {
            do {
                let trashURL = try moveToTrash(shot.url)
                // Undo puts a capture that was still waiting into the folder, saved.
                let home = isPending(shot.id) ? shot.at(folder.appending(path: shot.url.lastPathComponent)) : shot
                trashed.append(Trashed(shot: home, trashURL: trashURL, entry: index.entry(for: shot.id)))
                gone.insert(shot.id)
            } catch {
                log.error("Couldn't trash \(shot.url.lastPathComponent): \(error)")
            }
        }
        for id in gone { index.forget(id) }
        shots.removeAll { gone.contains($0.id) }
        pending.removeAll { gone.contains($0.id) }
        self.index = index
        return trashed
    }

    /// A folder deleted since is still where the user wants screenshots.
    // ponytail: one on a disk that's been ejected can't be made, so captures wait until it's back or Pluck restarts, when "Save to" falls back to the Desktop.
    private func makeFolderIfGone() {
        guard !FileManager.default.fileExists(atPath: folder.path(percentEncoded: false)) else { return }
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        if started { watch() }
    }

    /// Saved shots and waiting captures with these IDs.
    private func anywhere(_ ids: [Shot.ID]) -> [Shot] {
        let wanted = Set(ids)
        return (pending + shots).filter { wanted.contains($0.id) }
    }

    private func saveIndex() {
        do { try index.save(to: indexURL) } catch { log.error("Couldn't save the index: \(error)") }
    }
}

private extension Shot {
    /// The same shot, its file now at `url`.
    func at(_ url: URL) -> Shot {
        Shot(url: url, capturedAt: capturedAt, pixelSize: pixelSize, fileID: fileID)
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
