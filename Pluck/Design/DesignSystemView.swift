#if DEBUG
import SwiftUI

/// Every token in `Theme`, rendered. Debug builds only, from the menu bar; the
/// notch itself is reviewed live.
struct DesignSystemView: View {
    static let windowID = "design-system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xxl) {
                typeSection
                colorSection
                spaceSection
                radiusSection
                tileSection
                onboardingSection
            }
            .padding(Theme.Space.xxl)
        }
        .frame(width: Theme.Notch.canvas.width, height: Theme.Notch.canvas.height)
        .background(.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Tokens

    private var typeSection: some View {
        section("Type", "Native SF text styles. Nothing else in the notch.") {
            specimen("title · 13 pt semibold", "Pinned · PeekView.swift", Theme.Typography.title)
            specimen("label · 12 pt medium", "Copy · Moved to Trash · Undo", Theme.Typography.label)
            specimen("detail · 11 pt", "9:41 PM · 2880 × 1800 · Desktop", Theme.Typography.detail)
            specimen("badge · 10 pt semibold", "+8 · 3 selected · Wide", Theme.Typography.badge)
        }
    }

    private var colorSection: some View {
        section("Color", "Text and fills use the native dark hierarchy. Color is only for meaning.") {
            HStack(alignment: .top, spacing: Theme.Space.xl) {
                VStack(alignment: .leading, spacing: Theme.Space.xs) {
                    Text("Primary").foregroundStyle(.primary)
                    Text("Secondary").foregroundStyle(.secondary)
                    Text("Tertiary").foregroundStyle(.tertiary)
                }
                .font(Theme.Typography.label)
                swatch("fill.secondary", "hover", AnyShapeStyle(.fill.secondary))
                swatch("fill.tertiary", "controls", AnyShapeStyle(.fill.tertiary))
                swatch("accent", "selection, brand", AnyShapeStyle(Theme.Palette.accent))
                swatch("copied", "green", AnyShapeStyle(Theme.Palette.copied))
                swatch("trashed", "orange", AnyShapeStyle(Theme.Palette.trashed))
                swatch("pinned", "yellow", AnyShapeStyle(Theme.Palette.pinned))
                swatch("allowed", "folder access", AnyShapeStyle(Theme.Palette.allowed))
                swatch("denied", "folder access", AnyShapeStyle(Theme.Palette.denied))
            }
        }
    }

    private var spaceSection: some View {
        section("Space", "Every gap and padding is one of these.") {
            ForEach(Demo.spaces, id: \.name) { space in
                HStack(spacing: Theme.Space.m) {
                    Text("\(space.name) · \(Int(space.value))").font(Theme.Typography.detail).foregroundStyle(.secondary)
                        .frame(width: Demo.labelWidth, alignment: .leading)
                    Rectangle().fill(Theme.Palette.accent).frame(width: space.value * Demo.spaceScale, height: Theme.Space.s)
                }
            }
        }
    }

    private var radiusSection: some View {
        section("Radius", "Corner radii, smallest to largest.") {
            HStack(spacing: Theme.Space.xl) {
                ForEach(Demo.radii, id: \.name) { radius in
                    VStack(spacing: Theme.Space.xs) {
                        RoundedRectangle(cornerRadius: radius.value, style: .continuous).fill(.fill.secondary)
                            .frame(width: Theme.Notch.peekTile.width, height: Theme.Notch.peekTile.height)
                        Text("\(radius.name) · \(Int(radius.value))").font(Theme.Typography.detail).foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var tileSection: some View {
        section("Tiles", "A shot at rest, hovered, selected and pinned.") {
            HStack(spacing: Theme.Space.xl) {
                tileState("rest") { DemoTile(hue: Demo.hue(4)) }
                tileState("hover") { DemoTile(hue: Demo.hue(4), hovered: true) }
                tileState("selected") { DemoTile(hue: Demo.hue(4), selected: true) }
                tileState("pinned") { DemoTile(hue: Demo.hue(4), pinned: true) }
            }
        }
    }

    private var onboardingSection: some View {
        section("Onboarding", "The drawings on the wallpaper: the two preview choices, and the last step waiting.") {
            HStack(alignment: .top, spacing: Theme.Space.xl) {
                PreviewArt(style: .pluck).frame(width: Demo.artWidth)
                PreviewArt(style: .macOS).frame(width: Demo.artWidth)
                FirstShotArt(shot: nil).frame(width: Demo.artWidth * 1.4)
            }
        }
    }

    // MARK: Helpers

    private func section(_ title: String, _ note: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.m) {
            Text(title).font(Theme.Typography.title)
            Text(note).font(Theme.Typography.detail).foregroundStyle(.secondary)
            content()
        }
    }

    private func specimen(_ name: String, _ sample: String, _ font: Font) -> some View {
        HStack(spacing: Theme.Space.m) {
            Text(name).font(Theme.Typography.detail).foregroundStyle(.tertiary).frame(width: Demo.labelWidth * 1.6, alignment: .leading)
            Text(sample).font(font)
        }
    }

    private func swatch(_ name: String, _ use: String, _ style: AnyShapeStyle) -> some View {
        VStack(alignment: .leading, spacing: Theme.Space.xs) {
            RoundedRectangle(cornerRadius: Theme.Radius.control, style: .continuous).fill(style)
                .frame(width: Theme.Notch.peekTile.width, height: Theme.Notch.peekTile.height)
            Text(name).font(Theme.Typography.badge)
            Text(use).font(Theme.Typography.detail).foregroundStyle(.secondary)
        }
    }

    private func tileState(_ name: String, @ViewBuilder tile: () -> some View) -> some View {
        VStack(spacing: Theme.Space.s) {
            tile().frame(width: Theme.Notch.peekTile.width * 2, height: Theme.Notch.peekTile.height * 2)
            Text(name).font(Theme.Typography.detail).foregroundStyle(.secondary)
        }
    }
}

/// A placeholder screenshot, drawn with the real tile tokens.
private struct DemoTile: View {
    var hue: Double
    var hovered = false
    var selected = false
    var pinned = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Theme.Radius.tile, style: .continuous)
        shape
            .fill(LinearGradient(colors: [Color(hue: hue, saturation: 0.45, brightness: 0.55),
                                          Color(hue: hue + 0.08, saturation: 0.6, brightness: 0.3)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .overlay {
                if selected {
                    shape.strokeBorder(Theme.Palette.accent, lineWidth: Theme.Tile.selectedRingWidth)
                } else if hovered {
                    shape.strokeBorder(Theme.Tile.hoverRing, lineWidth: Theme.Tile.hoverRingWidth)
                } else {
                    shape.strokeBorder(Theme.Tile.ring, lineWidth: Theme.Tile.ringWidth)
                }
            }
            .overlay(alignment: .topTrailing) {
                if pinned {
                    Image(systemName: "pin.fill").font(Theme.Typography.badge).foregroundStyle(Theme.Palette.pinned)
                        .padding(Theme.Space.xs)
                }
            }
    }
}

/// Demo-only content for this window. None of this is part of the system.
private enum Demo {
    static func hue(_ i: Int) -> Double { (Double(i) * 0.13).truncatingRemainder(dividingBy: 1) }
    static let labelWidth: CGFloat = 96
    static let spaceScale: CGFloat = 8
    static let artWidth: CGFloat = 200
    static let spaces: [(name: String, value: CGFloat)] = [
        ("xxs", Theme.Space.xxs), ("xs", Theme.Space.xs), ("s", Theme.Space.s), ("m", Theme.Space.m),
        ("l", Theme.Space.l), ("xl", Theme.Space.xl), ("xxl", Theme.Space.xxl),
    ]
    static let radii: [(name: String, value: CGFloat)] = [
        ("tile", Theme.Radius.tile), ("control", Theme.Radius.control), ("notch idle", Theme.Notch.idleRadius),
        ("card", Theme.Radius.card), ("notch open", Theme.Notch.expandedRadius),
    ]
}
#endif
