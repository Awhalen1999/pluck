import SwiftUI

struct AboutSettings: View {
    let preferences: Preferences
    let setup: ScreenshotSetup
    @State private var restored = false

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
                         ? "Your original screenshot settings are back."
                         : "Returns the save location and thumbnail to how they were before Pluck.")
                }
                LabeledContent {
                    Button(preferences.onboarding == .finished ? "Show" : "Opens next launch") {
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
        // A change in General since makes it worth restoring again.
        .onAppear { restored = false }
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
