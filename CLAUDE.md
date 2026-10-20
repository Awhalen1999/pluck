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
  Finder's Put Back works. The one exception is the hand-off folder: what a drag
  left there is deleted after an hour.
- A capture waits for its Preview, as one waits behind the macOS thumbnail.
  macOS saves it into Pluck's holding folder (Application Support/Pluck/Pluck,
  so ⇧⌘5's Options say "Pluck"), and it reaches the user's folder only once
  the Preview is done with it: acted on, its time up, the Shelf opened, or
  Pluck quitting. Trashed, it goes straight there and never touches
  the user's folder. Anything left waiting by a crash is saved at the next
  launch.
- A drag hands shots off, by one rule: the shot's own file moves into Pluck's
  hand-off folder (in the temporary folder) for the drag, and the drop gets it.
  - Into a Finder folder, Finder moves it there, like any file, and that's
    where it's kept. One file, no "replace?", even dropped back on the Desktop.
  - Into an app, it stays in the hand-off folder an hour, so the app can read it
    (a path dropped in a terminal still works), and the shot leaves Pluck.
  - A cancelled drag moves it back. Nothing changes under a drag: the shot
    stays listed while its file is away.
  - Onto the Trash, it's trashed as the Trash button does it: back where it
    was first, so Put Back and Undo work.
  - Pinned shots, and saved shots when the user keeps what they drag out, go
    as themselves. A waiting capture the user keeps is saved as a copy once
    dropped into an app.
- Cleanup rules (approved by Alex):
  - Pinned shots are always kept. There is no setting to turn that off.
  - Shots taken before Pluck's first launch are never removed automatically.
  - Unpinning restarts a shot's clock, so it never vanishes the moment it's
    unpinned.
  - Renaming a shot keeps its pin. An unpinned renamed shot is still cleaned
    up on schedule.
- Pluck changes the macOS screenshot settings (save location, floating
  thumbnail) only through the user's choices. It snapshots the originals once
  ever, before changing anything, and About's Restore puts back exactly that
  snapshot, "never set" included, and switches Pluck's Preview off. Until the
  user picks Pluck's Preview in onboarding, the Preview is the macOS one.
- Onboarding runs until it's finished. Its window has no close button, so
  Pluck is never left running half set up: finishing or quitting are the ways
  out. Quitting partway brings it back at the next launch, at the save location;
  About's "Show the welcome again" brings it back from the start. A choice in it
  that changes macOS takes effect when it's made: the save folder when picked,
  the Preview and login item on Continue.
- Pluck doesn't look in the screenshot folder until onboarding asks for it, so
  the macOS access prompt comes at its "Allow Access" step, never at launch.
- With Preview set to Pluck, the macOS thumbnail is off and macOS saves into
  the holding folder while Pluck runs. Quitting, or switching to the macOS
  Preview, gives macOS the user's own: their thumbnail as it was, and their
  "Save to" folder. With the macOS Preview the thumbnail is theirs, and Pluck
  never writes it. If macOS doesn't take a change, the Preview setting becomes
  macOS, so it always says what's really happening, and there are never two
  previews.
- "Save to" is Pluck's record of the user's folder. At launch, a location the
  user chose in macOS while Pluck wasn't running is followed, unless it's still
  the holding folder (after a crash). A folder deleted while Pluck runs is made
  again when a capture is saved; one gone at launch falls back to the Desktop.
- ⇧⌘5's Options change macOS's settings directly, and the user's choice there
  wins, Pluck running or not: a folder becomes "Save to" (and Pluck holds again),
  and turning on the floating thumbnail switches the Preview to macOS's.
- The only permission Pluck asks for is access to the screenshot folder. No
  Accessibility, Screen Recording, Input Monitoring or Automation: v1 has no
  global shortcuts and no auto-paste, so it needs none.
- Settings changes take effect at once, never after a restart.
- Nothing leaves the Mac. The only network use is Sparkle's update check.
- Markup opens the shot in Preview. Pluck never builds its own editor.
- The notch stays on the display chosen in "Show on". A Preview appears there,
  whichever display the screenshot was taken on.

## The notch state contract

The notch is always in exactly one state. The rules live in `NotchMachine`, a
plain value with a test for each rule; `NotchController` feeds it events and runs
its timer.

| State   | Entered by                               | Left by                                                    |
|---------|------------------------------------------|------------------------------------------------------------|
| Idle    | default                                  | hover → Peek, click → Shelf, new shot → Preview            |
| Peek    | hovering the notch past the intent delay | pointer leaves (after a grace period) → Idle, click → Shelf, new shot → Preview |
| Shelf   | a click on the notch, or "+N" in Peek    | click outside or switching apps, Esc or ⌘W, Return (copies) → Idle; new shot → Preview |
| Preview | a new capture, from any state            | the last waiting capture dealt with, or its time up → Idle; click → Shelf; new capture → it, in front |

- A click on the notch itself opens the Shelf from any state. A click on a shot
  copies it; buttons do what they say.
- The Preview is a stack: every waiting capture, newest in front. Acting on the
  front one (copy, markup, pin, trash, a drop) deals with it and the next comes
  up; with none left the notch closes. Leaving the Preview any other way saves
  what it still holds. In Peek and the Shelf, acting leaves them open.
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
  can show; a new message replaces the old one. The Preview's header is too
  narrow for it, so there it floats on the card.
- Hover is geometry: the pointer's position against `NotchLayout.hoverZone`,
  from a global mouse monitor plus the notch's own hover events. No invisible
  views, so nothing blocks clicks underneath.
- The intent delay counts from when the pointer slows down on the notch. One
  sweeping across it along the menu bar is passing over, and never opens Peek.
- Esc always goes back exactly one level: a menu, then the selection, then the
  Shelf.
- Only the Shelf takes the keyboard. Peek and the Preview never take it from
  the app the user is typing in, and the moment the Shelf closes the keyboard
  goes straight back. Quick Look takes it while it shows.
- The Shelf's keys: arrows move the focus, Esc or ⌘W closes, Return copies
  and closes (so ⌘V pastes into the user's app), ⌘C copies, Space opens Quick
  Look, ⌫ or ⌘⌫ trashes (the focus moves on to the next shot), ⌘Z puts the
  last trash back, P or ⌘P pins, ⌘A selects all.
- The focus is one shot: the one under the pointer, or the one the arrow keys
  reached. Shots scrolling under a resting pointer don't take it back.
- ⌘-click selects in the Shelf. While there's a selection, keys, the menu and
  drags act on all of it. A plain click clears it and copies that one shot. The
  selection belongs to the Shelf and goes when it closes.
- A new shot always opens its Preview, from any state. Only a drag holds it
  back: nothing changes under a drag.
- During a drag the notch steps aside, and comes back if the drag returns.

Adding a state or a transition means updating this table first.

## Architecture

```
Pluck/
  App/         entry point, menu bar item, window wiring
  Core/        shots, folder watching, index, cleanup, macOS settings (no SwiftUI)
  Notch/       the notch: its panel, state machine, controller, input, views
  Settings/    Preferences and the Settings window
  Onboarding/  first-run flow
  Design/      Theme: every token the UI uses
PluckTests/
```

- `Core/` never imports SwiftUI. Views never touch `FileManager`, the pasteboard
  or `UserDefaults` directly; they call the model that owns that thing.
- One owner per piece of state: the shot library owns shots, `NotchController`
  owns the notch state, `Preferences` owns Pluck's own settings and how far
  onboarding got, and
  `ScreenshotSetup` owns where screenshots go and which preview shows them.
  Settings changes those two only through it. The system owns "Open at login",
  read from `SMAppService` each time and never stored.
- `@Observable` models, main actor by default. Background work only for file I/O
  and thumbnails.
- Inject only what a test needs (the folder URL, the clock).
- Dependencies: Sparkle. Anything else is discussed first.

## Design system

- Every spacing, size, radius, color, font and animation in a view comes from
  `Design/Theme.swift`. A raw number or color literal in a view is a bug (0 is
  fine).
- System fonts and semantic colors first. Custom colors only for the brand accent
  and the notch surfaces.
- The shape has one animation, keyed to its frame: it springs open when it
  grows and settles when it shrinks, whatever changed it. Nothing else in the
  notch animates on its own; hovers, presses and selection change at once.
- Notch content moves as one piece with the shape: it's clipped to the notch
  and enters through `Motion.contentTransition` on the shape's own spring. No
  delays, no per-element staggers; nothing should make the user wait on an
  animation. It leaves quickly, before the shape shrinks.
- The notch is plain black (`NotchShape`). Hanging from a notched screen, its
  top corners flare out into the edge, so it reads as the hardware notch grown;
  elsewhere it floats, rounded all round. No glass, no shadow.
- Tokens are reviewed in the Design System window (debug builds: menu bar,
  Design System…); the notch itself is reviewed live. A new visual token gets
  a specimen there in the same change.
- The notch's text and fills use the native dark hierarchy (`.primary`,
  `.secondary`, `.tertiary`, `.fill.*`). Color carries meaning only: accent,
  copied, trashed, pinned.

## Naming

One name per concept, in code and in UI copy:
**shot** (a screenshot Pluck tracks), **the notch** (the panel, even on screens
without a physical notch), **Idle / Peek / Shelf / Preview** (its states),
**pin** / **pinned**, **feedback** (the one-slot status message).

In copy, "screenshot" in sentences and in Settings; "shot" only where the notch
is short of room ("3 shots"). Settings copy names the choice in the label and
says what happens in one plain line below it.

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
  AppKit can go on reporting the notch as `keyWindow` after it let go.
  A local key monitor sees keys before the app's menus, which would otherwise
  take ⌘C and ⌘Z. Switching to another app posts no resign-active
  notification in this state; the panel resigning key while `NSApp.isActive`
  is false is the signal. (Checked by typing into TextEdit after the Shelf
  closed, and by activating Finder, 2026-10-17.)
- **Quick Look needs Pluck truly active.** With only the notch key, its keys go
  to the user's app. `NSApp.activate()` works once the
  notch has the keyboard, and is refused before. Afterwards `deactivate`
  doesn't give the keyboard back; activating the app that was frontmost does.
  (`NSApp.hide` also works, but hides Pluck's other windows with it.) Quick
  Look is still the key window during its will-close notification.
- **Showing resets a window's level.** Quick Look takes its level when it
  shows, so it's set after it shows. Below `.statusBar` + 1, the Shelf covers
  it.
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
  answered. Onboarding triggers it on purpose, at its "Allow Access" step, from
  a background thread. Allowing in System Settings › Files & Folders asks for
  Touch ID or a password; `tccutil reset SystemPolicyDesktopFolder
  app.pluck.Pluck` puts the prompt back without one.
- **A prompt hands activation away.** Once the access prompt is answered,
  macOS activates the app the user was in before, never a menu bar app, and
  refuses `NSApp.activate()`; `NSApp.activate(ignoringOtherApps: true)` still
  works. At launch from another app (a terminal, say), `NSApp.activate()` can be
  refused too; `orderFrontRegardless` shows the onboarding window anyway.
  (Checked 2026-10-19.)
- **SwiftUI sizes the window it's hosted in.** Under the SwiftUI app lifecycle,
  an `NSHostingController` or `NSHostingView` resizes its window to the content
  plus the title bar as it lays out, whatever `sizingOptions` says. Size the
  content, and center the window after `layoutIfNeeded`. (Checked 2026-10-19.)
- **A folder Pluck can't read has no icon.** `NSWorkspace.icon(forFile:)` gives
  a generic file icon for it; onboarding shows the plain folder icon.
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
- **Two changes in one update animate apart.** When the library's shots change
  (no animation) and the state changes in an animated transaction in the same
  update, SwiftUI applies the first at once and animates from there: the Shelf
  jumped to fit a new shot before shrinking into its Preview. So the shape's
  animation hangs off its frame (`.animation(_:value: frame)`), never off events.
- **A scale animation on a clipped image smears.** Animating `scaleEffect` on a
  tile whose filled image is clipped drew the image shifted sideways for a few
  frames as the hover ended. Tiles don't scale.
- **`Optional.take()`.** On an implicitly unwrapped optional, `x.take()` calls
  the standard library's `Optional.take()`, which returns the value and sets
  `x` to nil. Long-lived collaborators are plain `let`s.
- **Drop operations.** Finder moves a dragged file within a disk (operation 16);
  TextEdit copies (1). `FileManager.copyItem` clones on APFS, so a kept
  capture's copy is free. (Checked 2026-10-18.)
- **The save location takes at once.** Writing `location` through
  `CFPreferences` sends the next capture there, with no restart, ⇧⌘3 included
  (one file per display). (Checked 2026-10-18.)
- **A button's own action doesn't animate it.** State changed in a SwiftUI
  `Button`'s action reaches every view on the implicit animation except the
  button itself, which jumps to its new place. The notch's buttons are a
  `PrimitiveButtonStyle` that triggers on a tap gesture. (Checked frame by
  frame, 2026-10-18.)
- **An AppKit view takes clicks under SwiftUI drawn over it.** A SwiftUI
  `Button` overlaid on an `NSViewRepresentable` never gets its click; the
  AppKit view does. Anything clickable over a shot's interaction view needs that
  view kept clear of it. (Caught as the Preview's floating Undo copying the
  card, 2026-10-18.)
- **Finder asks before replacing.** A file dropped into a folder that has one
  of the same name gets Finder's Keep Both / Stop / Replace prompt, and the drag
  has already ended with `.move` by then. Hence drags carry the shot's own
  file: there's never a second one of the same name.
- **TextEdit asks about a drop.** Dropped into a plain-text document, TextEdit
  ends the drag as a copy, then asks whether to convert the document; Cancel
  there doesn't undo the drop. Dropped into a rich-text one, it asks to convert
  it to RTFD with the drag still open, and Cancel ends it as cancelled, after
  which TextEdit itself can hang. Test drops into a plain-text document.
  (Checked 2026-10-19.)
- **Opening Settings from code.** `showSettingsWindow:` does nothing on macOS 26.
  SwiftUI still puts its Settings… item in the app menu of a menu bar app that
  shows no menus, and sending that item's action opens Settings. In SwiftUI
  views, `openSettings` works too; Pluck uses the menu item everywhere.
- **SwiftUI quits a menu bar app whose icon is hidden** when its last window
  closes: with `MenuBarExtra(isInserted:)` false, closing Settings terminated
  Pluck. `applicationShouldTerminateAfterLastWindowClosed` returns false.
- **No reopen for an active app.** Opening Pluck while it's already active (its
  last window just closed) sends no reopen event, so closing Pluck's last
  window hands activation back (`NSApp.hide`).
- **SwiftUI's Settings window can't become main.** "Regular" windows are the
  titled ones that aren't panels.
- **Login items.** `SMAppService.mainApp.register()` registers the app where it
  is, a debug build included, and macOS shows "Login Item Added". Don't read
  login items with `sfltool` in tests: it can ask for an admin password.
- **The app icon is an Icon Composer file.** `Pluck/AppIcon.icon` is built
  straight into `Assets.car` and `AppIcon.icns`; its name is the
  `ASSETCATALOG_COMPILER_APPICON_NAME`. A build path macOS saw before it had an
  icon keeps the cached one until `lsregister -f` on the app. (Checked
  2026-10-19.)
- **The menu bar icon is a template image.** `MenuBarIcon` is an SVG marked
  template in the asset catalog, so macOS colors it for light and dark menu
  bars and highlights it when clicked. It shows the notch with a shot dropping
  out; two overlapping cards would read as Screen Mirroring.
- **The user's accent color wins.** A system-wide accent other than multicolor
  overrides the app's AccentColor in native controls.
- **Full-screen apps.** The notch shows over a full-screen app, which is its own
  Space: a Preview appears there, and hovering opens Peek while macOS slides its
  menu bar in beside it. (Checked 2026-10-19.)
- **The Trash deletes.** Dropped on the Dock's Trash, a drag ends with `.delete`
  (32), offered or not, and the file stays put: the source is to delete it.
- **Watching another app's preferences.** Key-value observing a defaults suite
  (`UserDefaults(suiteName:)`) reports changes other processes make, deletions
  included, on the main thread. (Checked with `defaults write`, 2026-10-19.)
- **⇧⌘5 writes at once, and remembers.** Its Options menu writes `location` and
  `show-thumbnail` the moment an item is chosen, and names the location folder by
  its own name. The toolbar's agent (`screencaptureui`, which outlives the
  toolbar) keeps the folder chosen there, so a capture taken from the toolbar
  goes to it even after the setting changes back; ⇧⌘3 and ⇧⌘4 follow the
  setting. Its menu ignores a quick synthetic click; press, pause, release.
- **A saved capture keeps its file.** Moving from the holding folder to the
  user's keeps the file's identity (`fileIdentifierKey`), so its thumbnail is
  cached by that, not by path.
- **Not yet verified:** whether access
  allowed in System Settings counts without relaunching Pluck (Pluck looks again
  whenever it becomes active).

The panel, landing, hover, drag and Quick Look facts were checked with the
throwaway app on `spike/platform`, 2026-10-17.
