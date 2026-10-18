import AppKit
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
    }

    enum Motion {
        /// Opening: quick, with a little life at the end.
        static let open = Animation.spring(duration: 0.42, bounce: 0.15)
        /// Closing: quick, and settles without overshoot.
        static let close = Animation.smooth(duration: 0.32)

        /// Content leaves before the notch closes, so it's never squeezed.
        static let contentOut = Animation.easeOut(duration: 0.08)
        /// How content enters and leaves the notch. It arrives as one piece on the
        /// shape's own spring, blurring into focus, so it never waits for the shape
        /// or trails behind it. It leaves quickly, before the shape closes.
        static var contentTransition: AnyTransition {
            reduceMotion ? .opacity : .asymmetric(insertion: AnyTransition(.blurReplace),
                                                  removal: .opacity.animation(contentOut))
        }

        /// Small responses to the pointer, like a tile lifting under it.
        static let hover = Animation.smooth(duration: 0.18)

        /// Under Reduce Motion, everything becomes a quick fade.
        static let reduced = Animation.easeInOut(duration: 0.15)

        /// The animation for the notch changing shape: opening, or settling closed.
        static func reshape(opening: Bool) -> Animation {
            reduceMotion ? reduced : opening ? open : close
        }

        private static var reduceMotion: Bool { NSWorkspace.shared.accessibilityDisplayShouldReduceMotion }
    }

    enum Drag {
        /// How far a press must move before it becomes a drag. A click on a
        /// trackpad or mouse can wobble several points and must stay a click;
        /// a real drag toward another app travels hundreds.
        static let threshold: CGFloat = 10
        /// The largest the shot under the cursor gets during a drag.
        static let imageSize = CGSize(width: 160, height: 100)
    }

    /// How long the notch waits, and for what. Each one exists to read intent;
    /// nothing here should ever make the user wait on an animation.
    enum Timing {
        /// Hovering this long opens Peek, so a pointer passing by on its way to a
        /// menu doesn't open anything.
        static let hoverIntent: TimeInterval = 0.13
        /// Peek stays this long after the pointer leaves, so a small overshoot
        /// doesn't close it.
        static let leaveGrace: TimeInterval = 0.2
        /// A Preview the pointer held open stays at least this long once it leaves.
        static let previewResumeMinimum: TimeInterval = 1
        /// How long feedback shows. Long enough to read; longer when it offers Undo.
        static let feedback: TimeInterval = 1.8
        static let feedbackWithUndo: TimeInterval = 4.2
        /// Long enough for the closing spring to finish before anything moves.
        static let settle: TimeInterval = 0.4
    }

    enum Tile {
        static let ring = Color.white.opacity(0.16)
        static let ringWidth: CGFloat = 0.5
        static let hoverRing = Color.white.opacity(0.5)
        static let hoverRingWidth: CGFloat = 1
        static let hoverScale: CGFloat = 1.03
        /// A shot being dragged, where it came from.
        static let draggedOpacity = 0.35
        /// How far a tile or button presses in under a click.
        static let pressScale: CGFloat = 0.97
        static let selectedRingWidth: CGFloat = 2
        /// Thumbnails crop to fill their tile, but a screenshot's shape is kept
        /// within these limits so very tall or wide ones still read.
        static let aspectRange: ClosedRange<CGFloat> = 0.6...2.6
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
        /// The narrowest an expanded notch's ears get, beside the hardware notch.
        static let minExpandedEar: CGFloat = 88

        static let peekTile = CGSize(width: 72, height: 45)
        static let peekTileCount = 6
        /// The "+N" slot after Peek's tiles, which opens the Shelf.
        static let peekMoreWidth: CGFloat = 44
        static let previewWidth: CGFloat = 320
        /// The Preview shows the whole screenshot, letterboxed between these heights.
        static let previewImageHeights: ClosedRange<CGFloat> = 124...220
        static let previewRingSize: CGFloat = 14
        static let previewRingWidth: CGFloat = 2
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
