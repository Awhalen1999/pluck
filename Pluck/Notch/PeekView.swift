import SwiftUI

/// A glance at the newest shots, from hovering the notch. Clicking one copies
/// it; "+N" or a click anywhere else opens the Shelf.
struct PeekView: View {
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let shots = controller.library.shots
        VStack(spacing: 0) {
            NotchHeader(notchWidth: notchWidth) {
                if let shot = controller.hoveredShot.flatMap({ id in shots.first { $0.id == id } }) {
                    Text(shot.detail)
                }
            } trailing: {
                if let feedback = controller.feedback { FeedbackLabel(feedback: feedback, controller: controller) }
            }
            if shots.isEmpty {
                NoShotsYet().frame(height: Theme.Notch.controlHeight)
            } else {
                HStack(spacing: Theme.Space.s) {
                    ForEach(NotchLayout.peekShots(shots)) { shot in
                        ShotTile(shot: shot, size: Theme.Notch.peekTile, controller: controller)
                    }
                    if shots.count > Theme.Notch.peekTileCount {
                        MoreTile(count: shots.count - Theme.Notch.peekTileCount, controller: controller)
                    }
                }
            }
        }
    }
}

/// "+N": the shots Peek has no room for. Opens the Shelf.
private struct MoreTile: View {
    let count: Int
    let controller: NotchController

    var body: some View {
        Button { controller.clickedNotch() } label: {
            Text("+\(count)")
                .font(Theme.Typography.badge)
                .foregroundStyle(.secondary)
                .frame(width: Theme.Notch.peekMoreWidth, height: Theme.Notch.peekTile.height)
                .background(.fill.quaternary, in: .rect(cornerRadius: Theme.Radius.tile, style: .continuous))
        }
        .buttonStyle(PressableStyle())
        .accessibilityLabel("\(count) more screenshots")
        .accessibilityHint("Opens the Shelf")
    }
}

/// What Peek and the Shelf say before there's anything to show.
struct NoShotsYet: View {
    var body: some View {
        Text("No screenshots yet. Press ⇧⌘4 to take one.")
            .font(Theme.Typography.label)
            .foregroundStyle(.secondary)
    }
}
