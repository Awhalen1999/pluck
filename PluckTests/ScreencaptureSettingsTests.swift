import Foundation
import Testing
@testable import Pluck

/// A throwaway preferences domain standing in for `com.apple.screencapture`, and
/// a throwaway store for the snapshot. Both are removed when the test ends.
@MainActor
private final class Scratch {
    let domain = "app.pluck.tests.screencapture-\(UUID().uuidString)"
    let storeName = "app.pluck.tests.originals-\(UUID().uuidString)"
    lazy var settings = ScreencaptureSettings(domain: domain, originals: UserDefaults(suiteName: storeName)!)

    /// What the "user" had before Pluck ever ran.
    func userHas(thumbnail: Bool? = nil, location: String? = nil) {
        CFPreferencesSetAppValue("show-thumbnail" as CFString, thumbnail.map { $0 as NSNumber }, domain as CFString)
        CFPreferencesSetAppValue("location" as CFString, location as CFString?, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    var rawThumbnail: Any? { raw("show-thumbnail") }
    var rawLocation: Any? { raw("location") }

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

private let holding = URL(filePath: "/tmp/pluck-holding")

@Test func turningTheThumbnailOffSticksAndReadsBack() {
    let scratch = Scratch()
    #expect(scratch.settings.showsThumbnail)
    #expect(scratch.settings.setShowsThumbnail(false))
    #expect(!scratch.settings.showsThumbnail)
}

@Test func restoringPutsBackASettingTheUserNeverMade() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: nil)
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.setShowsThumbnail(false)

    scratch.settings.restore()

    #expect(scratch.rawThumbnail == nil)
    #expect(scratch.settings.showsThumbnail)
}

@Test func restoringPutsBackTheUsersOwnChoice() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: false)
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.setShowsThumbnail(true)

    scratch.settings.restore()

    #expect(scratch.rawThumbnail as? Bool == false)
}

@Test func theSnapshotIsTakenOnceAndSurvivesPlucksOwnChanges() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: true)
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.setShowsThumbnail(false)

    // The next launch snapshots again, after Pluck has turned the thumbnail off.
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.restore()

    #expect(scratch.rawThumbnail as? Bool == true)
}

@Test func capturesGoToPlucksFolderUntilRestoredToWhereTheUserHadThem() throws {
    let scratch = Scratch()
    let theirs = FileManager.default.temporaryDirectory.appending(path: "PluckTests-theirs-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: theirs, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: theirs) }
    scratch.userHas(location: theirs.path(percentEncoded: false))
    scratch.settings.snapshotOriginals(holding: holding)

    #expect(scratch.settings.setLocation(holding))
    // Pluck saves into the user's own folder, not where macOS now points.
    #expect(scratch.settings.saveFolder.standardizedFileURL == theirs.standardizedFileURL)

    scratch.settings.restore()
    #expect(scratch.rawLocation as? String == theirs.path(percentEncoded: false))
}

@Test func aLocationTheUserNeverSetIsRemovedAgainAndMeansDesktop() {
    let scratch = Scratch()
    scratch.userHas(location: nil)
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.setLocation(holding)

    scratch.settings.restore()

    #expect(scratch.rawLocation == nil)
    #expect(scratch.settings.saveFolder == .desktopDirectory)
}

@Test func aLocationChosenWhilePluckWasntRunningIsFollowed() throws {
    let scratch = Scratch()
    scratch.userHas(location: nil)
    scratch.settings.snapshotOriginals(holding: holding)
    scratch.settings.setLocation(holding)
    scratch.settings.restore()

    // Between launches, the user picks a folder in the Screenshot app.
    let chosen = FileManager.default.temporaryDirectory.appending(path: "PluckTests-chosen-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: chosen, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: chosen) }
    scratch.userHas(location: chosen.path(percentEncoded: false))
    scratch.settings.snapshotOriginals(holding: holding)
    #expect(scratch.settings.saveFolder.standardizedFileURL == chosen.standardizedFileURL)

    // After a crash, macOS still points at Pluck's folder; that isn't the user's choice.
    scratch.settings.setLocation(holding)
    scratch.settings.snapshotOriginals(holding: holding)
    #expect(scratch.settings.saveFolder.standardizedFileURL == chosen.standardizedFileURL)
}
