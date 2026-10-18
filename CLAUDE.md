# CLAUDE.md

Pluck is a macOS screenshot shelf that lives in the notch. It does one thing:
it makes the screenshot you just took easy to use, then gets it out of your way.
SwiftUI + AppKit, macOS 26+, distributed as a notarized DMG with Sparkle.

Alex is the designer and PM. Claude is the tech lead and owns the code end to end.

## Principles

1. **Simple beats clever.** The smallest readable solution that works. No
   abstraction with one implementation, no config for a value that never changes,
   no scaffolding for later.
2. **Native first.** System menus, `Form`, `Toggle`, `Picker`, Quick Look,
   `NSStatusItem`, system fonts and colors. Go custom only where we truly want
   control, which is the notch itself.
3. **Linear behavior.** One owner per piece of state, one state machine for the
   notch, no state that can contradict another.
4. **Files are the truth.** Screenshots stay ordinary files in the user's
   screenshot folder. No database.
5. **One thing perfectly.** A feature that dilutes the core gets cut, not
   half-built.
6. **Invisible interactions.** Motion should feel so natural nobody notices it,
   the way Apple's does. Nobody ever waits on an animation.

## Designing an interaction

Before building one, sit in the user's seat:

- **Write the moment down first.** What is the user doing, what do they expect
  to happen, and what must never happen (flicker at an edge, closing mid-drag,
  a click that does nothing)?
- **Respond at once.** Input changes state immediately. The only deliberate
  delays are intent filters, like the hover delay that stops the notch opening
  when the pointer merely passes by.
- **One object, one spring.** Whatever moves together animates together, on a
  Theme spring. No staggers, no chains of animations.
- **Always interruptible.** Any animation can be redirected mid-flight (hover
  out halfway through opening) and settles smoothly from where it is.
- **Respect Reduce Motion.** Under it, motion becomes a quick fade.
- **Prove it before showing it.** Check it at real speed and in slow motion,
  including fast repeats and interruptions, before Alex sees it.

## Product rules

- Pluck **watches**, it never captures. macOS takes the screenshot; Pluck picks
  up the file.
- Pluck only touches files tagged as screenshots (see Platform facts). Every
  other file in the folder is left alone.
- Removing a shot always means `FileManager.trashItem`, never a delete, so
  Finder's Put Back works.
- Cleanup rules (approved by Alex):
  - Pinned shots are always kept. There is no setting to turn that off.
  - Shots taken before Pluck's first launch are never removed automatically.
  - Unpinning restarts a shot's clock, so it never vanishes the moment it's
    unpinned.
  - "Move to" lets go: a shot filed elsewhere leaves Pluck for good.
  - Renaming a shot keeps its pin. An unpinned renamed shot is still cleaned
    up on schedule.
- Pluck changes the macOS screenshot settings (save location, floating
  thumbnail) only through the user's choices. It snapshots the originals once,
  before changing anything, and every restore puts back exactly that snapshot,
  including "never set".
- With Preview set to Pluck, the macOS thumbnail is off while Pluck runs (it
  would hold each file back for seconds) and comes back on quit. If macOS
  doesn't take the change, its thumbnail stays and Pluck's Preview steps aside,
  so there are never two previews.
- Nothing leaves the Mac. The only network use is Sparkle's update check.
- Markup opens the shot in Preview. Pluck never builds its own editor.

## The notch state contract

The notch is always in exactly one state. The rules live in `NotchMachine`, a
plain value with a test for each rule; `NotchController` feeds it events and runs
its timer.

| State   | Entered by                               | Left by                                                    |
|---------|------------------------------------------|------------------------------------------------------------|
| Idle    | default                                  | hover → Peek, click → Shelf, new shot → Preview            |
| Peek    | hovering the notch past the intent delay | pointer leaves (after a grace period) → Idle, click → Shelf, new shot → Preview |
| Shelf   | a click on the notch, or "+N" in Peek    | click outside or switching apps, Esc or ⌘W, Return (copies) → Idle |
| Preview | a new screenshot, from Idle or Peek      | its timer ends, or acting on it → Idle; click → Shelf      |

- A click on the notch itself opens the Shelf from any state. A click on a shot
  copies it; buttons do what they say.
- Acting on the Preview (copy, markup, pin, trash) finishes it: the notch closes
  with feedback. In Peek and the Shelf, acting leaves them open.
- Hovering holds the Preview's timer. Leaving resumes it, never with less than
  `Timing.previewResumeMinimum` left.
- While feedback offers Undo, hovering doesn't open Peek: the pointer is aiming
  at the Undo. Once it goes, a pointer still resting there opens Peek.
- While one of its menus is open, the notch stays as it is: the pointer is on
  the menu, not gone.
- A successful drop finishes the notch from any state. A cancelled drag puts
  everything back.
- The machine has at most one timer, and every transition replaces it, so a
  timer can never outlive its state. Feedback has its own timer.
- Feedback ("Copied", "Trashed · Undo") is not a state. It is one slot any state
  can show; a new message replaces the old one.
- Hover is geometry: the pointer's position against `NotchLayout.hoverZone`,
  from a global mouse monitor plus the notch's own hover events. No invisible
  views, so nothing blocks clicks underneath.
- Esc always goes back exactly one level: a menu, then the selection, then the
  Shelf.
- Only the Shelf takes the keyboard. Peek and the Preview never take it from
  the app the user is typing in, and the moment the Shelf closes the keyboard
  goes straight back. Quick Look and the folder picker take it while they show.
- The Shelf's keys: arrows move the focus, Esc or ⌘W closes, Return copies
  and closes (so ⌘V pastes into the user's app), ⌘C copies, Space opens Quick
  Look, ⌫ or ⌘⌫ trashes (the focus moves on to the next shot), ⌘Z puts the
  last trash back, P or ⌘P pins, ⌘A selects all.
- The focus is one shot: the one under the pointer, or the one the arrow keys
  reached. Shots scrolling under a resting pointer don't take it back.
- ⌘-click selects in the Shelf. While there's a selection, keys, the menu and
  drags act on all of it. A plain click clears it and copies that one shot. The
  selection belongs to the Shelf and goes when it closes.
- A shot taken while the Shelf is open lands in the Shelf; it does not interrupt.
- During a drag the notch steps aside, and comes back if the drag returns.

Adding a state or a transition means updating this table first.

## Architecture

```
Pluck/
  App/         entry point, menu bar item, window wiring
  Core/        shots, folder watching, index, cleanup, macOS settings (no SwiftUI)
  Notch/       the notch panel, NotchController, and its views
  Settings/    Preferences and the Settings window
  Onboarding/  first-run flow
  Design/      Theme: every token the UI uses
PluckTests/
```

- `Core/` never imports SwiftUI. Views never touch `FileManager`, the pasteboard
  or `UserDefaults` directly; they call the model that owns that thing.
- One owner per piece of state: the shot library owns shots, `NotchController`
  owns the notch state, `Preferences` owns settings.
- `@Observable` models, main actor by default. Background work only for file I/O
  and thumbnails.
- Inject only what a test needs (the folder URL, the clock).
- Dependencies: Sparkle and KeyboardShortcuts. Anything else is discussed first.

## Design system

- Every spacing, size, radius, color, font and animation in a view comes from
  `Design/Theme.swift`. A raw number or color literal in a view is a bug (0 is
  fine).
- System fonts and semantic colors first. Custom colors only for the brand accent
  and the notch surfaces.
- Motion uses the two Theme springs, one for opening and one for closing. No
  one-off animations.
- Notch content moves as one piece with the shape: it's clipped to the notch
  and enters through `Motion.contentTransition` on the shape's own spring. No
  delays, no per-element staggers; nothing should make the user wait on an
  animation. It leaves quickly, before the shape closes.
- The notch surface is Liquid Glass (`notchSurface(radius:)`), pure black
  level with the hardware notch.
- Changes to the system happen in Theme and are reviewed by Alex in the Design
  System window (debug builds: menu bar, Design System…). A new token gets a
  specimen there in the same change.
- The notch's text and fills use the native dark hierarchy (`.primary`,
  `.secondary`, `.tertiary`, `.fill.*`). Color carries meaning only: accent,
  copied, trashed, pinned.

## Naming

One name per concept, in code and in UI copy:
**shot** (a screenshot Pluck tracks), **the notch** (the panel, even on screens
without a physical notch), **Idle / Peek / Shelf / Preview** (its states),
**pin** / **pinned**, **feedback** (the one-slot status message).

## Code style

- Comments explain why, not what. Most code needs none.
- Prefer a plain function to a type, and a type to a protocol.
- Mark a deliberate shortcut with a `// ponytail:` comment naming its limit and
  the upgrade path.

## Testing

- Swift Testing. A test states a rule of the app a user would notice breaking:
  state transitions, cleanup policy, shelf layout, index persistence.
- Hermetic: temp directories and an injected clock. No test reads the real
  screenshot folder or writes `com.apple.screencapture`.
- No UI or snapshot tests.
- Run: `xcodebuild test -project Pluck.xcodeproj -scheme Pluck -destination 'platform=macOS'`

## Project

- The Xcode project uses synced folders: a new file under `Pluck/` or
  `PluckTests/` is in the build automatically. Edit `project.pbxproj` only for
  build settings.
- Swift 6 language mode, main actor by default. Not sandboxed, hardened runtime.
- Unit tests run inside the app, so `AppDelegate` starts nothing under XCTest.
  Anything that touches the system starts from there.

## Workflow

- Until the first release, commit straight to `main`. After it, one branch and
  one PR per change, and `main` stays release-ready.
- Spikes live on `spike/*` branches and are never merged; what they prove is
  written into Platform facts below.

## Platform facts

Verified on this machine; each one notes how.

- **Screenshot tag.** macOS writes the extended attribute
  `com.apple.metadata:kMDItemIsScreenCapture` on every capture, and it survives
  renames and moves. Read the attribute directly; don't depend on Spotlight
  being enabled. (Checked with `xattr -l` on a renamed capture, 2026-10-17.)
- **Notch geometry.** `NSScreen.auxiliaryTopLeftArea` and
  `auxiliaryTopRightArea` are non-nil only on a notched screen; the gap between
  them is the notch (185 × 32 pt on a 14″ MacBook Pro). Screens without them
  get the pill. (Read from `NSScreen`, 2026-10-17.)
- **Screenshot settings defaults.** A missing `location` key means Desktop, a
  missing `show-thumbnail` key means the floating thumbnail is on.
- **The thumbnail delays the file.** With the macOS floating thumbnail on, the
  file lands 5 to 7 s after capture; with it off, about 1 s. The Pluck preview
  only works with the thumbnail off. Writing `show-thumbnail` through
  `CFPreferences` takes effect on the next capture, with no restart of anything.
- **How a capture lands.** macOS first writes a hidden, untagged temp file
  (`.Screenshot …png` or `..Screenshot …png-XXXX`), then renames it to the
  final, tagged name. Ignore dot-files and act only on the tagged file. A
  `DispatchSource` on the folder fires for the rename.
- **File names are not plain ASCII.** The space before AM/PM is U+202F (narrow
  no-break space), and the format follows the user's locale. Never parse or
  build screenshot names by hand.
- **The panel.** A borderless `.nonactivatingPanel` `NSPanel` at `.statusBar`
  level draws over the menu bar at the notch. Pluck doesn't rely on macOS
  passing clicks through its transparent pixels: the panel ignores the mouse,
  and the controller turns the mouse on exactly while the pointer is on the
  notch's shape (`NotchLayout.shapeRect`).
- **Pointer moves don't reach every app.** A global mouse-moved monitor misses
  moves over some apps' windows (macOS only sends them to apps tracking the
  mouse). Pluck samples `NSEvent.mouseLocation` as a backstop, 30 times a second
  while the notch is open and 10 at rest. A listen-only event tap would be
  event-driven, but receives nothing without Input Monitoring. (Checked
  2026-10-17.)
- **Use the event's own location, from Quartz.** In a monitor callback,
  `NSEvent.mouseLocation` can still be the previous position when the pointer
  jumps. `locationInWindow` isn't safe either: a global event can still name one
  of Pluck's windows (just after the Shelf takes the keyboard), and then it is
  in that window's coordinates. `event.cgEvent.location` is always global, top
  down from the primary display. (Caught as a stray "click outside" that closed
  the Shelf about one launch in three, 2026-10-17.)
- **The keyboard without activating.** A `.nonactivatingPanel` whose
  `canBecomeKey` is true becomes key without bringing Pluck forward: the user's
  app keeps the menu bar, and AppKit reports `NSApp.isActive`. To give the
  keyboard back, `NSApp.deactivate()`; `NSApp.hide` leaves it with the notch.
  A local key monitor sees keys before the app's menus, which would otherwise
  take ⌘C and ⌘Z. Switching to another app posts no resign-active
  notification in this state; the panel resigning key while `NSApp.isActive`
  is false is the signal. (Checked by typing into TextEdit after the Shelf
  closed, and by activating Finder, 2026-10-17.)
- **Quick Look and the folder picker need Pluck truly active.** With only the
  notch key, their keys go to the user's app. `NSApp.activate()` works once the
  notch has the keyboard, and is refused before. Afterwards `NSApp.hide` gives
  the keyboard back; `deactivate` doesn't. Quick Look is still the key window
  during its will-close notification.
- **Showing resets a window's level.** Quick Look and `NSOpenPanel` take their
  level when they show, so it's set after they show. `runModal` blocks until
  the panel closes, so the picker uses `begin`. Below `.statusBar` + 1, the
  Shelf covers them.
- **A lazy stack keeps what it drew for an ID.** If an ID comes back with new
  content, `LazyVStack` can draw the old content. Shelf rows are identified by
  all of their shots.
- **SwiftUI gestures fire through AppKit views.** A tap gesture on a container
  also fires for a click an embedded `NSView` already handled. Notch-level
  clicks live on a layer behind the content, never on a container of it.
- **First click.** `NSHostingView` swallows the first click on a non-key
  panel, so a tap needs two clicks. The notch's hosting view must return true
  from `acceptsFirstMouse`.
- **Hover.** SwiftUI `onHover` works in a non-activating panel of a menu-bar
  app with no permission. It flaps in under 100 ms at the edge of a shape that
  is animating, so hover needs an enter delay and a leave grace period.
- **The hardware notch hides the cursor.** The hover zone must reach below
  the notch, so nobody has to push the pointer into the camera housing.
- **Drag out is AppKit.** An `NSDraggingSource` started from the panel gets
  `draggingSession(_:endedAt:operation:)` with `.copy` on a successful drop.
  SwiftUI's drag APIs have no end callback.
- **Quick Look has no Markup.** `QLPreviewPanel` offers only Share and "Open
  with Preview". QuickLookUI has no public Markup or editing API.
- **The folder prompt blocks.** The first read of Desktop, Documents or
  Downloads shows the macOS access prompt and blocks that thread until it's
  answered. Onboarding must trigger it on purpose, at its "Allow Access" step.
- **Simulating a capture.** The `screencapture` command-line tool tags its
  files the same way ⇧⌘4 does, so `screencapture -x -R 0,0,200,100 <path>`
  lands a real, tagged screenshot without anyone at the keyboard.
- **Clicks fall through where nothing claims them.** Whether a click reaches
  the notch or the app underneath is decided by hit-testing, not by what's
  drawn. Anything inside the notch must be hit-testable, or a click on it lands
  in the app below and closes the notch.
- **Clipping doesn't trim hit-testing.** An image scaled to fill and then
  clipped still catches presses across its whole unclipped size. A filling
  thumbnail must not take the pointer (`allowsHitTesting(false)` on the image),
  or a wide screenshot steals presses from the tiles beside it.
- **Drop destinations choose the operation.** Offer copy, move and generic, as
  Finder does. TextEdit and others refuse a file drop unless generic is
  offered; Finder moves within a disk.
- **Liquid Glass works in the notch panel** over other apps' windows. (Checked
  with a live Preview over a terminal, 2026-10-17.)
- **Not yet verified:** switching Spaces, full-screen apps, external displays,
  and a cancelled drag (documented as operation 0).

The panel, landing, hover, drag and Quick Look facts were checked with the
throwaway app on `spike/platform`, 2026-10-17.
