import SwiftUI

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra(isInserted: Bindable(appDelegate.preferences).showsMenuBarIcon) {
            MenuBarMenu(library: appDelegate.library)
        } label: {
            // ponytail: placeholder symbol until the menu bar icon is designed.
            Image(systemName: "camera.viewfinder").accessibilityLabel("Pluck")
        }
        Settings {
            SettingsView(app: appDelegate)
        }
        #if DEBUG
        Window("Design System", id: DesignSystemView.windowID) {
            DesignSystemView()
        }
        .windowResizability(.contentSize)
        // `-openDesignSystem YES` opens it at launch, for reviewing without clicking around.
        .defaultLaunchBehavior(UserDefaults.standard.bool(forKey: "openDesignSystem") ? .presented : .suppressed)
        #endif
    }
}
