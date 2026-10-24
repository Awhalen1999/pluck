import Sparkle
import SwiftUI

struct AboutSettings: View {
    let preferences: Preferences
    let setup: ScreenshotSetup
    /// Nil in development builds, which never update themselves.
    let updater: SPUUpdater?
    @State private var restored = false
    @State private var checksAutomatically = false

    var body: some View {
        Form {
            Section {
                HStack(spacing: Theme.Space.l) {
                    Image(nsImage: NSApp.applicationIconImage)
                        .resizable()
                        .frame(width: Theme.Settings.iconSize, height: Theme.Settings.iconSize)
                    VStack(alignment: .leading) {
                        Text("Pluck").font(.title2.bold())
                        Text("Version \(Bundle.main.version)").foregroundStyle(.secondary)
                    }
                }
            }

            if let updater {
                Section("Updates") {
                    Toggle(isOn: Binding(get: { checksAutomatically }, set: { on in
                        updater.automaticallyChecksForUpdates = on
                        checksAutomatically = on
                    })) {
                        Text("Check for updates automatically")
                        Text("Pluck looks for a new version once a day.")
                    }
                    LabeledContent("Check for updates") {
                        Button("Check Now") { updater.checkForUpdates() }
                    }
                }
            }

            Section {
                LabeledContent {
                    Button(restored ? "Restored" : "Restore") {
                        setup.restoreOriginals()
                        restored = true
                    }
                    .disabled(restored)
                } label: {
                    Text("Restore macOS screenshot settings")
                    Text(restored
                         ? "Your original settings are back."
                         : "Puts the save location and thumbnail back the way they were before Pluck.")
                }
                LabeledContent {
                    Button("Show Next Time") {
                        preferences.onboarding = .new
                    }
                    .disabled(preferences.onboarding != .finished)
                } label: {
                    Text("Show the welcome again")
                    Text("It opens the next time Pluck starts.")
                }
                LabeledContent("Quit Pluck") {
                    Button("Quit") { NSApp.terminate(nil) }
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("To uninstall, restore your settings first, then move Pluck to the Trash.")
            }
        }
        .formStyle(.grouped)
        .onAppear {
            // A change in General since makes it worth restoring again.
            restored = false
            checksAutomatically = updater?.automaticallyChecksForUpdates ?? false
        }
    }
}

private extension Bundle {
    /// "1.0 (100)".
    var version: String {
        let short = object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        return "\(short) (\(build))"
    }
}
