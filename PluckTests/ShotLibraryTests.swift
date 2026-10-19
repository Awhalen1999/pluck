import AppKit
import Testing
@testable import Pluck

@Suite struct ShotLibraryTests {
    let sandbox: Sandbox
    init() throws { sandbox = try Sandbox() }

    // MARK: Picking up screenshots

    @Test func onlyTaggedImagesBecomeShots() throws {
        try sandbox.addShot("shot.png")
        try sandbox.addShot("photo.png", tagged: false)
        try sandbox.addShot(".hidden temp.png")
        let notes = sandbox.folder.appending(path: "notes.txt")
        try "hello".write(to: notes, atomically: true, encoding: .utf8)
        try sandbox.tag(notes)

        let library = sandbox.library()
        library.reconcile()

        #expect(library.names == ["shot.png"])
        #expect(library.shots.first?.pixelSize == CGSize(width: 40, height: 25))
    }

    @Test func shotsAreNewestFirst() throws {
        try sandbox.addShot("older.png", takenAt: testNow - 60)
        try sandbox.addShot("newest.png", takenAt: testNow)
        try sandbox.addShot("oldest.png", takenAt: testNow - 120)

        let library = sandbox.library()
        library.reconcile()

        #expect(library.names == ["newest.png", "older.png", "oldest.png"])
    }

    // MARK: Waiting for the Preview

    @Test func aCaptureWaitsOutsideTheFolderUntilItsSaved() throws {
        let library = sandbox.library()
        try sandbox.addShot("Screenshot.png", waiting: true)
        library.reconcilePending()
        #expect(library.pending.map(\.url.lastPathComponent) == ["Screenshot.png"])
        #expect(library.shots.isEmpty)

        let saved = library.save([sandbox.waitingPath("Screenshot.png")])

        #expect(saved == [sandbox.path("Screenshot.png")])
        #expect(library.pending.isEmpty)
        #expect(library.names == ["Screenshot.png"])
        #expect(FileManager.default.fileExists(atPath: sandbox.path("Screenshot.png")))
    }

    @Test func savingNeverOverwritesAShotAlreadyInTheFolder() throws {
        try sandbox.addShot("Screenshot.png")
        try sandbox.addShot("Screenshot.png", waiting: true)
        let library = sandbox.library()
        library.reconcile()
        library.reconcilePending()

        library.savePending()

        #expect(library.names.sorted() == ["Screenshot 2.png", "Screenshot.png"])
    }

    // MARK: Drags

    @Test func aDragCarriesTheShotsOwnFileAndNothingChangesUnderIt() throws {
        try sandbox.addShot("dragged.png")
        let library = sandbox.library()
        library.reconcile()

        let carried = try #require(library.handOff([sandbox.path("dragged.png")])[sandbox.path("dragged.png")])

        #expect(!FileManager.default.fileExists(atPath: sandbox.path("dragged.png")))
        #expect(FileManager.default.fileExists(atPath: carried.path(percentEncoded: false)))
        // The folder changing mid-drag doesn't drop it from the Shelf.
        library.reconcile()
        #expect(library.names == ["dragged.png"])
    }

    @Test func aCancelledDragPutsTheFileBack() throws {
        try sandbox.addShot("waiting.png", waiting: true)
        try sandbox.addShot("saved.png")
        let library = sandbox.library()
        library.reconcile()
        library.reconcilePending()
        _ = library.handOff([sandbox.waitingPath("waiting.png"), sandbox.path("saved.png")])

        library.finishHandOff(dropped: false, keeping: [])

        #expect(library.pending.map(\.url.lastPathComponent) == ["waiting.png"])
        #expect(library.names == ["saved.png"])
        #expect(FileManager.default.fileExists(atPath: sandbox.waitingPath("waiting.png")))
        #expect(FileManager.default.fileExists(atPath: sandbox.path("saved.png")))
    }

    @Test func aDropInAnAppHandsTheShotOffAndSavesNothing() throws {
        try sandbox.addShot("waiting.png", waiting: true)
        let library = sandbox.library()
        library.reconcilePending()
        let carried = try #require(library.handOff([sandbox.waitingPath("waiting.png")]).values.first)

        library.finishHandOff(dropped: true, keeping: [])

        #expect(library.pending.isEmpty)
        #expect(library.shots.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sandbox.path("waiting.png")))
        // The app's path still works.
        #expect(FileManager.default.fileExists(atPath: carried.path(percentEncoded: false)))
    }

    @Test func aCaptureTheUserKeepsIsSavedAsACopyOnceDropped() throws {
        try sandbox.addShot("kept.png", waiting: true)
        let library = sandbox.library()
        library.reconcilePending()
        let carried = try #require(library.handOff([sandbox.waitingPath("kept.png")]).values.first)

        library.finishHandOff(dropped: true, keeping: [sandbox.waitingPath("kept.png")])

        #expect(library.pending.isEmpty)
        #expect(library.names == ["kept.png"])
        #expect(FileManager.default.fileExists(atPath: carried.path(percentEncoded: false)))
    }

    @Test func aFileDroppedBackIntoTheFolderIsAShotAgain() throws {
        try sandbox.addShot("filed.png", waiting: true)
        let library = sandbox.library()
        library.reconcilePending()
        let carried = try #require(library.handOff([sandbox.waitingPath("filed.png")]).values.first)

        // Finder moves the carried file onto the Desktop, as the drop lands.
        try FileManager.default.moveItem(at: carried, to: sandbox.folder.appending(path: "filed.png"))
        library.finishHandOff(dropped: true, keeping: [])

        #expect(library.pending.isEmpty)
        #expect(library.names == ["filed.png"])
    }

    @Test func aTrashedCaptureNeverReachesTheFolderUntilUndoSavesIt() throws {
        try sandbox.addShot("trashed.png", waiting: true)
        let library = sandbox.library()
        library.reconcilePending()

        library.trash([sandbox.waitingPath("trashed.png")])
        #expect(library.pending.isEmpty)
        #expect(library.shots.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: sandbox.path("trashed.png")))
        #expect(FileManager.default.fileExists(atPath: sandbox.trash.appending(path: "trashed.png").path(percentEncoded: false)))

        library.undoTrash()
        #expect(library.names == ["trashed.png"])
        #expect(FileManager.default.fileExists(atPath: sandbox.path("trashed.png")))
    }

    @Test func aCaptureMovedElsewhereGoesStraightThere() throws {
        try sandbox.addShot("filed.png", waiting: true)
        let elsewhere = sandbox.root.appending(path: "Elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let library = sandbox.library()
        library.reconcilePending()

        library.move([sandbox.waitingPath("filed.png")], to: elsewhere)

        #expect(library.pending.isEmpty)
        #expect(library.shots.isEmpty)
        #expect(FileManager.default.fileExists(atPath: elsewhere.appending(path: "filed.png").path(percentEncoded: false)))
    }

    @Test func capturesLeftWaitingByAnEarlierRunAreSavedAtLaunch() throws {
        try sandbox.addShot("from a crash.png", waiting: true)
        let library = sandbox.library()

        library.start()

        #expect(library.pending.isEmpty)
        #expect(library.names == ["from a crash.png"])
    }

    @Test func anythingElseSavedToTheHoldingFolderGoesStraightOn() throws {
        let recording = sandbox.incoming.appending(path: "Screen Recording.mov")
        try Data("not an image".utf8).write(to: recording)
        let library = sandbox.library()

        library.reconcilePending()

        #expect(library.pending.isEmpty)
        #expect(FileManager.default.fileExists(atPath: sandbox.folder.appending(path: "Screen Recording.mov").path(percentEncoded: false)))
    }

    @Test func aLandingCaptureIsNoticedWithoutARefresh() async throws {
        let library = sandbox.library()
        library.start()

        try sandbox.addShot("landed.png", waiting: true)
        for _ in 0..<40 where library.pending.isEmpty { try await Task.sleep(for: .milliseconds(50)) }

        #expect(library.pending.map(\.url.lastPathComponent) == ["landed.png"])
    }

    @Test func whatADropLeftInTheHandOffFolderGoesAnHourLater() throws {
        try sandbox.addShot("sent.png")
        let library = sandbox.library()
        library.reconcile()
        let copy = try #require(library.handOff([sandbox.path("sent.png")]).values.first)
        library.finishHandOff(dropped: true, keeping: [])
        let made = copy.deletingLastPathComponent()
        try FileManager.default.setAttributes([.creationDate: testNow], ofItemAtPath: made.path(percentEncoded: false))

        sandbox.now = testNow + 59 * 60
        library.cleanUp()
        #expect(FileManager.default.fileExists(atPath: copy.path(percentEncoded: false)))

        sandbox.now = testNow + 60 * 60
        library.cleanUp()
        #expect(!FileManager.default.fileExists(atPath: made.path(percentEncoded: false)))
    }

    @Test func unreadableFolderChangesNothing() throws {
        try sandbox.addShot("a.png")
        let library = sandbox.library()
        library.reconcile()
        library.togglePin([sandbox.path("a.png")])

        let folder = sandbox.folder.path(percentEncoded: false)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: folder)
        defer { try? FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: folder) }
        library.reconcile()

        #expect(library.names == ["a.png"])
        #expect(library.pinnedNames == ["a.png"])
        #expect(library.canReadFolder == false)
    }

    @Test func switchingFoldersAndBackKeepsThePins() throws {
        try sandbox.addShot("pinned.png")
        let elsewhere = sandbox.root.appending(path: "Elsewhere")
        try FileManager.default.createDirectory(at: elsewhere, withIntermediateDirectories: true)
        let library = sandbox.library()
        library.start()
        library.togglePin([sandbox.path("pinned.png")])

        library.change(folder: elsewhere)
        #expect(library.shots.isEmpty)
        #expect(library.pinnedShots.isEmpty)

        library.change(folder: sandbox.folder)
        #expect(library.pinnedNames == ["pinned.png"])
    }

    @Test func nothingInTheFolderIsReadUntilPluckStarts() throws {
        try sandbox.addShot("a.png")
        let library = sandbox.library()
        library.change(folder: sandbox.root.appending(path: "Elsewhere"))
        library.change(folder: sandbox.folder)
        #expect(library.canReadFolder == nil)
        #expect(library.shots.isEmpty)

        library.start()
        #expect(library.canReadFolder == true)
        #expect(library.names == ["a.png"])
    }

    // MARK: Pins

    @Test func pinsKeepTheirOrderAcrossLaunches() throws {
        try sandbox.addShot("a.png", takenAt: testNow - 2)
        try sandbox.addShot("b.png", takenAt: testNow - 1)
        let first = sandbox.library()
        first.reconcile()
        first.togglePin([sandbox.path("a.png")])
        first.togglePin([sandbox.path("b.png")])

        let relaunched = sandbox.library()
        relaunched.reconcile()

        #expect(relaunched.pinnedNames == ["b.png", "a.png"])
    }

    @Test func togglingPinsAShotsSelectionUnlessAllArePinned() throws {
        try sandbox.addShot("a.png", takenAt: testNow - 2)
        try sandbox.addShot("b.png", takenAt: testNow - 1)
        let library = sandbox.library()
        library.reconcile()
        let both = [sandbox.path("a.png"), sandbox.path("b.png")]

        library.togglePin([sandbox.path("a.png")])
        library.togglePin(both)
        #expect(Set(library.pinnedNames) == ["a.png", "b.png"])

        library.togglePin(both)
        #expect(library.pinnedNames.isEmpty)
    }

    @Test func renamingInFinderKeepsThePin() throws {
        try sandbox.addShot("Screenshot.png")
        let library = sandbox.library()
        library.reconcile()
        library.togglePin([sandbox.path("Screenshot.png")])

        try FileManager.default.moveItem(atPath: sandbox.path("Screenshot.png"), toPath: sandbox.path("bug 123.png"))
        library.reconcile()

        #expect(library.pinnedNames == ["bug 123.png"])
    }

    @Test func deletingInFinderForgetsTheShot() throws {
        try sandbox.addShot("a.png")
        let library = sandbox.library()
        library.reconcile()
        library.togglePin([sandbox.path("a.png")])

        try FileManager.default.removeItem(atPath: sandbox.path("a.png"))
        library.reconcile()

        #expect(library.shots.isEmpty)
        #expect(library.index.pinned.isEmpty)
    }

    // MARK: Trash, move, copy

    @Test func undoPutsTrashedShotsBackWithTheirPins() throws {
        for (i, name) in ["a.png", "b.png", "c.png"].enumerated() {
            try sandbox.addShot(name, takenAt: testNow - Double(i))
        }
        let library = sandbox.library()
        library.reconcile()
        library.togglePin([sandbox.path("c.png")])
        library.togglePin([sandbox.path("b.png")])
        library.togglePin([sandbox.path("a.png")])

        library.trash([sandbox.path("a.png"), sandbox.path("c.png")])
        #expect(library.names == ["b.png"])
        #expect(!FileManager.default.fileExists(atPath: sandbox.path("a.png")))

        library.undoTrash()
        #expect(library.names == ["a.png", "b.png", "c.png"])
        #expect(library.pinnedNames == ["a.png", "b.png", "c.png"])
        #expect(FileManager.default.fileExists(atPath: sandbox.path("a.png")))
        #expect(library.lastTrashed.isEmpty)
    }

    @Test func movingAShotLetsGoOfItWithoutOverwriting() throws {
        try sandbox.addShot("a.png")
        let destination = sandbox.root.appending(path: "Kept")
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        try "taken".write(to: destination.appending(path: "a.png"), atomically: true, encoding: .utf8)
        let library = sandbox.library()
        library.reconcile()
        library.togglePin([sandbox.path("a.png")])

        library.move([sandbox.path("a.png")], to: destination)

        #expect(library.shots.isEmpty)
        #expect(library.index.pinned.isEmpty)
        #expect(FileManager.default.fileExists(atPath: destination.appending(path: "a 2.png").path(percentEncoded: false)))
    }

    @Test func copyPutsEachShotOnThePasteboardAsFileAndImage() throws {
        let a = try sandbox.addShot("a.png", takenAt: testNow - 1)
        try sandbox.addShot("b.png")
        let library = sandbox.library()
        library.reconcile()

        library.copy([sandbox.path("a.png"), sandbox.path("b.png")])

        let items = try #require(sandbox.pasteboard.pasteboardItems)
        #expect(items.count == 2)
        #expect(items[1].string(forType: .fileURL) == a.absoluteString)
        #expect(items[1].data(forType: .png) == (try Data(contentsOf: a)))
    }

    // MARK: Cleanup and the index

    @Test func cleanupTrashesExpiredShotsAndKeepsTheUserUndo() throws {
        let library = sandbox.library()
        try sandbox.addShot("old.png", takenAt: testNow + 1)
        try sandbox.addShot("mine.png", takenAt: testNow + 2)
        library.reconcile()
        library.trash([sandbox.path("mine.png")])

        sandbox.now = testNow + 8 * 86_400
        library.cleanUp()

        #expect(library.shots.isEmpty)
        #expect(FileManager.default.fileExists(atPath: sandbox.trash.appending(path: "old.png").path(percentEncoded: false)))
        #expect(library.lastTrashed.map(\.shot.url.lastPathComponent) == ["mine.png"])
    }

    @Test func unreadableIndexIsSetAsideNotOverwritten() throws {
        try "not json".write(to: sandbox.indexURL, atomically: true, encoding: .utf8)

        let library = sandbox.library()

        #expect(library.index.pinned.isEmpty)
        #expect(FileManager.default.fileExists(atPath: sandbox.indexURL.appendingPathExtension("corrupt").path(percentEncoded: false)))
    }
}
