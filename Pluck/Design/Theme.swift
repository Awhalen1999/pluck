import SwiftUI

/// Pluck's design system. Every value the UI uses lives here; views never
/// hard-code a number or a color. Changes are reviewed by Alex, in the Design
/// System window (debug builds, from the menu bar).
///
/// The notch is always dark, whatever the system appearance. Its views run in
/// the dark color scheme and use SwiftUI's native hierarchy (`.primary`,
/// `.secondary`, `.tertiary`) for text and fills, so they read as macOS.
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
    }

    enum Motion {
        /// Opening: quick, with a little life at the end.
        static let open = Animation.spring(duration: 0.42, bounce: 0.15)
        /// Closing: quick, and settles without overshoot.
        static let close = Animation.smooth(duration: 0.32)

        /// Content waits until the notch has mostly opened, then fades in.
        static let contentIn = Animation.easeOut(duration: 0.2).delay(0.12)
        /// Content leaves before the notch closes, so it's never squeezed.
        static let contentOut = Animation.easeOut(duration: 0.08)
        /// Gap between siblings appearing one after another, like a row of tiles.
        static let stagger: TimeInterval = 0.018
        /// Content starts this much smaller and settles to full size.
        static let contentScale: CGFloat = 0.97

        /// How content leaves the notch. Arrival is handled by `reveal(order:)`.
        static let contentTransition = AnyTransition.asymmetric(insertion: .identity, removal: .opacity.animation(contentOut))
    }

    enum Tile {
        static let ring = Color.white.opacity(0.16)
        static let ringWidth: CGFloat = 0.5
        static let hoverRing = Color.white.opacity(0.5)
        static let hoverRingWidth: CGFloat = 1
        static let hoverScale: CGFloat = 1.03
        static let selectedRingWidth: CGFloat = 2
    }

    enum Notch {
        /// The panel's fixed size, big enough for the largest state (the Shelf).
        static let canvas = CGSize(width: 720, height: 640)
        /// Bottom corner radius of the idle notch, matched to the hardware notch.
        static let idleRadius: CGFloat = 10
        /// Bottom corner radius of every expanded state: Peek, Preview, Shelf.
        static let expandedRadius: CGFloat = 24
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

        static let peekTile = CGSize(width: 72, height: 45)
        static let peekTileCount = 6
        static let previewWidth: CGFloat = 320
        static let previewImageHeight: CGFloat = 168
        static let shelfWidth: CGFloat = 680
        static let shelfRowHeight: CGFloat = 104
        static let shelfMaxHeight: CGFloat = 600

        static let fill = Color.black
        /// Darkens the glass so white text stays readable over bright windows.
        static let glassTint = Color.black.opacity(0.55)
        /// How far below the header the black fades into glass.
        static let glassFade: CGFloat = 40
        /// The expanded notch's shadow over the desktop.
        static let shadow = Color.black.opacity(0.5)
        static let shadowRadius: CGFloat = 30
        static let shadowY: CGFloat = 16
    }
}
