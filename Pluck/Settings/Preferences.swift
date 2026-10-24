import Foundation

/// The user's settings. Each property saves itself when it changes; defaults
/// follow the engineering spec in the Settings design.
@Observable final class Preferences {
    var retention: Retention {
        didSet { defaults.set(retention.rawValue, forKey: Key.retention) }
    }

    /// "When dragged into an app": Remove hands shots off, leaving Pluck once dropped. Pinned shots stay.
    var removeDraggedOut: Bool {
        didSet { defaults.set(removeDraggedOut, forKey: Key.removeDraggedOut) }
    }

    /// "Open on hover". When off, a click opens the notch.
    var opensOnHover: Bool {
        didSet { defaults.set(opensOnHover, forKey: Key.opensOnHover) }
    }

    /// "Show latest screenshot", beside the notch.
    var showsLatestWhenIdle: Bool {
        didSet { defaults.set(showsLatestWhenIdle, forKey: Key.showsLatestWhenIdle) }
    }

    /// "Show on": which display the notch lives on. Previews appear there too.
    var notchDisplay: NotchDisplay {
        didSet { defaults.set(notchDisplay.rawValue, forKey: Key.notchDisplay) }
    }

    /// "Show in menu bar". When it's hidden, opening Pluck again opens Settings.
    var showsMenuBarIcon: Bool {
        didSet { defaults.set(showsMenuBarIcon, forKey: Key.showsMenuBarIcon) }
    }

    /// "Preview": Pluck's own in the notch, or the macOS floating thumbnail. Set
    /// through `ScreenshotSetup`, which makes macOS match. Until the user chooses
    /// in onboarding it's the macOS one: Pluck changes nothing without a choice.
    var preview: PreviewStyle {
        didSet { defaults.set(preview.rawValue, forKey: Key.preview) }
    }

    /// "Show preview for".
    var previewDuration: PreviewDuration {
        didSet { defaults.set(previewDuration.rawValue, forKey: Key.previewDuration) }
    }

    /// How far the first run got. Not a setting: it decides whether onboarding
    /// shows, and where it opens.
    var onboarding: OnboardingProgress {
        didSet { defaults.set(onboarding.rawValue, forKey: Key.onboarding) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        retention = defaults.string(forKey: Key.retention).flatMap(Retention.init) ?? .sevenDays
        removeDraggedOut = defaults.object(forKey: Key.removeDraggedOut) as? Bool ?? false
        opensOnHover = defaults.object(forKey: Key.opensOnHover) as? Bool ?? true
        showsLatestWhenIdle = defaults.object(forKey: Key.showsLatestWhenIdle) as? Bool ?? false
        notchDisplay = defaults.string(forKey: Key.notchDisplay).flatMap(NotchDisplay.init) ?? .builtIn
        showsMenuBarIcon = defaults.object(forKey: Key.showsMenuBarIcon) as? Bool ?? true
        preview = defaults.string(forKey: Key.preview).flatMap(PreviewStyle.init) ?? .macOS
        previewDuration = PreviewDuration(rawValue: defaults.double(forKey: Key.previewDuration)) ?? .four
        onboarding = defaults.string(forKey: Key.onboarding).flatMap(OnboardingProgress.init) ?? .new
    }

    private enum Key {
        static let retention = "retention"
        static let removeDraggedOut = "removeDraggedOut"
        static let opensOnHover = "opensOnHover"
        static let showsLatestWhenIdle = "showsLatestWhenIdle"
        static let notchDisplay = "notchDisplay"
        static let showsMenuBarIcon = "showsMenuBarIcon"
        static let preview = "preview"
        static let previewDuration = "previewDuration"
        static let onboarding = "onboarding"
    }
}

enum NotchDisplay: String, CaseIterable {
    /// The laptop's own screen, where the notch is. Falls back to the main
    /// display when the lid is closed.
    case builtIn
    /// The display with the menu bar in System Settings' arrangement.
    case main
}

enum PreviewStyle: String, CaseIterable {
    case pluck, macOS
}

enum PreviewDuration: Double, CaseIterable {
    case two = 2, four = 4, six = 6
}

enum OnboardingProgress: String {
    /// It opens on the welcome: the first launch, or after "Show the welcome again".
    case new
    /// Quit partway: it opens again on its first choice, the save location.
    case started
    case finished
}
