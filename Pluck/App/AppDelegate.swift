import AppKit

/// Builds the app's long-lived pieces once, at launch, and wires them together.
/// Anything that touches the system starts and stops here.
@Observable final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var library: ShotLibrary?
    @ObservationIgnored private var notch: NotchController?
    @ObservationIgnored private let screencapture = ScreencaptureSettings()

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app. Keep them from opening the notch or
        // touching real folders and settings.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let preferences = Preferences()
        screencapture.snapshotOriginals(holding: ShotLibrary.holdingFolder)
        let library = ShotLibrary(folder: screencapture.saveFolder, preferences: preferences)
        // Pluck's Preview stands in for the macOS thumbnail. macOS saves captures
        // into Pluck's holding folder, and each reaches the save folder once its
        // Preview is done, as one does behind the thumbnail. If macOS doesn't take
        // both changes, its own thumbnail and folder stay, and Pluck shelves shots
        // as they land.
        let holding = preferences.preview == .pluck
            && screencapture.setShowsThumbnail(false)
            && screencapture.setLocation(library.incoming)
        if !holding { screencapture.restore() }
        library.start()
        self.library = library
        notch = NotchController(library: library, preferences: preferences)
    }

    /// Quitting saves every capture still waiting, and gives macOS its thumbnail and
    /// folder back, so screenshots never pile up where the user can't see them.
    // ponytail: a crash or force quit skips this; the next launch saves what's waiting, and About's Restore covers the settings.
    func applicationWillTerminate(_ notification: Notification) {
        library?.savePending()
        screencapture.restore()
    }
}
