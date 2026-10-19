import AppKit
import SwiftUI

/// Builds the app's long-lived pieces once, at launch, and wires them together.
/// Anything that touches the system starts and stops here.
@Observable final class AppDelegate: NSObject, NSApplicationDelegate {
    let preferences = Preferences()
    private(set) var library: ShotLibrary?
    private(set) var setup: ScreenshotSetup?
    @ObservationIgnored private var notch: NotchController?
    @ObservationIgnored private var onboarding: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests run inside the app. Keep them from opening the notch or
        // touching real folders and settings.
        guard ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil else { return }

        let screencapture = ScreencaptureSettings()
        screencapture.prepare()
        let library = ShotLibrary(folder: screencapture.saveFolder, preferences: preferences)
        let setup = ScreenshotSetup(screencapture: screencapture, library: library, preferences: preferences)
        setup.apply()
        self.library = library
        self.setup = setup
        notch = NotchController(library: library, preferences: preferences)
        watchWindows()
        // Onboarding starts the library once it has asked for the folder.
        if preferences.onboarding == .finished { library.start() } else { showOnboarding(library: library, setup: setup) }
    }

    /// The first run's window. It has no close button: finishing or quitting are
    /// the ways out, so Pluck is never left running half set up.
    private func showOnboarding(library: ShotLibrary, setup: ScreenshotSetup) {
        let view = OnboardingView(preferences: preferences, setup: setup, library: library) { [weak self] in
            self?.onboarding?.close()
            self?.onboarding = nil
        }
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.styleMask = [.titled]
        for button in [NSWindow.ButtonType.closeButton, .miniaturizeButton, .zoomButton] {
            window.standardWindowButton(button)?.isHidden = true
        }
        window.title = "Welcome to Pluck"
        window.titleVisibility = .hidden
        window.titlebarAppearsTransparent = true
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        // SwiftUI sizes the window as it lays out, so center it after.
        window.layoutIfNeeded()
        window.center()
        onboarding = window
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
        // macOS can refuse a menu bar app's activation at launch; the window shows anyway.
        window.orderFrontRegardless()
    }

    /// When the last of Pluck's windows closes (Settings, say), the app the user
    /// was in gets the keyboard back, as it does when the notch lets go.
    private func watchWindows() {
        Task {
            for await note in NotificationCenter.default.notifications(named: NSWindow.willCloseNotification) {
                guard let closing = note.object as? NSWindow, closing.isRegular else { continue }
                if !NSApp.windows.contains(where: { $0 !== closing && $0.isVisible && $0.isRegular }) { NSApp.hide(nil) }
            }
        }
    }

    /// Pluck lives in the notch. Closing Settings with the menu bar icon hidden
    /// closes its last window, and that must never quit it.
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    /// With the menu bar icon hidden, opening Pluck again is the way into Settings,
    /// or back to onboarding while it's under way.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        if let onboarding {
            NSApp.activate()
            onboarding.makeKeyAndOrderFront(nil)
        } else {
            openSettings()
        }
        return false
    }

    /// Quitting saves every capture still waiting, and gives macOS its thumbnail and
    /// folder back, so screenshots never pile up where the user can't see them.
    // ponytail: a crash or force quit skips this; the next launch saves what's waiting, and About's Restore covers the settings.
    func applicationWillTerminate(_ notification: Notification) {
        setup?.release()
    }
}

/// Opens Settings and brings Pluck forward: a menu bar app's windows open behind
/// the app the user is in otherwise.
@MainActor func openSettings() {
    NSApp.activate()
    // SwiftUI puts a Settings item in the app menu even when a menu bar app shows
    // no menus. Outside SwiftUI views, its action is the way to open Settings.
    let items = NSApp.mainMenu?.items.first?.submenu?.items ?? []
    guard let item = items.first(where: { $0.keyEquivalent == "," }), let action = item.action else { return }
    NSApp.sendAction(action, to: item.target, from: item)
}

private extension NSWindow {
    /// Settings and the like: not the notch, a panel, a menu or the menu bar item.
    var isRegular: Bool { styleMask.contains(.titled) && !(self is NSPanel) }
}
