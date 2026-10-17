import SwiftUI

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuBarMenu(library: appDelegate.library)
        } label: {
            // ponytail: placeholder symbol until the menu bar icon is designed.
            Image(systemName: "camera.viewfinder").accessibilityLabel("Pluck")
        }
        #if DEBUG
        Window("Design System", id: DesignSystemView.windowID) {
            DesignSystemView()
        }
        .windowResizability(.contentSize)
        .defaultLaunchBehavior(.suppressed)
        #endif
    }
}
