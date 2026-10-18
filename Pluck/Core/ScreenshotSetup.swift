import Foundation

/// Where screenshots are saved, and which preview shows them: the one owner of
/// both, so the folder Pluck shelves, the folder macOS saves to and the Preview can
/// never disagree. Settings changes them only through here.
final class ScreenshotSetup {
    private let screencapture: ScreencaptureSettings
    private let library: ShotLibrary
    private let preferences: Preferences

    init(screencapture: ScreencaptureSettings, library: ShotLibrary, preferences: Preferences) {
        self.screencapture = screencapture
        self.library = library
        self.preferences = preferences
    }

    var saveFolder: URL { library.folder }

    /// With Pluck's Preview, macOS saves into the holding folder and its thumbnail
    /// is off: each capture waits there for its Preview. Otherwise macOS keeps its
    /// own thumbnail and saves straight into the folder. If macOS refuses the first,
    /// the choice becomes the second, so it always says what's really happening.
    func apply() {
        if preferences.preview == .pluck, screencapture.hold() { return }
        library.savePending()
        screencapture.release()
        preferences.preview = .macOS
    }

    func setPreview(_ preview: PreviewStyle) {
        preferences.preview = preview
        apply()
    }

    func setSaveFolder(_ folder: URL) {
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        screencapture.setSaveFolder(folder)
        library.change(folder: folder)
        // While Pluck's Preview holds captures, macOS keeps saving to the holding
        // folder; they reach the new folder once their Preview is done.
        if preferences.preview == .macOS { screencapture.release() }
    }

    /// About's Restore: the macOS settings go back to how they were before Pluck,
    /// and Pluck stops changing them, so it can be uninstalled cleanly.
    func restoreOriginals() {
        library.savePending()
        preferences.preview = .macOS
        screencapture.restoreOriginals()
        library.change(folder: screencapture.saveFolder)
    }

    /// Quitting: what's waiting is saved, and macOS gets the user's own back.
    func release() {
        library.savePending()
        screencapture.release()
    }
}
