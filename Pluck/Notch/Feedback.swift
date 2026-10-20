import SwiftUI

/// A short confirmation of what the user just did, shown in the notch's one
/// feedback slot. A new one replaces the old.
struct Feedback: Equatable {
    enum Kind: Equatable {
        case copied, pinned, unpinned, trashed, restored
    }

    let kind: Kind
    var count = 1

    var canUndo: Bool { kind == .trashed }

    var duration: TimeInterval {
        canUndo ? Theme.Timing.feedbackWithUndo : Theme.Timing.feedback
    }

    var text: String {
        let many = count > 1 ? " \(count)" : ""
        switch kind {
        case .copied: return "Copied" + many
        case .pinned: return "Pinned" + many
        case .unpinned: return "Unpinned"
        case .trashed: return "Trashed" + many
        case .restored: return "Restored"
        }
    }

    var symbol: String {
        switch kind {
        case .copied, .restored: "checkmark.circle.fill"
        case .pinned, .unpinned: "pin.fill"
        case .trashed: "trash.fill"
        }
    }

    var tint: Color {
        switch kind {
        case .copied, .restored: Theme.Palette.copied
        case .pinned, .unpinned: Theme.Palette.pinned
        case .trashed: Theme.Palette.trashed
        }
    }
}
