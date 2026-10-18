import SwiftUI

/// The screenshots you just took, newest in front, with what you'd do next.
/// Acting on the front one saves it and brings up the next; when the time runs
/// out, all of them are saved. Hovering holds it, and dragging the front one out
/// takes it with you, never saved.
struct PreviewView: View {
    /// Front first.
    let stack: [Shot]
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let shot = stack[0]
        let card = RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
        // The strip at the card's foot where feedback floats.
        let feedbackBand = controller.feedback == nil ? 0 : Theme.Notch.controlHeight + 2 * Theme.Space.m
        VStack(spacing: 0) {
            NotchHeader(notchWidth: notchWidth) {
                if stack.count > 1 { Text("\(stack.count) shots") }
            } trailing: {
                CountdownRing(controller: controller)
            }
            VStack(spacing: Theme.Space.m) {
                ShotImage(shot: shot, fits: true)
                    .frame(height: NotchLayout.previewImageHeight(shot))
                    // Opaque, so the shots behind don't show through the letterbox.
                    .background(Theme.Notch.fill)
                    .clipShape(card)
                    .overlay { card.strokeBorder(Theme.Tile.ring, lineWidth: Theme.Tile.ringWidth) }
                    .overlay {
                        // No double-click here: a click copies at once.
                        // Clear of the feedback: an AppKit view takes every click in its
                        // frame, even under SwiftUI drawn above it, Undo's included.
                        ShotInteraction(onClick: { _ in controller.copy([shot.id]) },
                                        onDoubleClick: nil,
                                        onDrag: { controller.beginDrag(shot.id, from: $0, event: $1) },
                                        menu: { controller.menu(for: shot.id) })
                            .padding(.bottom, feedbackBand)
                    }
                    .background(alignment: .top) {
                        ForEach(1..<min(stack.count, Theme.Notch.previewStackDepth), id: \.self) { depth in
                            card.fill(.fill.tertiary)
                                .scaleEffect(1 - CGFloat(depth) * Theme.Notch.previewStackShrink, anchor: .top)
                                .offset(y: -CGFloat(depth) * Theme.Notch.previewStackStep)
                                .opacity(1 - Double(depth - 1) * Theme.Notch.latestStackFade)
                        }
                    }
                    .opacity(controller.draggedShots.contains(shot.id) ? Theme.Tile.draggedOpacity : 1)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Screenshot, \(shot.detail)")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Copies it")
                    .accessibilityAction { controller.copy([shot.id]) }
                    // The next shot comes up as a new card; the buttons stay put.
                    .id(shot.id)
                    .transition(Theme.Motion.contentTransition)
                    // The header is too narrow for feedback, so it floats on the card,
                    // over the next shot once the last one was dealt with. A click
                    // beside it does nothing, rather than reaching the notch.
                    .overlay(alignment: .bottom) {
                        if let feedback = controller.feedback {
                            FeedbackLabel(feedback: feedback, controller: controller)
                                .padding(.horizontal, Theme.Space.m)
                                .frame(height: Theme.Notch.controlHeight)
                                .background(Theme.Notch.fill, in: .capsule)
                                .frame(maxWidth: .infinity, maxHeight: feedbackBand)
                                .contentShape(.rect)
                        }
                    }

                HStack(spacing: Theme.Space.s) {
                    Button("Copy") { controller.copy([shot.id]) }
                    Button("Markup") { controller.markup(shot.id) }
                    Button("Pin") { controller.togglePin([shot.id]) }
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
