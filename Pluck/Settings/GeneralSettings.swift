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
                Picker(selection: Binding(get: { preferences.preview }, set: { setup.setPreview($0) })) {
                    Text("Pluck").tag(PreviewStyle.pluck)
                    Text("macOS").tag(PreviewStyle.macOS)
                } label: {
                    Text("Preview")
                    Text(preferences.preview == .pluck
                         ? "Appears in the notch, ready to copy, mark up, pin or drag anywhere."
                         : "The standard macOS thumbnail, in the corner of the screen.")
                }
                .pickerStyle(.segmented)
                if preferences.preview == .pluck {
                    PreviewDurationPicker(preferences: preferences)
                }
            } header: {
                Text("Screenshots")
            } footer: {
                Text("Pluck manages these macOS screenshot settings for you. You can restore your originals any time in About.")
            }

            Section {
                DragOutPicker(preferences: preferences, folderName: folderName)
                RetentionPicker(preferences: preferences)
            } header: {
                Text("Cleanup")
            } footer: {
                Text("Pinned screenshots are never removed, and anything moved to the Trash can be put back from there.")
            }

            Section("Notch") {
                Toggle(isOn: $preferences.opensOnHover) {
                    Text("Open on hover")
                    Text("Rest the pointer on the notch to see recent screenshots. When off, click the notch instead.")
                }
                Toggle(isOn: $preferences.showsLatestWhenIdle) {
                    Text("Show latest screenshot")
                    Text("A small thumbnail beside the notch.")
                }
                Picker(selection: $preferences.notchDisplay) {
                    ForEach(NotchDisplay.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Show on")
                    Text("Where the notch and previews appear.")
                }
            }

            Section("System") {
                Toggle("Open Pluck at login", isOn: Binding(get: { opensAtLogin }, set: { on in
                    LaunchAtLogin.set(on)
                    opensAtLogin = LaunchAtLogin.isEnabled
                }))
                if LaunchAtLogin.needsApproval {
                    LabeledContent("Allow Pluck in Login Items to finish setting this up") {
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    }
                }
                Toggle(isOn: $preferences.showsMenuBarIcon) {
                    Text("Show in menu bar")
                    Text("Pluck’s menu, with Settings and Quit. If it’s hidden, open Pluck again to get back here.")
                }
            }

            // Only while there's something to fix: the folder is the one permission.
            if library.canReadFolder == false {
                Section {
                    LabeledContent("Access to \(folderName)") {
                        Button("Allow in System Settings…") { NSWorkspace.shared.open(.filesAndFoldersSettings) }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Pluck needs access to \(folderName) to show your new screenshots.")
                }
            }
        }
        .formStyle(.grouped)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { setup.setSaveFolder(folder) }
        }
        .onAppear { opensAtLogin = LaunchAtLogin.isEnabled }
    }
}

// The rows onboarding shares, so a choice reads the same in both places.

/// "Save to": the usual places, the current folder if it's elsewhere,
/// and any folder at all.
struct SaveFolderPicker: View {
    let setup: ScreenshotSetup
    @Binding var choosingFolder: Bool

    private enum Choice: Hashable {
        case folder(String)
        case choose
    }

    var body: some View {
        let current = Self.path(setup.saveFolder)
        let usual = [URL.desktopDirectory, .downloadsDirectory, URL.picturesDirectory.appending(path: "Screenshots")].map(Self.path)
        Picker("Save to", selection: Binding(get: { Choice.folder(current) }, set: { choice in
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

struct PreviewDurationPicker: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Picker(selection: $preferences.previewDuration) {
            ForEach(PreviewDuration.allCases, id: \.self) { Text("\(Int($0.rawValue)) sec").tag($0) }
        } label: {
            Text("Show preview for")
            Text("Hover over the preview to keep it open.")
        }
        .pickerStyle(.segmented)
    }
}

struct DragOutPicker: View {
    @Bindable var preferences: Preferences
    let folderName: String

    var body: some View {
        Picker(selection: $preferences.removeDraggedOut) {
            Text("Keep").tag(false)
            Text("Remove").tag(true)
        } label: {
            Text("When dragged into an app")
            Text(preferences.removeDraggedOut
                 ? "Screenshots leave \(folderName) once you drop them into another app. Pinned ones stay."
                 : "Screenshots stay in \(folderName) after you drop them into another app.")
        }
        .pickerStyle(.segmented)
    }
}

struct RetentionPicker: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Picker("Move to Trash after", selection: $preferences.retention) {
            ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
        }
        .pickerStyle(.segmented)
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
        case .builtIn: "Built-in Display"
        case .main: "Main Display"
        }
    }
}

extension URL {
    static let filesAndFoldersSettings = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_FilesAndFolders")!
}
