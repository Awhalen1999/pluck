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

## Product rules

- Pluck **watches**, it never captures. macOS takes the screenshot; Pluck picks
  up the file.
- Pluck only touches files tagged as screenshots (see Platform facts). Every
  other file in the folder is left alone.
- Removing a shot always means `FileManager.trashItem`, never a delete, so
  Finder's Put Back works. Pinned shots are never removed by cleanup.
- Pluck changes the macOS screenshot settings (save location, floating
  thumbnail) only through the user's choices, snapshots the originals on first
  launch, and can restore them from About.
- Nothing leaves the Mac. The only network use is Sparkle's update check.

## The notch state contract

The notch is always in exactly one state. `NotchController` owns it, and every
transition goes through it.

| State   | Entered by                          | Left by                                          |
|---------|-------------------------------------|--------------------------------------------------|
| Idle    | default                             | hover → Peek, click → Shelf, new shot → Preview  |
| Peek    | hovering the notch                  | pointer leaves → Idle, click → Shelf             |
| Shelf   | click, shortcut, or "+N" in Peek    | click outside, Esc, or shortcut → Idle           |
| Preview | a new screenshot                    | its timer ends (hover pauses it) → Idle          |

- Every timer belongs to a state and is cancelled when the state changes.
- Feedback ("Copied", "Moved to Trash · Undo") is not a state. It is one slot any
  state can show; a new message replaces the old one.
- Esc always goes back exactly one level.
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
- Changes to the system happen in Theme and are reviewed by Alex.

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

## Workflow

- One branch and one PR per change. `main` is always release-ready.
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
- **No Markup API.** QuickLookUI has no public editing or Markup API. (Searched
  the macOS SDK headers, 2026-10-17.)
