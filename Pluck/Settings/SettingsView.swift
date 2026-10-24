import SwiftUI

/// Pluck's Settings: native panes over the same models the app runs on, so a
/// change takes effect at once.
struct SettingsView: View {
    let app: AppDelegate

    var body: some View {
        if let setup = app.setup, let library = app.library {
            TabView {
                Tab("General", systemImage: "gearshape") {
                    GeneralSettings(preferences: app.preferences, setup: setup, library: library)
                }
                Tab("About", systemImage: "info.circle") {
                    AboutSettings(preferences: app.preferences, setup: setup, updater: app.updates?.updater)
                }
            }
            .frame(width: Theme.Settings.width)
        }
    }
}
