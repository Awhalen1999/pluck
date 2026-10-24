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
                SaveFolderPicker(folder: setup.saveFolder, choose: { setup.setSaveFolder($0) }, choosingFolder: $choosingFolder)
                Picker(selection: Binding(get: { preferences.preview }, set: { setup.setPreview($0) })) {
                    Text("Pluck").tag(PreviewStyle.pluck)
                    Text("macOS").tag(PreviewStyle.macOS)
                } label: {
                    Text("Preview")
                    Text(preferences.preview.detail)
                }
                .pickerStyle(.segmented)
                if preferences.preview == .pluck {
                    PreviewDurationPicker(preferences: preferences)
                }
            } header: {
                Text("Screenshots")
            } footer: {
                Text("These are your macOS screenshot settings. You can restore the originals in About.")
            }

            Section {
                DragOutPicker(preferences: preferences)
                RetentionPicker(preferences: preferences)
            } header: {
                Text("Cleanup")
            } footer: {
                Text("Screenshots from before Pluck are never cleaned up. Anything moved to the Trash can be put back.")
            }

            Section("Notch") {
                Toggle(isOn: $preferences.opensOnHover) {
                    Text("Open on hover")
                    Text("Rest the pointer on the notch to see recent screenshots. When off, click it instead.")
                }
                Toggle(isOn: $preferences.showsLatestWhenIdle) {
                    Text("Show latest screenshot")
                    Text("A small thumbnail beside the notch.")
                }
                Picker(selection: $preferences.notchDisplay) {
                    ForEach(NotchDisplay.allCases, id: \.self) { Text($0.title).tag($0) }
                } label: {
                    Text("Show on")
                    Text("The display where the notch and previews appear.")
                }
            }

            Section("System") {
                Toggle("Open Pluck at login", isOn: Binding(get: { opensAtLogin }, set: { on in
                    LaunchAtLogin.set(on)
                    opensAtLogin = LaunchAtLogin.isEnabled
                }))
                if LaunchAtLogin.needsApproval {
                    LabeledContent {
                        Button("Open Login Items") { LaunchAtLogin.openSystemSettings() }
                    } label: {
                        Text("Waiting for your approval")
                        Text("Allow Pluck in Login Items to open it at login.")
                    }
                }
                Toggle(isOn: $preferences.showsMenuBarIcon) {
                    Text("Show in menu bar")
                    Text("Pluck’s menu, with Settings and Quit. If you hide it, open Pluck again to get back here.")
                }
            }

            // Only while there's something to fix: the folder is the one permission.
            if library.canReadFolder == false {
                Section {
                    LabeledContent("Access to \(folderName)") {
                        Button("Open System Settings") { NSWorkspace.shared.open(.filesAndFoldersSettings) }
                    }
                } header: {
                    Text("Permissions")
                } footer: {
                    Text("Pluck needs access to \(folderName) to see new screenshots.")
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
    let folder: URL
    let choose: (URL) -> Void
    @Binding var choosingFolder: Bool

    private enum Choice: Hashable {
        case folder(String)
        case choose
    }

    var body: some View {
        let current = folder.standardPath
        let usual = [URL.desktopDirectory, .downloadsDirectory, .screenshotsFolder].map(\.standardPath)
        Picker("Save to", selection: Binding(get: { Choice.folder(current) }, set: { choice in
            switch choice {
            case .folder(let path): choose(URL(filePath: path, directoryHint: .isDirectory))
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

    var body: some View {
        Picker(selection: $preferences.removeDraggedOut) {
            Text("Keep").tag(false)
            Text("Remove").tag(true)
        } label: {
            Text("When dragged into an app")
            Text(preferences.removeDraggedOut
                 ? "Screenshots you drop into an app are removed from your folder. Pinned ones stay."
                 : "Screenshots you drop into an app stay in your folder.")
        }
        .pickerStyle(.segmented)
    }
}

struct RetentionPicker: View {
    @Bindable var preferences: Preferences

    var body: some View {
        Picker(selection: $preferences.retention) {
            ForEach(Retention.allCases, id: \.self) { Text($0.title).tag($0) }
        } label: {
            Text("Move to Trash after")
            Text("Pinned screenshots are always kept.")
        }
        .pickerStyle(.segmented)
    }
}

extension PreviewStyle {
    /// What each preview is, in one line.
    var detail: String {
        switch self {
        case .pluck: "Shows in the notch, ready to copy, pin, or drag into any app."
        case .macOS: "The standard thumbnail in the corner of the screen."
        }
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
    /// macOS's own Screenshots folder. Outside Desktop, Documents and Downloads,
    /// so using it needs no permission.
    static let screenshotsFolder = URL.picturesDirectory.appending(path: "Screenshots", directoryHint: .isDirectory)

    /// One spelling per folder, so the same folder always matches itself.
    var standardPath: String { (path(percentEncoded: false) as NSString).standardizingPath }
}
