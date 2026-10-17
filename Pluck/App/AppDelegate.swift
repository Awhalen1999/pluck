import AppKit

/// Builds the app's long-lived pieces once, at launch, and wires them together.
/// Anything that touches the system starts and stops here.
@Observable final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var library: ShotLibrary?
    @ObservationIgnored private var preferences: Preferences?
    @ObservationIgnored private var notch: NotchController?
    @ObservationIgnored private let screencapture = ScreencaptureSettings()
    /// Whether Pluck turned the macOS thumbnail off this session, so quitting
    /// knows to bring it back.
    @ObservationIgnored private var replacedThumbnail = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app. Keep them from opening the notch or
        // touching real folders and settings.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let preferences = Preferences()
        screencapture.snapshotOriginals()
        // Pluck's Preview replaces the macOS thumbnail, which would otherwise hold
        // each file back for seconds. If macOS doesn't take the change, its
        // thumbnail stays and Pluck's Preview steps aside, so there's never two.
        replacedThumbnail = preferences.preview == .pluck && screencapture.setShowsThumbnail(false)

        // ponytail: the save folder is read once at launch; follow changes to it when Settings can change it.
        let library = ShotLibrary(folder: screencapture.saveFolder, preferences: preferences)
        library.start()
        self.preferences = preferences
        self.library = library
        notch = NotchController(library: library, preferences: preferences, showsPreview: replacedThumbnail)
    }

    /// Quitting Pluck brings the macOS thumbnail back, so there's always a preview.
    // ponytail: a crash or force quit skips this; the next launch and About's Restore cover it.
    func applicationWillTerminate(_ notification: Notification) {
        if replacedThumbnail { screencapture.restoreThumbnail() }
    }
}
