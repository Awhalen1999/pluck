import SwiftUI

/// The notch: one black shape that takes the size of its current state, with
/// that state's content inside, moving together on one spring.
struct NotchView: View {
    let controller: NotchController
    @State private var lastSize = CGSize.zero

    var body: some View {
        if let geometry = controller.geometry {
            let frame = controller.frame
            let expanded = !controller.shownState.isCompact
            let shape = NotchShape(radius: expanded ? Theme.Notch.expandedRadius
                                       : geometry.hasNotch ? Theme.Notch.idleRadius : frame.size.height / 2,
                                   flare: expanded ? Theme.Notch.expandedFlare : Theme.Notch.idleFlare,
                                   floats: !geometry.hasNotch)
            let reshape = Theme.Motion.reshape(growing: frame.size.width * frame.size.height > lastSize.width * lastSize.height)
            ZStack(alignment: .top) {
                // Behind the content, so it only gets clicks nothing in front claims.
                // Labels don't take the pointer, so a click on one is a click here.
                Color.clear
                    .contentShape(shape)
                    .onTapGesture { controller.clickedNotch() }
                content(notchWidth: geometry.frame.width)
                    .transition(Theme.Motion.contentTransition)
                    .opacity(controller.showsContent ? 1 : 0)
            }
            .frame(width: frame.size.width, height: frame.size.height, alignment: .top)
            .clipShape(shape)
            .background(Theme.Notch.fill, in: shape)
            .onContinuousHover(coordinateSpace: .global) { phase in
                switch phase {
                case .active(let point): controller.pointerMovedInPanel(point)
                case .ended: controller.pointerLeftShape()
                }
            }
            .offset(x: frame.offsetX)
            .padding(.top, geometry.topInset)
            // Whatever changes the notch, its frame or its state (the Preview's next
            // shot, say), animates it, so two changes in one update move as one.
            .animation(reshape, value: frame)
            .animation(reshape, value: controller.state)
            .onChange(of: frame, initial: true) { _, new in lastSize = new.size }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private func content(notchWidth: CGFloat) -> some View {
        switch controller.state {
        // One view for both, so a capture landing grows the ear in place.
        case .idle, .preview(_, open: false):
            Ears(controller: controller, notchWidth: notchWidth)
        case .peek:
            PeekView(controller: controller, notchWidth: notchWidth)
        case .preview(_, open: true):
            let stack = controller.previewStack
            if !stack.isEmpty {
                PreviewView(stack: stack, controller: controller, notchWidth: notchWidth)
            }
        case .shelf:
            ShelfView(controller: controller, notchWidth: notchWidth)
        }
    }
}

/// The band level with the hardware notch, split into the ears either side of
/// it. Nothing in an ear may run under the camera housing or widen the notch.
struct NotchHeader<Leading: View, Trailing: View>: View {
    let notchWidth: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(minWidth: 0, maxWidth: .infinity, alignment: .leading).allowsHitTesting(false)
            Color.clear.frame(width: notchWidth + 2 * Theme.Space.m)
            trailing.frame(minWidth: 0, maxWidth: .infinity, alignment: .trailing)
        }
        .font(Theme.Typography.detail)
        .foregroundStyle(.secondary)
        .lineLimit(1)
        .padding(.horizontal, Theme.Space.l)
        .frame(height: Theme.Notch.headerHeight)
    }
}

/// What the user just did, with Undo when it can be undone.
struct FeedbackLabel: View {
    let feedback: Feedback
    let controller: NotchController

    var body: some View {
        HStack(spacing: Theme.Space.xs) {
            Group {
                Image(systemName: feedback.symbol).foregroundStyle(feedback.tint)
                Text(feedback.text).foregroundStyle(.primary)
            }
            .allowsHitTesting(false)
            if feedback.canUndo {
                Button("Undo") { controller.undoTrash() }
                    .buttonStyle(.plain)
                    .foregroundStyle(Theme.Palette.accent)
            }
        }
        .font(Theme.Typography.label)
        .lineLimit(1)
        .transition(.blurReplace)
    }
}

/// The notch at notch height: on the left a compact Preview's capture, or the
/// latest shot when idle; feedback on the right.
private struct Ears: View {
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let ears = NotchLayout.ears(for: controller.state, controller.content)
        HStack(spacing: 0) {
            Group {
                let stack = controller.previewStack
                if let front = stack.first {
                    PreviewThumb(stack: stack, front: front, controller: controller)
                } else {
                    LatestStack(shots: Array(controller.library.shots.prefix(Theme.Notch.latestStackDepth)), size: Theme.Notch.latestThumb)
                }
            }
            .frame(width: ears.left)
            .opacity(ears.left > 0 ? 1 : 0)
            Color.clear.frame(width: notchWidth)
            Group {
                if let feedback = controller.feedback { FeedbackLabel(feedback: feedback, controller: controller) }
            }
            .frame(width: ears.right)
        }
        .frame(height: controller.geometry?.frame.height)
    }
}

/// A compact Preview's capture, with any waiting behind it: a click copies it, a
/// drag takes it, and resting on it opens the Preview.
private struct PreviewThumb: View {
    let stack: [Shot]
    let front: Shot
    let controller: NotchController

    var body: some View {
        LatestStack(shots: Array(stack.prefix(Theme.Notch.latestStackDepth)), size: Theme.Notch.previewThumb)
            .overlay {
                ShotInteraction(onClick: { _ in controller.copy([front.id]) },
                                onDoubleClick: nil,
                                onDrag: { controller.beginDrag(front.id, from: $0, event: $1) },
                                menu: { controller.menu(for: front.id) })
            }
            .opacity(controller.draggedShots.contains(front.id) ? Theme.Tile.draggedOpacity : 1)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screenshot, \(front.detail)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Copies it")
            .accessibilityAction { controller.copy([front.id]) }
    }
}

/// The newest shots, stacked like a little deck.
private struct LatestStack: View {
    let shots: [Shot]
    let size: CGSize

    var body: some View {
        ZStack {
            ForEach(Array(shots.enumerated().reversed()), id: \.element.id) { depth, shot in
                ShotImage(shot: shot)
                    .frame(width: size.width, height: size.height)
                    .clipShape(.rect(cornerRadius: Theme.Radius.mini, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Theme.Radius.mini, style: .continuous)
                            .strokeBorder(Theme.Tile.ring, lineWidth: Theme.Tile.ringWidth)
                    }
                    .offset(x: -CGFloat(depth) * Theme.Space.xxs, y: CGFloat(depth) * Theme.Space.xxs)
                    .opacity(1 - Double(depth) * Theme.Notch.latestStackFade)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
