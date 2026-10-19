import Foundation
import Testing
@testable import Pluck

/// A throwaway preferences domain standing in for `com.apple.screencapture`, and
/// a throwaway store for the snapshot and save folder. Both are removed when the
/// test ends.
@MainActor
private final class Scratch {
    let domain = "app.pluck.tests.screencapture-\(UUID().uuidString)"
    let storeName = "app.pluck.tests.originals-\(UUID().uuidString)"
    let holding = FileManager.default.temporaryDirectory.appending(path: "PluckTests-holding-\(UUID().uuidString)")
    lazy var settings = ScreencaptureSettings(domain: domain, store: UserDefaults(suiteName: storeName)!, holding: holding)

    /// What the "user" had before Pluck ever ran.
    func userHas(thumbnail: Bool? = nil, location: String? = nil) {
        CFPreferencesSetAppValue("show-thumbnail" as CFString, thumbnail.map { $0 as NSNumber }, domain as CFString)
        CFPreferencesSetAppValue("location" as CFString, location as CFString?, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    var rawThumbnail: Any? { raw("show-thumbnail") }
    var rawLocation: String? { raw("location") as? String }

    private func raw(_ key: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    /// Clears every key through CFPreferences, then deletes the files, so nothing
    /// is left in ~/Library/Preferences.
    isolated deinit {
        for name in [domain, storeName] {
            let keys = CFPreferencesCopyKeyList(name as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? [String] ?? []
            for key in keys { CFPreferencesSetAppValue(key as CFString, nil, name as CFString) }
            CFPreferencesAppSynchronize(name as CFString)
            try? FileManager.default.removeItem(at: URL.libraryDirectory.appending(path: "Preferences/\(name).plist"))
        }
    }
}

/// A real folder, for a location `saveFolder` will accept.
private func folder(_ name: String) throws -> URL {
    let url = FileManager.default.temporaryDirectory.appending(path: "PluckTests-\(name)-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

@Test func holdingPointsMacOSAtPlucksFolderWithNoThumbnail() {
    let scratch = Scratch()
    scratch.settings.prepare()

    #expect(scratch.settings.hold())

    #expect(scratch.rawThumbnail as? Bool == false)
    #expect(scratch.rawLocation == scratch.holding.path(percentEncoded: false))
}

@Test func releasingKeepsWhatTheUserNeverSet() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: nil, location: nil)
    scratch.settings.prepare()
    _ = scratch.settings.hold()

    scratch.settings.release()

    #expect(scratch.rawThumbnail == nil)
    #expect(scratch.rawLocation == nil)
    #expect(scratch.settings.saveFolder == .desktopDirectory)
}

@Test func releasingGivesMacOSTheFolderChosenInPluck() throws {
    let scratch = Scratch()
    scratch.userHas(thumbnail: true)
    scratch.settings.prepare()
    let chosen = try folder("chosen")
    defer { try? FileManager.default.removeItem(at: chosen) }
    _ = scratch.settings.hold()
    scratch.settings.setSaveFolder(chosen)

    scratch.settings.release()

    #expect(scratch.rawLocation == chosen.path(percentEncoded: false))
    #expect(scratch.rawThumbnail as? Bool == true)
}

@Test func restoringPutsBackHowItWasBeforePluckAndForgetsTheChoice() throws {
    let scratch = Scratch()
    let theirs = try folder("theirs")
    let chosen = try folder("chosen")
    defer { [theirs, chosen].forEach { try? FileManager.default.removeItem(at: $0) } }
    scratch.userHas(thumbnail: false, location: theirs.path(percentEncoded: false))
    scratch.settings.prepare()
    scratch.settings.setSaveFolder(chosen)
    _ = scratch.settings.hold()

    scratch.settings.restoreOriginals()

    #expect(scratch.rawThumbnail as? Bool == false)
    #expect(scratch.rawLocation == theirs.path(percentEncoded: false))
    #expect(scratch.settings.saveFolder.standardizedFileURL == theirs.standardizedFileURL)
}

@Test func theSnapshotIsTakenOnceAndSurvivesPlucksOwnChanges() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: true)
    scratch.settings.prepare()
    _ = scratch.settings.hold()

    // The next launch prepares again, after Pluck has changed both.
    scratch.settings.prepare()
    scratch.settings.restoreOriginals()

    #expect(scratch.rawThumbnail as? Bool == true)
    #expect(scratch.rawLocation == nil)
}

@Test func aLocationChosenInMacOSWhilePluckWasntRunningIsFollowed() throws {
    let scratch = Scratch()
    scratch.settings.prepare()
    _ = scratch.settings.hold()
    scratch.settings.release()

    // Between launches, the user picks a folder in the Screenshot app.
    let chosen = try folder("chosen")
    defer { try? FileManager.default.removeItem(at: chosen) }
    scratch.userHas(location: chosen.path(percentEncoded: false))
    scratch.settings.prepare()
    #expect(scratch.settings.saveFolder.standardizedFileURL == chosen.standardizedFileURL)

    // After a crash, macOS still points at the holding folder: that isn't the user's.
    _ = scratch.settings.hold()
    scratch.settings.prepare()
    #expect(scratch.settings.saveFolder.standardizedFileURL == chosen.standardizedFileURL)
}

@Test func aSaveFolderThatsGoneMeansDesktop() throws {
    let scratch = Scratch()
    let gone = try folder("gone")
    scratch.settings.setSaveFolder(gone)
    try FileManager.default.removeItem(at: gone)

    #expect(scratch.settings.saveFolder == .desktopDirectory)
}

// MARK: Screenshot setup

/// A setup over a sandboxed library and a scratch macOS domain, where the user
/// saved screenshots to the sandbox's folder before Pluck.
private func setup() throws -> (ScreenshotSetup, ShotLibrary, Sandbox, Scratch) {
    let sandbox = try Sandbox()
    let scratch = Scratch()
    scratch.userHas(location: sandbox.folder.path(percentEncoded: false))
    scratch.settings.prepare()
    let library = sandbox.library()
    let setup = ScreenshotSetup(screencapture: scratch.settings, library: library, preferences: sandbox.preferences)
    setup.setPreview(.pluck)
    return (setup, library, sandbox, scratch)
}

@Test func untilTheUserChoosesMacOSKeepsItsOwnSettings() throws {
    let sandbox = try Sandbox()
    let scratch = Scratch()
    scratch.userHas(thumbnail: nil, location: nil)
    scratch.settings.prepare()
    let setup = ScreenshotSetup(screencapture: scratch.settings, library: sandbox.library(), preferences: sandbox.preferences)

    setup.apply()

    #expect(scratch.rawThumbnail == nil)
    #expect(scratch.rawLocation == nil)
}

@Test func switchingToTheMacOSPreviewSavesWhatsWaitingAndHandsMacOSBack() throws {
    let (setup, library, sandbox, scratch) = try setup()
    #expect(scratch.rawLocation == scratch.holding.path(percentEncoded: false))
    try sandbox.addShot("waiting.png", waiting: true)
    library.reconcilePending()

    setup.setPreview(.macOS)

    #expect(library.pending.isEmpty)
    #expect(library.names == ["waiting.png"])
    #expect(scratch.rawLocation == sandbox.folder.path(percentEncoded: false))
    #expect(scratch.rawThumbnail == nil)
}

@Test func aNewSaveFolderGetsTheShotsStillWaiting() throws {
    let (setup, library, sandbox, scratch) = try setup()
    let elsewhere = sandbox.root.appending(path: "Elsewhere")
    try sandbox.addShot("waiting.png", waiting: true)
    library.reconcilePending()

    setup.setSaveFolder(elsewhere)

    // macOS keeps saving to the holding folder while Pluck's Preview has them.
    #expect(scratch.rawLocation == scratch.holding.path(percentEncoded: false))
    library.savePending()
    #expect(FileManager.default.fileExists(atPath: elsewhere.appending(path: "waiting.png").path(percentEncoded: false)))
}

@Test func withTheMacOSPreviewANewSaveFolderIsWhereMacOSSaves() throws {
    let (setup, _, sandbox, scratch) = try setup()
    setup.setPreview(.macOS)
    let elsewhere = sandbox.root.appending(path: "Elsewhere")

    setup.setSaveFolder(elsewhere)

    #expect(scratch.rawLocation == elsewhere.path(percentEncoded: false))
}

@Test func restoringLeavesMacOSAsItWasAndPluckOutOfTheWay() throws {
    let (setup, library, sandbox, scratch) = try setup()
    setup.setSaveFolder(sandbox.root.appending(path: "Elsewhere"))

    setup.restoreOriginals()

    #expect(sandbox.preferences.preview == .macOS)
    #expect(scratch.rawLocation == sandbox.folder.path(percentEncoded: false))
    #expect(library.folder.standardizedFileURL == sandbox.folder.standardizedFileURL)
}
