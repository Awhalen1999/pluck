#if DEBUG
import SwiftUI

/// A living spec sheet: every token in `Theme`, rendered for real. Debug builds
/// only, opened from the menu bar. Design changes are reviewed here first.
struct DesignSystemView: View {
    static let windowID = "design-system"

    /// Starts at `-designSystem.state Shelf` when given at launch. Read once, so the
    /// argument never overrides the picker.
    @State private var state = UserDefaults.standard.string(forKey: "designSystem.state").flatMap(DemoState.init) ?? .idle

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Space.xxl) {
                notchSection
                typeSection
                colorSection
                spaceSection
                radiusSection
                tileSection
            }
            .padding(Theme.Space.xxl)
        }
        .frame(width: Theme.Notch.canvas.width + 2 * Theme.Space.xxl, height: Theme.Notch.canvas.height)
        .background(.black)
        .environment(\.colorScheme, .dark)
    }

    // MARK: Notch

    private var notchSection: some View {
        section("Notch", "The shape opens with Motion.open and closes with Motion.close. Content arrives as one piece on the same spring; on close it leaves first.") {
            Picker("State", selection: Binding(get: { state }, set: { next in
                withAnimation(next == .idle ? Theme.Motion.close : Theme.Motion.open) { state = next }
            })) {
                ForEach(DemoState.allCases) { Text($0.rawValue).tag($0) }
            }
            .pickerStyle(.segmented)
            .fixedSize()

            NotchDemoStage(state: state)
        }
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

/// The notch over a desktop, in one of its states. Its own view so it can also
/// be rendered off-screen.
struct NotchDemoStage: View {
    let state: DemoState

    var body: some View {
        ZStack(alignment: .top) {
            LinearGradient(colors: Demo.wallpaper, startPoint: .topTrailing, endPoint: .bottomLeading)
            RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous).fill(.white)
                .frame(width: Theme.Notch.canvas.width / 2, height: Theme.Notch.canvas.height / 2)
                .frame(maxWidth: .infinity, alignment: .trailing)
                .padding(.top, Theme.Notch.headerHeight * 2)
            NotchShape(radius: Theme.Notch.idleRadius).fill(Theme.Notch.fill)
                .frame(width: Theme.Notch.referenceSize.width, height: Theme.Notch.referenceSize.height)
            notch
        }
        .frame(width: Theme.Notch.canvas.width, height: DemoState.shelf.size.height + Theme.Space.xxl, alignment: .top)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
    }

    private var notch: some View {
        ZStack(alignment: .top) {
            Group {
                switch state {
                case .idle: EmptyView()
                case .peek: peekContent
                case .preview: previewContent
                case .shelf: shelfContent
                }
            }
            .transition(Theme.Motion.contentTransition)
        }
        .padding(.top, Theme.Notch.headerHeight)
        .frame(width: state.size.width, height: state.size.height, alignment: .top)
        .notchSurface(radius: state == .idle ? Theme.Notch.idleRadius : Theme.Notch.expandedRadius)
        .shadow(color: state == .idle ? .clear : Theme.Notch.shadow, radius: Theme.Notch.shadowRadius, y: Theme.Notch.shadowY)
    }

    private var peekContent: some View {
        HStack(spacing: Theme.Space.s) {
            ForEach(0..<Theme.Notch.peekTileCount, id: \.self) { i in
                DemoTile(hue: Demo.hue(i)).frame(width: Theme.Notch.peekTile.width, height: Theme.Notch.peekTile.height)
                    
            }
            Text("+8").font(Theme.Typography.badge).foregroundStyle(.secondary)
                .frame(width: Theme.Notch.peekTile.width, height: Theme.Notch.peekTile.height)
        }
    }

    private var previewContent: some View {
        VStack(spacing: Theme.Space.m) {
            DemoTile(hue: Demo.hue(2), radius: Theme.Radius.card).frame(height: Theme.Notch.previewImageHeight)
            HStack {
                VStack(alignment: .leading, spacing: 0) {
                    Text("PeekView.swift").font(Theme.Typography.title)
                    Text("2880 × 1800 · Desktop").font(Theme.Typography.detail).foregroundStyle(.secondary)
                }
                Spacer()
                Label("Copied", systemImage: "checkmark.circle.fill").font(Theme.Typography.label).foregroundStyle(Theme.Palette.copied)
            }
            .frame(height: Theme.Notch.controlHeight)
            HStack(spacing: Theme.Space.s) {
                ForEach(["Copy", "Markup", "Pin", "Trash"], id: \.self) { title in
                    Text(title).font(Theme.Typography.label)
                        .frame(maxWidth: .infinity, minHeight: Theme.Notch.controlHeight)
                        .background(.fill.tertiary, in: .rect(cornerRadius: Theme.Radius.control))
                }
            }
        }
        .padding([.horizontal, .bottom], Theme.Space.l)
    }

    private var shelfContent: some View {
        VStack(alignment: .leading, spacing: Theme.Space.s) {
            sectionHeader("Pinned", note: "Kept until you unpin")
            tileRow(hues: 0..<3)
            sectionHeader("Today", note: nil)
            tileRow(hues: 3..<7)
            tileRow(hues: 7..<11)
        }
        .padding([.horizontal, .bottom], Theme.Space.xl)
    }

    private func sectionHeader(_ name: String, note: String?) -> some View {
        HStack {
            Text(name).font(Theme.Typography.title)
            Spacer()
            if let note { Text(note).font(Theme.Typography.detail).foregroundStyle(.tertiary) }
        }
        .frame(height: Theme.Notch.sectionHeaderHeight)
    }

    private func tileRow(hues: Range<Int>) -> some View {
        HStack(spacing: Theme.Space.s) {
            ForEach(hues, id: \.self) { DemoTile(hue: Demo.hue($0)) }
        }
        .frame(height: Theme.Notch.shelfRowHeight)
    }
}

/// A placeholder screenshot, drawn with the real tile tokens.
private struct DemoTile: View {
    var hue: Double
    var radius = Theme.Radius.tile
    var hovered = false
    var selected = false
    var pinned = false

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
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
            .scaleEffect(hovered ? Theme.Tile.hoverScale : 1)
    }
}

enum DemoState: String, CaseIterable, Identifiable {
    case idle = "Idle", peek = "Peek", preview = "Preview", shelf = "Shelf"

    var id: Self { self }

    /// Sizes built from tokens, the way the real notch will compute them.
    var size: CGSize {
        let notch = Theme.Notch.self
        switch self {
        case .idle:
            return notch.referenceSize
        case .peek:
            let slots = CGFloat(notch.peekTileCount + 1)
            return CGSize(width: slots * notch.peekTile.width + (slots - 1) * Theme.Space.s + 2 * Theme.Space.l,
                          height: notch.headerHeight + notch.peekTile.height + Theme.Space.l)
        case .preview:
            return CGSize(width: notch.previewWidth,
                          height: notch.headerHeight + notch.previewImageHeight + 2 * notch.controlHeight + 2 * Theme.Space.m + Theme.Space.l)
        case .shelf:
            return CGSize(width: notch.shelfWidth,
                          height: notch.headerHeight + 2 * notch.sectionHeaderHeight + 3 * notch.shelfRowHeight + 4 * Theme.Space.s + Theme.Space.xl)
        }
    }
}

/// Demo-only content for this window. None of this is part of the system.
private enum Demo {
    static let wallpaper = [Color(red: 0.29, green: 0.25, blue: 0.62), Color(red: 0.27, green: 0.14, blue: 0.33), Color(red: 0.62, green: 0.29, blue: 0.2)]
    static func hue(_ i: Int) -> Double { (Double(i) * 0.13).truncatingRemainder(dividingBy: 1) }
    static let labelWidth: CGFloat = 96
    static let spaceScale: CGFloat = 8
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
