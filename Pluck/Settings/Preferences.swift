import Foundation

/// The user's settings. Each property saves itself when it changes; defaults
/// follow the engineering spec in the Settings design.
@Observable final class Preferences {
    var retention: Retention {
        didSet { defaults.set(retention.rawValue, forKey: Key.retention) }
    }

    /// "Shots you drag out": remove them an hour after the drag.
    var removeDraggedOut: Bool {
        didSet { defaults.set(removeDraggedOut, forKey: Key.removeDraggedOut) }
    }

    @ObservationIgnored private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        retention = defaults.string(forKey: Key.retention).flatMap(Retention.init) ?? .sevenDays
        removeDraggedOut = defaults.object(forKey: Key.removeDraggedOut) as? Bool ?? true
    }

    private enum Key {
        static let retention = "retention"
        static let removeDraggedOut = "removeDraggedOut"
    }
}
