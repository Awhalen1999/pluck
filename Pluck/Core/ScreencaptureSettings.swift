import Foundation

/// The macOS screenshot settings Pluck manages, in `com.apple.screencapture`:
/// where captures are saved, and whether the floating thumbnail shows.
///
/// Three things are kept apart. The snapshot is how the user had them before
/// Pluck, taken once ever, so Restore can always put exactly that back,
/// "never set" included. The save folder is where the user wants screenshots now:
/// Pluck's "Save to". And macOS's live values are whatever Pluck has set for the
/// moment, the holding folder and no thumbnail while Pluck's Preview has the
/// captures, or the user's own otherwise.
struct ScreencaptureSettings {
    var domain = "com.apple.screencapture"
    /// Pluck's own store, for the snapshot and the save folder.
    var store: UserDefaults = .standard
    var holding = ShotLibrary.holdingFolder

    /// Takes the snapshot, once ever, and follows a location the user chose in
    /// macOS while Pluck wasn't running. One that's still the holding folder, after
    /// a crash, isn't the user's.
    func prepare() {
        if store.dictionary(forKey: Self.snapshotKey) == nil {
            store.set(Self.keys.reduce(into: [String: Any]()) { $0[$1] = value(for: $1) }, forKey: Self.snapshotKey)
        }
        let live = value(for: "location") as? String
        if live != path(holding) { store.set(live, forKey: Self.saveFolderKey) }
    }

    /// Where the user wants screenshots. Missing, or a folder that's gone, means Desktop.
    var saveFolder: URL {
        guard let raw = store.string(forKey: Self.saveFolderKey) else { return .desktopDirectory }
        let path = (raw as NSString).expandingTildeInPath
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return .desktopDirectory }
        return URL(filePath: path, directoryHint: .isDirectory)
    }

    func setSaveFolder(_ folder: URL) {
        store.set(path(folder), forKey: Self.saveFolderKey)
    }

    /// However it's spelled.
    func isSaveFolder(_ folder: URL) -> Bool { path(folder) == path(saveFolder) }

    /// Points macOS at the holding folder with its thumbnail off, for Pluck's
    /// Preview, and reads both back. If macOS didn't take them, it gets the user's
    /// own back, and this returns false.
    func hold() -> Bool {
        set(false as NSNumber, for: "show-thumbnail")
        set(path(holding) as NSString, for: "location")
        let held = value(for: "show-thumbnail") as? Bool == false && value(for: "location") as? String == path(holding)
        if !held { release() }
        return held
    }

    /// Gives macOS the user's save folder and their own thumbnail, as when Pluck
    /// isn't running.
    func release() {
        set(snapshot["show-thumbnail"] as AnyObject?, for: "show-thumbnail")
        releaseFolder()
    }

    /// Gives macOS the user's save folder, and leaves its thumbnail as it is.
    func releaseFolder() {
        set(store.string(forKey: Self.saveFolderKey) as NSString?, for: "location")
    }

    /// What macOS has now, which the user can change in ⇧⌘5's Options at any
    /// time: the folder it saves to, nil while it's the holding folder, and
    /// whether its floating thumbnail is on.
    var live: (folder: URL?, thumbnail: Bool) {
        // A missing location means Desktop, a missing thumbnail setting means on.
        let location = (value(for: "location") as? String).map { ($0 as NSString).expandingTildeInPath }
        let folder = URL(filePath: location ?? URL.desktopDirectory.path(percentEncoded: false), directoryHint: .isDirectory)
        return (path(folder) == path(holding) ? nil : folder, value(for: "show-thumbnail") as? Bool != false)
    }

    /// Calls `changed` whenever macOS's screenshot settings change, whoever changed them.
    func watch(_ changed: @escaping @MainActor @Sendable () -> Void) -> NSObject {
        PreferencesObserver(domain: domain, keys: Self.keys, changed: changed)
    }

    /// Puts both back as they were before Pluck, the save folder included.
    func restoreOriginals() {
        store.set(snapshot["location"] as? String, forKey: Self.saveFolderKey)
        release()
    }

    private static let keys = ["show-thumbnail", "location"]
    private static let snapshotKey = "screencaptureOriginals"
    private static let saveFolderKey = "saveFolder"

    private var snapshot: [String: Any] { store.dictionary(forKey: Self.snapshotKey) ?? [:] }

    /// One spelling per folder, with no trailing slash, as macOS writes them.
    private func path(_ folder: URL) -> String { (folder.path(percentEncoded: false) as NSString).standardizingPath }

    private func value(for key: String) -> Any? {
        CFPreferencesAppSynchronize(domain as CFString)
        return CFPreferencesCopyAppValue(key as CFString, domain as CFString)
    }

    /// Writing nil removes the key, which is how "the user never set this" is kept.
    private func set(_ value: AnyObject?, for key: String) {
        CFPreferencesSetAppValue(key as CFString, value, domain as CFString)
        CFPreferencesAppSynchronize(domain as CFString)
    }
}

/// Observes keys in another app's preferences. Key-value observing a defaults
/// suite also reports changes other processes make.
private final class PreferencesObserver: NSObject {
    private let defaults: UserDefaults?
    private let keys: [String]
    nonisolated private let changed: @MainActor @Sendable () -> Void

    init(domain: String, keys: [String], changed: @escaping @MainActor @Sendable () -> Void) {
        defaults = UserDefaults(suiteName: domain)
        self.keys = keys
        self.changed = changed
        super.init()
        for key in keys { defaults?.addObserver(self, forKeyPath: key, context: nil) }
    }

    isolated deinit {
        for key in keys { defaults?.removeObserver(self, forKeyPath: key) }
    }

    /// Handled once the write that caused it is done, Pluck's own included.
    nonisolated override func observeValue(forKeyPath keyPath: String?, of object: Any?,
                                           change: [NSKeyValueChangeKey: Any]?, context: UnsafeMutableRawPointer?) {
        Task { @MainActor [changed] in changed() }
    }
}
