import AVKit
import SwiftUI

/// The first run, in five steps: the welcome, where screenshots go, which
/// preview shows them, a few defaults, and the first screenshot. A choice that
/// changes macOS takes effect when it's made, never before: the save folder
/// when it's picked, the preview and login item on Continue.
struct OnboardingView: View {
    let preferences: Preferences
    let setup: ScreenshotSetup
    let library: ShotLibrary
    let finish: () -> Void

    @State private var step: Step
    @State private var preview = PreviewStyle.pluck
    @State private var opensAtLogin = true
    @State private var choosingFolder = false
    /// When the last step began. A screenshot taken after it is the user's first.
    @State private var waitingSince = Date.now
    @State private var firstShot: Shot?

    private enum Step: Int, CaseIterable {
        case welcome, saveLocation, preview, defaults, firstScreenshot
    }

    init(preferences: Preferences, setup: ScreenshotSetup, library: ShotLibrary, finish: @escaping () -> Void) {
        self.preferences = preferences
        self.setup = setup
        self.library = library
        self.finish = finish
        _step = State(initialValue: preferences.onboarding == .new ? .welcome : .saveLocation)
    }

    var body: some View {
        VStack(spacing: 0) {
            Group {
                switch step {
                case .welcome: welcome
                case .saveLocation: saveLocation
                case .preview: previewChoice
                case .defaults: defaults
                case .firstScreenshot: firstScreenshot
                }
            }
            .padding(.top, Theme.Space.xl)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            Divider()
            footer
        }
        .frame(width: Theme.Onboarding.size.width, height: Theme.Onboarding.size.height)
        .fileImporter(isPresented: $choosingFolder, allowedContentTypes: [.folder]) { result in
            if case .success(let folder) = result { setup.setSaveFolder(folder) }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: Theme.Space.xl) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Theme.Onboarding.iconSize, height: Theme.Onboarding.iconSize)
            header("Welcome to Pluck",
                   "Your screenshots, right in the notch. Drag them anywhere, copy in a click, and old ones clean themselves up.",
                   font: Theme.Onboarding.welcomeTitle)
            PromoVideo()
                .frame(width: Theme.Onboarding.videoSize.width, height: Theme.Onboarding.videoSize.height)
                .clipShape(.rect(cornerRadius: Theme.Radius.card))
        }
    }

    private var saveLocation: some View {
        let path = setup.saveFolder.path(percentEncoded: false)
        let name = FileManager.default.displayName(atPath: path)
        return choices("Where should screenshots go?",
                       "Pluck uses your Mac’s screenshot folder and only picks up real screenshots, so other files in it are left alone.") {
            Section {
                LabeledContent {
                    Menu("Change") {
                        SaveFolderPicker(setup: setup, choosingFolder: $choosingFolder)
                            .pickerStyle(.inline)
                            .labelsHidden()
                    }
                    .fixedSize()
                } label: {
                    Label {
                        Text(name)
                        Text((path as NSString).abbreviatingWithTildeInPath)
                    } icon: {
                        Image(nsImage: NSWorkspace.shared.icon(for: .folder))
                    }
                }
                folderAccess(name: name)
            } footer: {
                Label("Changing it here also changes ⇧⌘5 → Options. Nothing leaves your Mac.", systemImage: "lock")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func folderAccess(name: String) -> some View {
        LabeledContent {
            switch access {
            case .ask:
                Button("Allow Access…") {
                    Task {
                        await library.requestAccess()
                        // After its prompt macOS goes back to the app the user was in
                        // before, never to a menu bar app, and refuses a plain activate.
                        NSApp.activate(ignoringOtherApps: true)
                    }
                }
            case .denied: Button("Open System Settings") { NSWorkspace.shared.open(.filesAndFoldersSettings) }
            case .notNeeded, .allowed: Label("Allowed", systemImage: "checkmark").foregroundStyle(Theme.Palette.allowed)
            }
        } label: {
            Text("Folder access")
            switch access {
            case .ask: Text("macOS protects your \(name) folder, so it will ask once.")
            case .denied: Text("Pluck can’t see new screenshots without this.").foregroundStyle(Theme.Palette.denied)
            case .notNeeded: Text("No permission needed for this folder.")
            case .allowed: Text("Pluck can see new screenshots here.")
            }
        }
    }

    private var previewChoice: some View {
        choices("Choose your preview", "What you see right after you take a screenshot.") {
            Section {
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    choice(.pluck, "Pluck preview",
                           "A live preview in the notch with Copy, Markup, Pin and Trash. Drag it straight into any app.")
                    choice(.macOS, "macOS thumbnail", "Apple’s standard corner thumbnail, with Markup.")
                }
                .fixedSize(horizontal: false, vertical: true)
                if preview == .pluck { PreviewDurationPicker(preferences: preferences) }
            } footer: {
                Text(preview == .pluck
                     ? "Pluck turns off the macOS floating thumbnail so the two don’t overlap."
                     : "Pluck leaves your macOS settings as they are.")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func choice(_ style: PreviewStyle, _ title: String, _ detail: String) -> some View {
        let chosen = preview == style
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        return Button { preview = style } label: {
            VStack(alignment: .leading, spacing: Theme.Space.s) {
                PreviewArt(style: style)
                HStack(spacing: Theme.Space.s) {
                    Image(systemName: chosen ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(chosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.tertiary))
                    Text(title).font(Theme.Typography.title)
                    if style == .pluck {
                        Text("Recommended")
                            .font(Theme.Typography.badge)
                            .foregroundStyle(.tint)
                            .padding(.horizontal, Theme.Space.xs)
                            .background(.tint.quaternary, in: .rect(cornerRadius: Theme.Radius.mini))
                    }
                }
                Text(detail)
                    .font(Theme.Typography.detail)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Theme.Space.s)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .overlay {
                shape.strokeBorder(chosen ? AnyShapeStyle(.tint) : AnyShapeStyle(.separator),
                                   lineWidth: chosen ? Theme.Tile.selectedRingWidth : Theme.Tile.hoverRingWidth)
            }
            .contentShape(shape)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(chosen ? .isSelected : [])
    }

    private var defaults: some View {
        let name = FileManager.default.displayName(atPath: setup.saveFolder.path(percentEncoded: false))
        return choices("Make it yours", "A few defaults. Change anything later in Settings.") {
            Section {
                Toggle("Open Pluck at login", isOn: $opensAtLogin)
                DragOutPicker(preferences: preferences, folderName: name)
                RetentionPicker(preferences: preferences)
            } footer: {
                Text("Pinned screenshots are always kept.").frame(maxWidth: .infinity)
            }
        }
    }

    private var firstScreenshot: some View {
        VStack(spacing: Theme.Space.xl) {
            Image(systemName: firstShot == nil ? "viewfinder" : "checkmark")
                .font(Theme.Onboarding.statusFont)
                .foregroundStyle(firstShot == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))
                .frame(width: Theme.Onboarding.statusSize, height: Theme.Onboarding.statusSize)
                .background(firstShot == nil ? AnyShapeStyle(.fill.tertiary) : AnyShapeStyle(.tint), in: .circle)
            if firstShot == nil {
                header("Take your first screenshot", "Press ⇧⌘4 and drag over anything. It will show up in the notch.")
            } else {
                header("You’re all set", "Pluck lives in your notch. Hover there any time to see your screenshots.")
            }
            FirstShotArt(shot: firstShot)
                .padding(.horizontal, Theme.Onboarding.inset)
        }
        .onAppear { waitingSince = .now }
        .onChange(of: library.pending.first ?? library.shots.first) { _, newest in
            if firstShot == nil, let newest, newest.capturedAt >= waitingSince { firstShot = newest }
        }
    }

    // MARK: Parts

    private func header(_ title: String, _ message: String, font: Font = Theme.Onboarding.title) -> some View {
        VStack(spacing: Theme.Space.s) {
            Text(title).font(font)
            Text(message)
                .foregroundStyle(.secondary)
                .frame(maxWidth: Theme.Onboarding.messageWidth)
        }
        .multilineTextAlignment(.center)
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, Theme.Onboarding.inset)
    }

    /// A step with choices: its header, then native rows, as in Settings.
    private func choices(_ title: String, _ message: String, @ViewBuilder rows: () -> some View) -> some View {
        VStack(spacing: 0) {
            header(title, message)
            Form { rows() }
                .formStyle(.grouped)
                .scrollContentBackground(.hidden)
                .scrollDisabled(true)
        }
    }

    private var footer: some View {
        ZStack {
            HStack(spacing: Theme.Space.s) {
                ForEach(Step.allCases, id: \.self) { dot in
                    Capsule()
                        .fill(dot.rawValue <= step.rawValue ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.secondary))
                        .frame(width: dot == step ? Theme.Onboarding.currentDotWidth : Theme.Onboarding.dot,
                               height: Theme.Onboarding.dot)
                }
            }
            HStack {
                if step != .welcome {
                    Button("Back") { step = Step(rawValue: step.rawValue - 1)! }
                        .buttonStyle(.borderless)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(step == .welcome ? "Get Started" : step == .firstScreenshot ? "Open Pluck" : "Continue", action: next)
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!canContinue)
            }
        }
        .controlSize(.large)
        .padding(Theme.Space.xl)
    }

    // MARK: Flow

    private var canContinue: Bool {
        switch step {
        case .saveLocation: access == .notNeeded || access == .allowed
        case .firstScreenshot: firstShot != nil
        default: true
        }
    }

    private func next() {
        switch step {
        case .welcome:
            preferences.onboarding = .started
        case .saveLocation:
            library.start()
            // A folder that turned out to be protected after all just asked.
            guard library.canReadFolder == true else { return }
        case .preview:
            setup.setPreview(preview)
        case .defaults:
            LaunchAtLogin.set(opensAtLogin)
        case .firstScreenshot:
            preferences.onboarding = .finished
            finish()
            return
        }
        step = Step(rawValue: step.rawValue + 1)!
    }

    private enum Access { case notNeeded, ask, allowed, denied }

    /// Pluck hasn't looked in the folder until onboarding asks for it.
    private var access: Access {
        switch (library.canReadFolder, setup.saveFolder.isPrivacyProtected) {
        case (false?, _): .denied
        case (nil, true): .ask
        case (_, false): .notNeeded
        case (true?, true): .allowed
        }
    }
}

/// The promo, muted and on a loop. Under Reduce Motion it waits for a click on play.
private struct PromoVideo: NSViewRepresentable {
    func makeNSView(context: Context) -> AVPlayerView {
        let view = AVPlayerView()
        view.player = context.coordinator.player
        if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion {
            view.controlsStyle = .minimal
        } else {
            view.controlsStyle = .none
            context.coordinator.player.play()
        }
        return view
    }

    func updateNSView(_ view: AVPlayerView, context: Context) {}

    static func dismantleNSView(_ view: AVPlayerView, coordinator: Loop) {
        coordinator.player.pause()
    }

    func makeCoordinator() -> Loop { Loop() }

    /// The player, and the looper that keeps it going for as long as the view.
    final class Loop {
        let player = AVQueuePlayer()
        private let looper: AVPlayerLooper

        init() {
            looper = AVPlayerLooper(player: player, templateItem: AVPlayerItem(url: Bundle.main.url(forResource: "Promo", withExtension: "mp4")!))
            player.isMuted = true
        }
    }
}

private extension URL {
    /// Desktop, Documents and Downloads, and folders in them: macOS asks the user
    /// before an app reads these.
    // ponytail: iCloud Drive and other volumes ask too; chosen here, they ask at Continue.
    var isPrivacyProtected: Bool {
        let path = (path(percentEncoded: false) as NSString).standardizingPath
        return [URL.desktopDirectory, .documentsDirectory, .downloadsDirectory].contains { folder in
            let protected = (folder.path(percentEncoded: false) as NSString).standardizingPath
            return path == protected || path.hasPrefix(protected + "/")
        }
    }
}
