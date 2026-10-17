import Foundation

/// How long Pluck keeps screenshots: Settings, "Remove screenshots after".
enum Retention: String, CaseIterable {
    case oneDay, sevenDays, thirtyDays, never

    var duration: TimeInterval? {
        switch self {
        case .oneDay: 1 * 86_400
        case .sevenDays: 7 * 86_400
        case .thirtyDays: 30 * 86_400
        case .never: nil
        }
    }
}

enum Cleanup {
    /// Time between a drag into another app and removal, so the app can finish
    /// reading the file.
    static let dragOutGrace: TimeInterval = 60 * 60

    /// How often cleanup runs while Pluck is open.
    static let interval: Duration = .seconds(5 * 60)

    /// The shots cleanup should move to the Trash at `now`.
    /// - Pinned shots are never included.
    /// - Shots taken before Pluck first ran are never included.
    /// - A shot's age counts from its capture, or from when it was last unpinned,
    ///   so unpinning an old shot doesn't make it vanish at once.
    static func expired(_ shots: [Shot], index: ShotIndex, retention: Retention,
                        removeDraggedOut: Bool, now: Date) -> [Shot] {
        shots.filter { shot in
            guard !index.pinned.contains(shot.id),
                  let managedSince = index.managedSince, shot.capturedAt >= managedSince
            else { return false }
            if removeDraggedOut, let dragged = index.draggedOut[shot.id],
               now.timeIntervalSince(dragged) >= dragOutGrace {
                return true
            }
            guard let keep = retention.duration else { return false }
            let start = max(shot.capturedAt, index.unpinned[shot.id] ?? .distantPast)
            return now.timeIntervalSince(start) >= keep
        }
    }
}
