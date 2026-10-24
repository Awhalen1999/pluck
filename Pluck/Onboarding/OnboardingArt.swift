import SwiftUI

/// A preview choice, drawn on the same sample screenshot: Pluck's Preview open
/// in the notch, built from the real one's parts at its real size, or the macOS
/// thumbnail in the corner of the screen. Both are scaled down as one.
struct PreviewArt: View {
    let style: PreviewStyle

    var body: some View {
        Wallpaper()
            .frame(height: Theme.Onboarding.choiceArtHeight)
            .overlay(alignment: .top) {
                Group {
                    switch style {
                    case .pluck: PreviewReplica()
                    case .macOS:
                        NotchShape(radius: Theme.Notch.idleRadius, flare: Theme.Notch.idleFlare)
                            .fill(Theme.Notch.fill)
                            .frame(width: Theme.Notch.referenceSize.width, height: Theme.Notch.referenceSize.height)
                    }
                }
                .scaleEffect(Theme.Onboarding.artScale, anchor: .top)
            }
            .overlay(alignment: .bottomTrailing) {
                if style == .macOS {
                    SampleScreenshot(radius: Theme.Radius.mini)
                        .frame(width: Theme.Onboarding.choiceThumbnailWidth)
                        .padding(Theme.Space.m)
                }
            }
            .clipShape(.rect(cornerRadius: Theme.Radius.control))
            .environment(\.colorScheme, .dark)
            .accessibilityHidden(true)
    }
}

/// The Preview as it opens after a screenshot: the shot, then what you'd do next.
private struct PreviewReplica: View {
    var body: some View {
        VStack(spacing: Theme.Space.m) {
            SampleScreenshot(radius: Theme.Radius.card)
            HStack(spacing: Theme.Space.s) {
                ForEach(["Copy", "Preview", "Pin", "Trash"], id: \.self) { Button($0) {} }
            }
            .buttonStyle(NotchButtonStyle())
        }
        .padding(.top, Theme.Notch.headerHeight)
        .padding([.horizontal, .bottom], Theme.Space.l)
        .frame(width: Theme.Notch.previewWidth)
        // Its own height, whatever room the drawing has: it's scaled down after.
        .fixedSize(horizontal: false, vertical: true)
        .background(NotchShape(radius: Theme.Notch.expandedRadius, flare: Theme.Notch.expandedFlare).fill(Theme.Notch.fill))
        .allowsHitTesting(false)
    }
}

private struct SampleScreenshot: View {
    let radius: CGFloat

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: radius, style: .continuous)
        Image(.sampleScreenshot)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .clipShape(shape)
            .overlay { shape.strokeBorder(Theme.Tile.ring, lineWidth: Theme.Tile.ringWidth) }
    }
}

/// The last step's drawing while it waits: the notch at rest over ⇧⌘4.
struct ShortcutArt: View {
    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            NotchShape(radius: Theme.Notch.idleRadius, flare: Theme.Notch.idleFlare)
                .fill(Theme.Notch.fill)
                .frame(width: Theme.Onboarding.shortcutNotch.width, height: Theme.Onboarding.shortcutNotch.height)
            HStack(spacing: Theme.Space.xs) {
                ForEach(["⇧", "⌘", "4"], id: \.self) { key in
                    Text(key)
                        .font(Theme.Onboarding.keycapFont)
                        .frame(width: Theme.Onboarding.keycapSize, height: Theme.Onboarding.keycapSize)
                        .background(.fill.tertiary, in: .rect(cornerRadius: Theme.Radius.control))
                }
            }
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, Theme.Space.xxl)
        }
        .frame(height: Theme.Onboarding.shortcutArtHeight)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .environment(\.colorScheme, .dark)
        .accessibilityHidden(true)
    }
}

/// The stand-in screen the drawings sit on.
private struct Wallpaper: View {
    var body: some View {
        ZStack {
            Theme.Onboarding.wallpaper
            Theme.Onboarding.wallpaperGlow
        }
    }
}
