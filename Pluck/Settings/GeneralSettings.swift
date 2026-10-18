import SwiftUI

struct GeneralSettings: View {
    @Bindable var preferences: Preferences
    let setup: ScreenshotSetup
    let library: ShotLibrary
    @State private var choosingFolder = false
    @State private var opensAtLogin = LaunchAtLogin.isEnabled

    var body: some View {
        let folderName = FileManager.default.displayName(atPath: setup.saveFolder.path(percentEncoded: false))
        Form {
            Section {
                SaveFolderPicker(setup: setup, choosingFolder: $choosingFolder)
                Picker(selection: Binding(get: { preferences.preview }, set: setup.setPreview)) {
                    Text("Pluck").tag(PreviewStyle.pluck)
                    Text("macOS").tag(PreviewStyle.macOS)
                } label: {
                    Text("Preview")
                    Text(preferences.preview == .pluck
                         ? "A live preview in the notch, with Copy, Markup, Pin and Trash."
                         : "Apple’s corner thumbnail, with Markup.")
                }
                .pickerStyle(.segmented)
                if preferences.preview == .pluck {
                    Picker(selection: $preferences.previewDuration) {
                        ForEach(PreviewDuration.allCases, id: \.self) { Text("\(Int($0.rawValue))s").tag($0) }
                    } label: {
                        Text("Keep the preview up for")
                        Text("Hover it to keep it longer.")
                    }
                    .pickerStyle(.segmented)
                }
            } header: {
                Text("Capture")
            } footer: {
                Text("Save location and preview are macOS settings. Pluck changes them for you, and can put them back any time in About.")
            }

            Section {
                Picker(selection: $preferences.removeDraggedOut) {
                    Text("Keep").tag(false)
                    Text("Remove").tag(true)
                } label: {
                    Text("Shots you drag out")
                    Text(preferences.removeDraggedOut
                         ? "Drop one into an app and it leaves \(folderName): the app has it. Pin a shot to keep it."
                         : "They stay in \(folderName) like any other screenshot.")
                }
                .pickerStyle(.segmented)
                Picker("Remove screenshots after", selection: $preferences.retention) {
                    ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            } header: {
                Text("Files")
            } footer: {
                Text("Removed screenshots go to the Trash, so Finder’s Put Back still works. Pinned ones are always kept.")
            }

            Section("Notch") {
                Toggle(isOn: $preferences.opensOnHover) {
                    Text("Open on hover")
                    Text("When off, click the notch to open it.")
                }
                Toggle(isOn: $preferences.showsLatestWhenIdle) {
                    Text("Show latest shot when idle")
                    Text("Your newest screenshot, beside the notch.")
                }
                Picker(selection: $preferences.notchDisplay) {
                    ForEach(NotchDisplay.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Show on")
                    Text("The display the notch lives on. Previews appear there too.")
                }
                .pickerStyle(.segmented)
            }

            Section("System") {
                Toggle("Open Pluck at login", isOn: Binding(get: { opensAtLogin }, set: { on in
                    LaunchAtLogin.set(on)
                    opensAtLogin = LaunchAtLogin.isEnabled
                }))
                if LaunchAtLogin.needsApproval {
                    LabeledContent("Allow Pluck in Login Items to finish") {
                        Button("Open System Settings") { LaunchAtLogin.openSystemSettings() }
                    }
                }
                Toggle(isOn: $preferences.showsMenuBarIcon) {
                    Text("Show in menu bar")
                    Text("Your way in when a full-screen app hides the notch. Hidden, open Pluck again for Settings.")
                }
            }

            Section {
                LabeledContent("\(folderName) folder") {
                    if library.canReadFolder {
                        Text("Allowed").foregroundStyle(.secondary)
                    } else {
                        Button("Open System Settings") { NSWorkspace.shared.open(.filesAndFoldersSettings) }
                    }
                }
            } header: {
                Text("Access")
            } footer: {
                Text(library.canReadFolder
                     ? "Screenshots never leave your Mac."
                     : "Pluck can’t see new screenshots until it’s allowed to read \(folderName).")
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { setup.setSaveFolder(folder) }
        }
        .onAppear { opensAtLogin = LaunchAtLogin.isEnabled }
    }
}

/// "Save screenshots to": the usual places, the current folder if it's elsewhere,
/// and any folder at all.
private struct SaveFolderPicker: View {
    let setup: ScreenshotSetup
    @Binding var choosingFolder: Bool

    private enum Choice: Hashable {
        case folder(String)
        case choose
    }

    var body: some View {
        let current = Self.path(setup.saveFolder)
        let usual = [URL.desktopDirectory, .downloadsDirectory, URL.picturesDirectory.appending(path: "Screenshots")].map(Self.path)
        Picker("Save screenshots to", selection: Binding(get: { Choice.folder(current) }, set: { choice in
            switch choice {
            case .folder(let path): setup.setSaveFolder(URL(filePath: path, directoryHint: .isDirectory))
            case .choose: choosingFolder = true
            }
        })) {
            ForEach(usual.contains(current) ? usual : usual + [current], id: \.self) { path in
                Text(FileManager.default.displayName(atPath: path)).tag(Choice.folder(path))
            }
            Divider()
            Text("Choose Folder…").tag(Choice.choose)
        }
    }

    /// One spelling per folder, so the same folder always matches itself.
    private static func path(_ folder: URL) -> String {
        (folder.path(percentEncoded: false) as NSString).standardizingPath
    }
}

private extension Retention {
    var title: String {
        switch self {
        case .oneDay: "1 day"
        case .sevenDays: "7 days"
        case .thirtyDays: "30 days"
        case .never: "Never"
        }
    }
}

private extension NotchDisplay {
    var title: String {
        switch self {
        case .builtIn: "Built-in"
        case .main: "Main"
        case .withMouse: "With mouse"
        }
    }
}

private extension URL {
    static let filesAndFoldersSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
}
