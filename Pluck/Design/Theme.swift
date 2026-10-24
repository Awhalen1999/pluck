import AppKit
import SwiftUI

/// Every value the UI uses. The notch is always dark: its views run in the dark
/// color scheme and use the native hierarchy (`.primary`, `.fill.tertiary`).
enum Theme {
    /// Spacing. Mostly 4 pt steps, with 2 and 6 for tight spots.
    enum Space {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let s: CGFloat = 6
        static let m: CGFloat = 8
        static let l: CGFloat = 12
        static let xl: CGFloat = 16
        static let xxl: CGFloat = 24
    }

    enum Radius {
        /// The tiny thumbnails beside the idle notch.
        static let mini: CGFloat = 3
        /// Thumbnails.
        static let tile: CGFloat = 6
        /// Buttons and chips inside the notch.
        static let control: CGFloat = 8
        /// The Preview's large image.
        static let card: CGFloat = 12
    }

    /// Four text styles, all native SF. Sizes are what macOS gives each style.
    enum Typography {
        /// 13 pt semibold: section names, the Preview's title.
        static let title = Font.system(.body, weight: .semibold)
        /// 12 pt medium: buttons, feedback.
        static let label = Font.system(.callout, weight: .medium)
        /// 11 pt: times, sizes, notes.
        static let detail = Font.system(.subheadline)
        /// 10 pt semibold: counts and badges.
        static let badge = Font.system(.caption, weight: .semibold)
    }

    enum Palette {
        /// Raspberry, #D81E5B. Also the app's AccentColor, so native controls match.
        static let accent = Color(.accent)
        static let copied = Color.green
        static let trashed = Color.orange
        static let pinned = Color.yellow
        /// Folder access, in onboarding.
        static let allowed = Color.green
        static let denied = Color.red
    }

    enum Motion {
        /// Opening: quick, with a little life at the end.
        static let open = Animation.spring(duration: 0.42, bounce: 0.15)
        /// Closing: quick, and settles without overshoot.
        static let close = Animation.smooth(duration: 0.32)

        /// Content leaves before the shape shrinks, so it's never squeezed.
        static let contentOut = Animation.easeOut(duration: 0.08)
        /// Content arrives as one piece on the shape's own spring, blurring into
        /// focus, and leaves quickly.
        static var contentTransition: AnyTransition {
            reduceMotion ? .opacity : .asymmetric(insertion: AnyTransition(.blurReplace),
                                                  removal: .opacity.animation(contentOut))
        }

        static let reduced = Animation.easeInOut(duration: 0.15)

        /// A shape that grows springs open; one that shrinks settles without overshoot.
        static func reshape(growing: Bool) -> Animation {
            reduceMotion ? reduced : growing ? open : close
        }

        private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    }

    enum Drag {
        /// A click can wobble several points on a trackpad and must stay a click.
        static let threshold: CGFloat = 10
        /// The largest the shot under the cursor gets during a drag.
        static let imageSize = CGSize(width: 160, height: 100)
    }

    /// Intent filters. None of these is ever a wait on an animation.
    enum Timing {
        /// Resting on the notch this long opens Peek.
        static let hoverIntent: TimeInterval = 0.13
        /// Points a second. Faster than this over the notch is passing over it,
        /// along the menu bar say, and the hover delay starts again.
        static let passingSpeed: CGFloat = 300
        /// Peek survives a small overshoot.
        static let leaveGrace: TimeInterval = 0.2
        /// A Preview the pointer held never vanishes the moment it leaves.
        static let previewResumeMinimum: TimeInterval = 1
        static let feedback: TimeInterval = 1.8
        static let feedbackWithUndo: TimeInterval = 4.2
        static let pointerOpen: TimeInterval = 1.0 / 30
        static let pointerAtRest: TimeInterval = 1.0 / 10
    }

    enum Tile {
        static let ring = Color.white.opacity(0.16)
        static let ringWidth: CGFloat = 0.5
        static let hoverRing = Color.white.opacity(0.5)
        static let hoverRingWidth: CGFloat = 1
        static let selectedRingWidth: CGFloat = 2
        /// A shot being dragged, where it came from.
        static let draggedOpacity = 0.35
        /// Thumbnails crop to fill their tile, within these aspect ratios.
        static let aspectRange: ClosedRange<CGFloat> = 0.6...2.6
    }

    /// The Settings window: native controls, sized here.
    enum Settings {
        static let width: CGFloat = 520
        static let iconSize: CGFloat = 64
    }

    /// The onboarding window: native controls, and small drawings of the notch
    /// on a stand-in screen.
    enum Onboarding {
        /// Below the title bar. Just tall enough for the welcome, its video at full width.
        static let size = CGSize(width: 560, height: 574)
        /// The one spacing in every step: the side margins, the space between its
        /// parts, and the footer's. It's the grouped Form's own inset, so rows,
        /// drawings, the video and the buttons share one edge, and a header sits as
        /// far above a Form as above a drawing.
        static let margin: CGFloat = 20
        /// A header's message is held to this width, so it breaks into even lines.
        static let messageWidth: CGFloat = 400
        static let welcomeTitle = Font.largeTitle.bold()
        static let title = Font.title.bold()
        static let iconSize: CGFloat = 64
        /// The promo, 16:9, from margin to margin.
        static let videoSize = CGSize(width: size.width - 2 * margin, height: (size.width - 2 * margin) * 9 / 16)
        /// The footer's page dots: the current one long, the ones done in the accent.
        static let dot: CGFloat = 5
        static let currentDotWidth: CGFloat = 18

        /// The stand-in screen: a dark desktop with a raspberry glow, so the black
        /// notch shows on it.
        static let wallpaper = LinearGradient(colors: [Color(red: 0.16, green: 0.18, blue: 0.23), Color(red: 0.11, green: 0.12, blue: 0.16)],
                                              startPoint: .top, endPoint: .bottom)
        static let wallpaperGlow = RadialGradient(colors: [Palette.accent.opacity(0.35), .clear],
                                                  center: UnitPoint(x: 0.75, y: 1.2), startRadius: 0, endRadius: 200)
        /// The preview choices' drawings: the notch drawn at its real size, then
        /// scaled down, so the Preview looks exactly as it will.
        static let choiceArtHeight: CGFloat = 116
        static let artScale: CGFloat = 0.36
        static let choiceThumbnailWidth: CGFloat = 80
        /// The last step's drawing: the notch at rest over ⇧⌘4.
        static let shortcutArtHeight: CGFloat = 170
        static let shortcutNotch = CGSize(width: 150, height: 22)
        static let keycapSize: CGFloat = 30
        static let keycapFont = Font.title3
        /// The last step's badge: a viewfinder while it waits, a check once done.
        static let statusSize: CGFloat = 52
        static let statusFont = Font.title2.weight(.semibold)
    }

    enum Notch {
        /// The panel's fixed size, big enough for the Shelf and its flares.
        static let canvas = CGSize(width: 720, height: 640)
        /// Bottom corners: the idle radius matches the hardware notch.
        static let idleRadius: CGFloat = 10
        static let expandedRadius: CGFloat = 24
        /// How far the top corners flare out into the screen's top edge, so the
        /// notch grows out of the hardware one.
        static let idleFlare: CGFloat = 6
        static let expandedFlare: CGFloat = 12
        /// The band level with the hardware notch. Expanded content starts below it.
        static let headerHeight: CGFloat = 36
        /// Buttons and info rows inside the notch.
        static let controlHeight: CGFloat = 28
        /// A Shelf section's name row ("Pinned", "Today").
        static let sectionHeaderHeight: CGFloat = 28
        /// The stand-in for the notch on screens without one.
        static let pillSize = CGSize(width: 160, height: 24)
        static let pillTopInset: CGFloat = 4
        /// A 14″ MacBook Pro's notch, for previews and the Design System window.
        static let referenceSize = CGSize(width: 185, height: 32)

        /// How far the hover zone reaches below the idle notch, so nobody has to
        /// push the pointer into the camera housing.
        static let hoverReach: CGFloat = 8
        /// The idle notch's left ear, where the latest shot sits.
        static let idleEarWidth: CGFloat = 44
        static let latestThumb = CGSize(width: 24, height: 15)
        static let latestStackDepth = 3
        /// Each card further back in the latest-shot stack is this much fainter.
        static let latestStackFade = 0.3
        /// The idle notch's right ear while it shows feedback.
        static let feedbackEarWidth: CGFloat = 96
        static let feedbackUndoEarWidth: CGFloat = 136
        /// Wide enough for the header's longest line, a shot's time and size
        /// (about 126 pt), clear of the camera housing.
        static let minExpandedEar: CGFloat = 148

        static let peekTile = CGSize(width: 72, height: 45)
        static let peekTileCount = 6
        /// The "+N" slot after Peek's tiles, which opens the Shelf.
        static let peekMoreWidth: CGFloat = 44
        static let previewWidth: CGFloat = 320
        /// The Preview shows the whole screenshot, letterboxed between these heights.
        static let previewImageHeights: ClosedRange<CGFloat> = 124...220
        /// Captures waiting behind the Preview's front one peek out above it, each
        /// a step higher and smaller; this many show, the front one included.
        static let previewStackDepth = 3
        static let previewStackStep: CGFloat = 6
        static let previewStackShrink: CGFloat = 0.06
        static let previewRingSize: CGFloat = 14
        static let previewRingWidth: CGFloat = 2
        static let shelfWidth: CGFloat = 680
        static let shelfRowHeight: CGFloat = 104
        static let shelfMaxHeight: CGFloat = 600

        static let fill = Color.black
    }
}
