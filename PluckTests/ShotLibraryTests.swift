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

    @Test func freshCapturesAreAnnouncedButOldFilesMovedInAreNot() throws {
        try sandbox.addShot("already there.png", takenAt: testNow - 10)
        let library = sandbox.library()
        var announced: [String] = []
        library.onArrival = { announced.append($0.url.lastPathComponent) }
        library.reconcile(announcing: false)

        try sandbox.addShot("just taken.png", takenAt: testNow - 2)
        try sandbox.addShot("from last week.png", takenAt: testNow - 7 * 86_400)
        library.reconcile()

        #expect(announced == ["just taken.png"])
        #expect(library.shots.count == 3)
    }

    @Test func aLandingScreenshotIsNoticedWithoutARefresh() async throws {
        let library = sandbox.library()
        library.start()
        var announced: [String] = []
        library.onArrival = { announced.append($0.url.lastPathComponent) }

        try sandbox.addShot("landed.png")
        for _ in 0..<40 where announced.isEmpty { try await Task.sleep(for: .milliseconds(50)) }

        #expect(announced == ["landed.png"])
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
        var announced = 0
        library.onArrival = { _ in announced += 1 }

        try FileManager.default.moveItem(atPath: sandbox.path("Screenshot.png"), toPath: sandbox.path("bug 123.png"))
        library.reconcile()

        #expect(library.pinnedNames == ["bug 123.png"])
        #expect(announced == 0)
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
