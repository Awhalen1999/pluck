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
                        // A filled image overflows its frame, and clipping doesn't
                        // trim hit-testing: the overflow would take presses meant
                        // for the tiles beside it.
                        .allowsHitTesting(false)
                }
            }
            .clipped()
            .task(id: shot.id) { image = await Thumbnails.image(for: shot) }
    }
}

/// A shot in Peek or the Shelf: click copies, ⌘-click selects (in the Shelf),
/// double-click opens it in Preview, and it drags into other apps. Ringed while it
/// has the focus, in the accent while selected.
struct ShotTile: View {
    let shot: Shot
    let size: CGSize
    let controller: NotchController

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
        let focused = controller.focusedShot == shot.id
        let selected = controller.selection.contains(shot.id)
        ShotImage(shot: shot)
            .frame(width: size.width, height: size.height)
            .clipShape(shape)
            .overlay {
                if selected {
                    shape.strokeBorder(Theme.Palette.accent, lineWidth: Theme.Tile.selectedRingWidth)
                } else {
                    shape.strokeBorder(focused ? Theme.Tile.hoverRing : Theme.Tile.ring,
                                       lineWidth: focused ? Theme.Tile.hoverRingWidth : Theme.Tile.ringWidth)
                }
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
                                onDoubleClick: { controller.openInPreview([shot.id]) },
                                onDrag: { controller.beginDrag(shot.id, from: $0, event: $1) },
                                menu: { controller.menu(for: shot.id) })
            }
            .opacity(controller.draggedShots.contains(shot.id) ? Theme.Tile.draggedOpacity : 1)
            .onHover { controller.hover(shot.id, $0) }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Screenshot, \(shot.detail)")
            .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
            .accessibilityHint("Copies it")
            .accessibilityAction { controller.copy([shot.id]) }
    }
}

/// The notch's text buttons: Copy, Preview, Pin, Trash. They act on a tap, not
/// through a system button's press tracking, which keeps its own view from
/// animating with the change it makes: the clicked button jumped while its
/// neighbours moved on the notch's spring.
struct NotchButtonStyle: PrimitiveButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        NotchButton(configuration: configuration)
    }
}

private struct NotchButton: View {
    let configuration: PrimitiveButtonStyleConfiguration
    @State private var hovered = false

    var body: some View {
        configuration.label
            .font(Theme.Typography.label)
            .frame(maxWidth: .infinity, minHeight: Theme.Notch.controlHeight)
            .background(hovered ? AnyShapeStyle(.fill.secondary) : AnyShapeStyle(.fill.tertiary),
                        in: .rect(cornerRadius: Theme.Radius.control, style: .continuous))
            .contentShape(.rect)
            .onHover { hovered = $0 }
            .onTapGesture { configuration.trigger() }
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
