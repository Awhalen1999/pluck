import SwiftUI

/// A shot's thumbnail. Fills its frame anchored at the top, where a screenshot's
/// title usually is, or fits whole when `fits` is set.
struct ShotImage: View {
    let shot: Shot
    var fits = false
    @State private var image: CGImage?

    var body: some View {
        Rectangle()
            .fill(.fill.quaternary)
            .overlay(alignment: fits ? .center : .top) {
                if let image = image ?? Thumbnails.cached(shot) {
                    Image(decorative: image, scale: 1)
                        .resizable()
                        .aspectRatio(contentMode: fits ? .fit : .fill)
                        // Filling scales a very wide or tall image past its frame
                        // before it's clipped, and clipping doesn't trim where it
                        // can be hit. It never takes the pointer, so the overflow
                        // can't steal presses from the tiles beside it.
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .task(id: shot.id) { image = await Thumbnails.image(for: shot) }
    }
}

/// A shot in Peek or the Shelf. Click copies it, double-click opens Quick Look,
/// right-click shows its menu, and it drags straight into other apps. It lifts
/// under the pointer and presses in under a click.
struct ShotTile: View {
    let shot: Shot
    let size: CGSize
    let controller: NotchController
    @State private var hovered = false
    @State private var pressed = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
        ShotImage(shot: shot)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay {
                shape.strokeBorder(hovered ? Theme.Tile.hoverRing : Theme.Tile.ring,
                                   lineWidth: hovered ? Theme.Tile.hoverRingWidth : Theme.Tile.ringWidth)
            }
            .overlay(alignment: .topTrailing) {
                if controller.library.isPinned(shot.id) {
                    Image(systemName: "pin.fill")
                        .font(Theme.Typography.badge)
                        .foregroundStyle(Theme.Palette.pinned)
                        .padding(Theme.Space.xs)
                }
            }
            .overlay {
                ShotInteraction(onClick: { controller.clicked(shot.id, modifiers: $0) },
                                onDoubleClick: { controller.quickLook(shot.id) },
                                onPress: { pressed = $0 },
                                onDrag: { controller.beginDrag(shot.id, from: $0, event: $1) },
                                menu: { controller.menu(for: shot.id) },
                                register: { controller.register($0, for: shot.id) })
            }
            .scaleEffect(pressed ? Theme.Tile.pressScale : hovered ? Theme.Tile.hoverScale : 1)
            .opacity(controller.draggedShots.contains(shot.id) ? Theme.Tile.draggedOpacity : 1)
            .animation(Theme.Motion.hover, value: hovered)
            .animation(Theme.Motion.hover, value: pressed)
            .onHover { inside in
                hovered = inside
                controller.hover(shot.id, inside)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screenshot, \(shot.detail)")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Copies it")
            .accessibilityAction { controller.copy([shot.id]) }
    }
}

/// Presses in slightly, so a click is felt the instant it lands.
struct PressableStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? Theme.Tile.pressScale : 1)
            .animation(Theme.Motion.hover, value: configuration.isPressed)
    }
}

/// The notch's text buttons: Copy, Markup, Pin, Trash.
struct NotchButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NotchButton(configuration: configuration)
    }
}

private struct NotchButton: View {
    let configuration: ButtonStyleConfiguration
    @State private var hovered = false

    var body: some View {
        configuration.label
            .font(Theme.Typography.label)
            .frame(maxWidth: .infinity, minHeight: Theme.Notch.controlHeight)
            .background(hovered ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary),
                        in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .contentShape(.rect)
            .scaleEffect(configuration.isPressed ? Theme.Tile.pressScale : 1)
            .animation(Theme.Motion.hover, value: configuration.isPressed)
            .animation(Theme.Motion.hover, value: hovered)
            .onHover { hovered = $0 }
    }
}

extension Shot {
    /// "9:41 PM · 2880 × 1800", or "Oct 12 · 2880 × 1800" for older shots.
    var detail: String {
        let when = Calendar.current.isDateInToday(capturedAt)
            ? capturedAt.formatted(date: .omitted, time: .shortened)
            : capturedAt.formatted(.dateTime.month(.abbreviated).day())
        return "\(when) · \(Int(pixelSize.width)) × \(Int(pixelSize.height))"
    }
}
