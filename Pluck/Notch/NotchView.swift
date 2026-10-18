import SwiftUI

/// The notch: one glass shape that takes the size of its current state, with
/// that state's content inside. Content and shape move together on one spring.
struct NotchView: View {
    let controller: NotchController

    var body: some View {
        if let geometry = controller.geometry {
            let frame = controller.frame
            let expanded = controller.shownState != .idle
            let radius = expanded ? Theme.Notch.expandedRadius
                : geometry.hasNotch ? Theme.Notch.idleRadius : frame.size.height / 2
            let topRadius = geometry.hasNotch ? 0 : radius
            let shape = NotchShape(radius: radius, topRadius: topRadius)

            ZStack(alignment: .top) {
                // A click on the notch itself opens the Shelf. This sits behind the
                // content, so it only fires where nothing in front takes the click:
                // a shot, a button. Labels don't take the pointer, so a click on
                // one is a click on the notch.
                Color.clear
                    .contentShape(shape)
                    .onTapGesture { controller.clickedNotch() }
                content(notchWidth: geometry.frame.width)
                    .transition(Theme.Motion.contentTransition)
                    .opacity(controller.showsContent ? 1 : 0)
            }
            .frame(width: frame.size.width, height: frame.size.height, alignment: .top)
            .notchSurface(radius: radius, topRadius: topRadius)
            .onContinuousHover(coordinateSpace: .global) { phase in
                switch phase {
                case .active(let point): controller.pointerMovedInPanel(point)
                case .ended: controller.pointerLeftShape()
                }
            }
            .shadow(color: expanded ? Theme.Notch.shadow : .clear, radius: Theme.Notch.shadowRadius, y: Theme.Notch.shadowY)
            .offset(x: frame.offsetX)
            .padding(.top, geometry.topInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .environment(\.colorScheme, .dark)
        }
    }

    @ViewBuilder
    private func content(notchWidth: CGFloat) -> some View {
        switch controller.state {
        case .idle:
            IdleEars(controller: controller, notchWidth: notchWidth)
        case .peek:
            PeekView(controller: controller, notchWidth: notchWidth)
        case .preview(let id):
            if let shot = controller.library.shots(withIDs: [id]).first {
                PreviewView(shot: shot, controller: controller, notchWidth: notchWidth)
                    .id(id)
            }
        case .shelf:
            ShelfView(controller: controller, notchWidth: notchWidth)
        }
    }
}

/// The band level with the hardware notch, split into the ears either side of it.
struct NotchHeader<Leading: View, Trailing: View>: View {
    let notchWidth: CGFloat
    @ViewBuilder var leading: Leading
    @ViewBuilder var trailing: Trailing

    var body: some View {
        HStack(spacing: 0) {
            leading.frame(maxWidth: .infinity, alignment: .leading).allowsHitTesting(false)
            Color.clear.frame(width: notchWidth)
            trailing.frame(maxWidth: .infinity, alignment: .trailing)
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

/// The idle notch's ears: the latest shot on the left, feedback on the right.
private struct IdleEars: View {
    let controller: NotchController
    let notchWidth: CGFloat

    var body: some View {
        let ears = NotchLayout.idleEars(controller.content)
        HStack(spacing: 0) {
            LatestStack(shots: Array(controller.library.shots.prefix(Theme.Notch.latestStackDepth)))
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

/// The newest shots, stacked like a little deck.
private struct LatestStack: View {
    let shots: [Shot]

    var body: some View {
        ZStack {
            ForEach(Array(shots.enumerated().reversed()), id: \.element.id) { depth, shot in
                ShotImage(shot: shot)
                    .frame(width: Theme.Notch.latestThumb.width, height: Theme.Notch.latestThumb.height)
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
