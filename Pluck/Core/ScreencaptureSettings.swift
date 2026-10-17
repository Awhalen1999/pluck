import Foundation

/// The macOS screenshot settings in `com.apple.screencapture`: where captures are
/// saved and whether the floating thumbnail shows. Pluck snapshots them before it
/// changes anything, so they can always be put back exactly as the user had them.
struct ScreencaptureSettings {
    var domain = "com.apple.screencapture"
    /// Where the snapshot of the user's own settings is kept.
    var originals: UserDefaults = .standard

    /// The settings Pluck may change, and so snapshots.
    static let managedKeys = ["show-thumbnail", "location"]

    /// Where macOS saves screenshots. A missing or invalid location means Desktop.
    var saveFolder: URL {
        guard let raw = value(for: "location") as? String else { return .desktopDirectory }
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

    /// Records the user's own settings, once ever. Later launches keep that first
    /// record, even though Pluck has changed the values since.
    func snapshotOriginals() {
        guard originals.dictionary(forKey: Self.snapshotKey) == nil else { return }
        var snapshot: [String: Any] = [:]
        for key in Self.managedKeys {
            if let value = value(for: key) { snapshot[key] = value }
        }
        originals.set(snapshot, forKey: Self.snapshotKey)
    }

    /// Puts the floating thumbnail back the way the user had it before Pluck.
    func restoreThumbnail() {
        guard let snapshot = originals.dictionary(forKey: Self.snapshotKey) else { return }
        set(snapshot["show-thumbnail"] as AnyObject?, for: "show-thumbnail")
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
