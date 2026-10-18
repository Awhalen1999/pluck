import SwiftUI

struct AboutSettings: View {
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
                         ? "The save location and thumbnail are back to how they were before Pluck."
                         : "Puts the save location and thumbnail back to how they were before Pluck.")
                }
                LabeledContent("Quit Pluck") {
                    Button("Quit") { NSApp.terminate(nil) }
                }
            } header: {
                Text("Reset")
            } footer: {
                Text("Uninstalling? Restore first, then drag Pluck to the Trash.")
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
