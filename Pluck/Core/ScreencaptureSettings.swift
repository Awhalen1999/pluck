import Foundation

/// The macOS screenshot settings in `com.apple.screencapture`. Reading only for
/// now; writing (save location, floating thumbnail) arrives with Settings.
enum ScreencaptureSettings {
    private static let domain = "com.apple.screencapture" as CFString

    /// Where macOS saves screenshots. A missing or invalid location means Desktop.
    static var saveFolder: URL {
        CFPreferencesAppSynchronize(domain)
        guard let raw = CFPreferencesCopyAppValue("location" as CFString, domain) as? String else { return .desktopDirectory }
        let path = (raw as NSString).expandingTildeInPath
        var isFolder: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isFolder), isFolder.boolValue else { return .desktopDirectory }
        return URL(filePath: path, directoryHint: .isDirectory)
    }
}
