import SwiftUI

/// The screenshot you just took, whole, with what you'd do next. Acting on it
/// finishes it, hovering holds it open, and dragging it out takes it with you.
struct PreviewView: View {
    let shot: Shot
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        VStack(spacing: 0) {
            NotchHeader(notchWidth: notchWidth) {
                Text("Saved")
            } trailing: {
                CountdownRing(controller: controller)
            }
            VStack(spacing: Theme.Space.m) {
                let card = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                ShotImage(shot: shot, fits: true)
                    .frame(height: NotchLayout.previewImageHeight(shot))
                    .clipShape(card)
                    .overlay { card.strokeBorder(Theme.Tile.ring, lineWidth: Theme.Tile.ringWidth) }
                    .overlay {
                        // No double-click here: a click copies and closes at once.
                        ShotInteraction(onClick: { _ in controller.copy([shot.id]) },
                                        onDoubleClick: nil,
                                        onDrag: { controller.beginDrag(shot.id, from: $0, event: $1) },
                                        menu: { controller.menu(for: shot.id) })
                    }
                    .opacity(controller.draggedShots.contains(shot.id) ? Theme.Tile.draggedOpacity : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Screenshot, \(shot.detail)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Copies it")
                    .accessibilityAction { controller.copy([shot.id]) }

                HStack(spacing: Theme.Space.s) {
                    Button("Copy") { controller.copy([shot.id]) }
                    Button("Markup") { controller.markup(shot.id) }
                    Button(controller.library.isPinned(shot.id) ? "Unpin" : "Pin") { controller.togglePin([shot.id]) }
                    Button("Trash") { controller.trash([shot.id]) }
                }
                .buttonStyle(NotchButtonStyle())
            }
            .padding(.horizontal, Theme.Space.l)
        }
    }
}

/// How long until the Preview closes. It stops while the pointer holds it.
private struct CountdownRing: View {
    let controller: NotchController

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: controller.previewIsHeld)) { context in
            let style = StrokeStyle(lineWidth: Theme.Notch.previewRingWidth, lineCap: .round)
            ZStack {
                Circle().stroke(.quaternary, style: style)
                Circle()
                    .trim(from: 0, to: controller.previewProgress(at: context.date))
                    .stroke(.secondary, style: style)
                    .rotationEffect(.degrees(-90))
            }
            .frame(width: Theme.Notch.previewRingSize, height: Theme.Notch.previewRingSize)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
