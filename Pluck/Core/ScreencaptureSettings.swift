import Foundation

/// The macOS screenshot settings in `com.apple.screencapture`: where captures are
/// saved and whether the floating thumbnail shows. Pluck snapshots them before it
/// changes anything, so they can always be put back exactly as the user had them.
// ponytail: a location the user picks in ⇧⌘5 while Pluck runs is lost on restore; follow it when Settings owns "Save to".
struct ScreencaptureSettings {
    var domain = "com.apple.screencapture"
    /// Where the snapshot of the user's own settings is kept.
    var originals: UserDefaults = .standard

    /// The settings Pluck may change, and so snapshots.
    static let managedKeys = ["show-thumbnail", "location"]

    /// Where the user has macOS save screenshots, from the snapshot, since Pluck
    /// points macOS at its own holding folder. Missing or invalid means Desktop.
    var saveFolder: URL {
        guard let raw = originals.dictionary(forKey: Self.snapshotKey)?["location"] as? String else { return .desktopDirectory }
        let path = (raw as NSString).expandingTildeInPath
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return .desktopDirectory }
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    /// Whether the macOS floating thumbnail shows. A missing key means it does.
    var showsThumbnail: Bool { value(for: "show-thumbnail") as? Bool ?? true }

    /// Turns the floating thumbnail on or off, then reads it back. Returns whether
    /// the change stuck.
    @discardableResult
    func setShowsThumbnail(_ shows: Bool) -> Bool {
        set(shows as NSNumber, for: "show-thumbnail")
        return showsThumbnail == shows
    }

    /// Points macOS's captures at a folder, then reads it back. Returns whether the
    /// change stuck.
    @discardableResult
    func setLocation(_ folder: URL) -> Bool {
        let path = folder.path(percentEncoded: false)
        set(path as NSString, for: "location")
        return value(for: "location") as? String == path
    }

    /// Records the user's own settings, once ever: later launches keep that first
    /// record, since Pluck has changed the values since. The save location is the
    /// exception. Pluck can tell `holding`, its own, from the user's, so a location
    /// the user chose while Pluck wasn't running is followed.
    func snapshotOriginals(holding: URL) {
        var snapshot = originals.dictionary(forKey: Self.snapshotKey)
            ?? Self.managedKeys.reduce(into: [String: Any]()) { $0[$1] = value(for: $1) }
        let location = value(for: "location") as? String
        if location != holding.path(percentEncoded: false) { snapshot["location"] = location }
        originals.set(snapshot, forKey: Self.snapshotKey)
    }

    /// Puts every setting Pluck may change back the way the user had it.
    func restore() {
        guard let snapshot = originals.dictionary(forKey: Self.snapshotKey) else { return }
        for key in Self.managedKeys { set(snapshot[key] as AnyObject?, for: key) }
    }

    private static let snapshotKey = "screencaptureOriginals"

    private func value(for key: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    /// Writing nil removes the key, which is how "the user never set this" is restored.
    private func set(_ value: AnyObject?, for key: String) {
        CFPreferencesSetAppValue(key as CFString, value, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }
}
