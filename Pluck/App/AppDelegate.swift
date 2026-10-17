import AppKit

/// Builds the app's long-lived pieces once, at launch, and wires them together.
@Observable final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var library: ShotLibrary?
    @ObservationIgnored private var preferences: Preferences?
    @ObservationIgnored private var notch: NotchController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app. Keep them from opening the notch or
        // touching real folders.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let preferences = Preferences()
        // ponytail: the save folder is read once at launch; follow changes to it when Settings can change it.
        let library = ShotLibrary(folder: ScreencaptureSettings.saveFolder, preferences: preferences)
        library.start()
        self.preferences = preferences
        self.library = library
        notch = NotchController()
    }
}
