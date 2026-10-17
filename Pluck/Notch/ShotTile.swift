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
                }
            }
            .clipped()
            .task(id: shot.id) { image = await Thumbnails.image(for: shot) }
    }
}

/// A shot in Peek or the Shelf. Clicking copies it; it lifts under the pointer.
struct ShotTile: View {
    let shot: Shot
    let size: CGSize
    let controller: NotchController
    @State private var hovered = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
        Button { controller.copy(shot.id) } label: {
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
        }
        .buttonStyle(PressableStyle())
        .scaleEffect(hovered ? Theme.Tile.hoverScale : 1)
        .animation(Theme.Motion.hover, value: hovered)
        .onHover { inside in
            hovered = inside
            controller.hover(shot.id, inside)
        }
        .accessibilityLabel("Screenshot, \(shot.detail)")
        .accessibilityHint("Copies it")
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
