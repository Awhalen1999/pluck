import AVKit
import SwiftUI

/// The first run, in five steps: the welcome, where screenshots go, which
/// preview shows them, a few defaults, and the first screenshot. A choice that
/// changes macOS takes effect on Continue, never before: the save folder (or as
/// soon as its access is asked for), the preview, the login item.
struct OnboardingView: View {
    let preferences: Preferences
    let setup: ScreenshotSetup
    let library: ShotLibrary
    let finish: () -> Void

    @State private var step: Step
    /// Where screenshots will go. With no folder chosen yet, macOS's Screenshots
    /// folder rather than its default, the Desktop: tidier, and no permission.
    @State private var folder: URL
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
        _folder = State(initialValue: setup.hasChosenFolder ? setup.saveFolder : .screenshotsFolder)
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
            if case .success(let chosen) = result { folder = chosen }
        }
    }

    // MARK: Steps

    private var welcome: some View {
        VStack(spacing: Theme.Space.xl) {
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .frame(width: Theme.Onboarding.iconSize, height: Theme.Onboarding.iconSize)
            header("Welcome to Pluck",
                   "Pluck keeps your screenshots in the notch, ready to copy or drag into any app, and clears out the old ones for you.",
                   font: Theme.Onboarding.welcomeTitle)
            PromoVideo()
                .frame(width: Theme.Onboarding.videoSize.width, height: Theme.Onboarding.videoSize.height)
                .clipShape(.rect(cornerRadius: Theme.Radius.card))
        }
    }

    private var saveLocation: some View {
        let path = folder.path(percentEncoded: false)
        let name = FileManager.default.displayName(atPath: path)
        return choices("Choose a folder",
                       "macOS saves your screenshots here. Pluck works only with screenshots and leaves other files alone.") {
            Section {
                LabeledContent {
                    Menu("Change") {
                        SaveFolderPicker(folder: folder, choose: { folder = $0 }, choosingFolder: $choosingFolder)
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
                if access != .notNeeded { folderAccess }
            } footer: {
                Label("Your screenshots never leave your Mac.", systemImage: "lock")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var folderAccess: some View {
        LabeledContent {
            switch access {
            case .ask:
                Button("Allow Access…") {
                    useFolder()
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
            case .ask: Text("macOS asks once before Pluck can see this folder.")
            case .denied: Text("Pluck needs this to see new screenshots.").foregroundStyle(Theme.Palette.denied)
            case .notNeeded, .allowed: Text("Pluck can see new screenshots here.")
            }
        }
    }

    private var previewChoice: some View {
        choices("Choose a preview", "What appears after you take a screenshot.") {
            Section {
                HStack(alignment: .top, spacing: Theme.Space.l) {
                    choice(.pluck, "Pluck preview")
                    choice(.macOS, "macOS thumbnail")
                }
                .fixedSize(horizontal: false, vertical: true)
                if preview == .pluck { PreviewDurationPicker(preferences: preferences) }
            } footer: {
                Text(preview == .pluck
                     ? "Pluck turns off the macOS thumbnail while it runs."
                     : "Pluck leaves your macOS settings as they are.")
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private func choice(_ style: PreviewStyle, _ title: String) -> some View {
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
                Text(style.detail)
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
        choices("Set your defaults", "You can change these any time in Settings.") {
            Section {
                Toggle("Open Pluck at login", isOn: $opensAtLogin)
                DragOutPicker(preferences: preferences)
                RetentionPicker(preferences: preferences)
            } footer: {
                Text("Screenshots from before Pluck are never cleaned up.").frame(maxWidth: .infinity)
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
                header("Take a screenshot", "Press ⇧⌘4, then drag over any part of the screen.")
                ShortcutArt()
                    .padding(.horizontal, Theme.Onboarding.inset)
            } else {
                choices("You’re all set", "Here’s how to get to your screenshots.") {
                    Section {
                        tip("Hover over the notch", "See your latest screenshots.", symbol: "cursorarrow")
                        tip("Click the notch", "See all of them, and pin the ones to keep.", symbol: "cursorarrow.click")
                        tip("Drag a screenshot", "Drop it into any app or folder.", symbol: "hand.draw")
                    } footer: {
                        Text("Settings are in the Pluck menu, in the menu bar.").frame(maxWidth: .infinity)
                    }
                }
            }
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

    private func tip(_ title: String, _ detail: String, symbol: String) -> some View {
        Label {
            Text(title)
            Text(detail)
        } icon: {
            Image(systemName: symbol).foregroundStyle(.tint)
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
                Button(step == .welcome ? "Get Started" : step == .firstScreenshot ? "Done" : "Continue", action: next)
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
            useFolder()
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

    /// Gives macOS the folder shown, if it doesn't have it already.
    private func useFolder() {
        if folder.standardPath != setup.saveFolder.standardPath { setup.setSaveFolder(folder) }
    }

    private enum Access { case notNeeded, ask, allowed, denied }

    /// Pluck hasn't looked in the folder until onboarding asks for it, and knows
    /// nothing about one macOS doesn't have yet.
    private var access: Access {
        let canRead = folder.standardPath == setup.saveFolder.standardPath ? library.canReadFolder : nil
        switch (canRead, folder.isPrivacyProtected) {
        case (false?, _): return .denied
        case (nil, true): return .ask
        case (_, false): return .notNeeded
        case (true?, true): return .allowed
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
        [URL.desktopDirectory, .documentsDirectory, .downloadsDirectory].contains { protected in
            standardPath == protected.standardPath || standardPath.hasPrefix(protected.standardPath + "/")
        }
    }
}
