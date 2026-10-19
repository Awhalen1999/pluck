import SwiftUI

/// A preview choice, drawn: Pluck's open in the notch, or the macOS thumbnail
/// in the corner of the screen.
struct PreviewArt: View {
    let style: PreviewStyle

    var body: some View {
        ZStack(alignment: .top) {
            Wallpaper()
            switch style {
            case .pluck:
                NotchShape(radius: Theme.Radius.card, flare: Theme.Notch.idleFlare)
                    .fill(Theme.Notch.fill)
                    .frame(width: Theme.Onboarding.choiceNotch.width, height: Theme.Onboarding.choiceNotch.height)
                    .overlay {
                        VStack(spacing: Theme.Space.xs) {
                            RoundedRectangle(cornerRadius: Theme.Radius.mini, style: .continuous)
                                .fill(Theme.Palette.accent.gradient)
                            HStack(spacing: Theme.Space.xs) {
                                ForEach(0..<4, id: \.self) { _ in
                                    RoundedRectangle(cornerRadius: Theme.Radius.mini, style: .continuous).fill(.fill.tertiary)
                                }
                            }
                            .frame(height: Theme.Onboarding.choiceTileHeight)
                        }
                        .padding(.horizontal, Theme.Space.m)
                        .padding(.top, Theme.Space.l)
                        .padding(.bottom, Theme.Space.m)
                    }
            case .macOS:
                NotchShape(radius: Theme.Radius.tile, flare: Theme.Notch.idleFlare)
                    .fill(Theme.Notch.fill)
                    .frame(width: Theme.Onboarding.choiceIdleNotch.width, height: Theme.Onboarding.choiceIdleNotch.height)
                RoundedRectangle(cornerRadius: Theme.Radius.mini, style: .continuous)
                    .fill(.white.gradient)
                    .frame(width: Theme.Onboarding.choiceThumbnail.width, height: Theme.Onboarding.choiceThumbnail.height)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(Theme.Space.l)
            }
        }
        .frame(height: Theme.Onboarding.choiceArtHeight)
        .clipShape(.rect(cornerRadius: Theme.Radius.control))
        .environment(\.colorScheme, .dark)
    }
}

/// Onboarding's last step, drawn: the notch at rest over ⇧⌘4, then open on the
/// user's first screenshot, on the notch's own spring.
struct FirstShotArt: View {
    let shot: Shot?

    var body: some View {
        let open = shot != nil
        let size = open ? Theme.Onboarding.firstShotOpen : Theme.Onboarding.firstShotIdle
        let notch = NotchShape(radius: open ? Theme.Notch.expandedRadius : Theme.Notch.idleRadius,
                               flare: open ? Theme.Notch.expandedFlare : Theme.Notch.idleFlare)
        ZStack(alignment: .top) {
            Wallpaper()
            notch
                .fill(Theme.Notch.fill)
                .frame(width: size.width, height: size.height)
                .overlay {
                    if let shot {
                        ShotImage(shot: shot)
                            .clipShape(.rect(cornerRadius: Theme.Radius.tile))
                            .padding(.top, Theme.Notch.headerHeight)
                            .padding([.horizontal, .bottom], Theme.Space.m)
                            .transition(Theme.Motion.contentTransition)
                    }
                }
                .clipShape(notch)
            if !open {
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
        }
        .frame(height: Theme.Onboarding.firstShotArtHeight)
        .clipShape(.rect(cornerRadius: Theme.Radius.card))
        .environment(\.colorScheme, .dark)
        .animation(Theme.Motion.reshape(growing: open), value: size)
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
