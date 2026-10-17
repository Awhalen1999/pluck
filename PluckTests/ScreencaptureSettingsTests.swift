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
    func userHas(thumbnail: Bool?) {
        CFPreferencesSetAppValue("show-thumbnail" as CFString, thumbnail.map { $0 as NSNumber }, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }

    var rawThumbnail: Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue("show-thumbnail" as CFString, domain as CFString)
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

@Test func turningTheThumbnailOffSticksAndReadsBack() {
    let scratch = Scratch()
    #expect(scratch.settings.showsThumbnail)
    #expect(scratch.settings.setShowsThumbnail(false))
    #expect(!scratch.settings.showsThumbnail)
}

@Test func restoringPutsBackASettingTheUserNeverMade() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: nil)
    scratch.settings.snapshotOriginals()
    scratch.settings.setShowsThumbnail(false)

    scratch.settings.restoreThumbnail()

    #expect(scratch.rawThumbnail == nil)
    #expect(scratch.settings.showsThumbnail)
}

@Test func restoringPutsBackTheUsersOwnChoice() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: false)
    scratch.settings.snapshotOriginals()
    scratch.settings.setShowsThumbnail(true)

    scratch.settings.restoreThumbnail()

    #expect(scratch.rawThumbnail as? Bool == false)
}

@Test func theSnapshotIsTakenOnceAndSurvivesPlucksOwnChanges() {
    let scratch = Scratch()
    scratch.userHas(thumbnail: true)
    scratch.settings.snapshotOriginals()
    scratch.settings.setShowsThumbnail(false)

    // The next launch snapshots again, after Pluck has turned the thumbnail off.
    scratch.settings.snapshotOriginals()
    scratch.settings.restoreThumbnail()

    #expect(scratch.rawThumbnail as? Bool == true)
}
