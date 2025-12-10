# Pluck Architecture - Unified Sizing System

## Overview

This document describes the unified panel sizing and positioning system for Pluck. The architecture is inspired by apps like boringNotch but adapted for a floating side panel design.

## Core Principle

**Single Source of Truth**: All panel sizing, positioning, and frame calculations happen in one place: `PanelDimensions.swift`

## File Structure

```
┌─────────────────────────────────────────────────────────────  ┐
│                                                               │
│  PanelDimensions.swift                                        │
│  ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━      │
│  • Constants (sizes, margins, radii)                          │
│  • size(for:screenHeight:) -> CGSize                          │
│  • calculateFrame(for:dockedEdge:yFromTop:screen:) -> NSRect  │
│                                                               │
└───────────────────────────┬───────────────────────────────────┘
                            │
                ┌───────────┴───────────┐
                │                       │
                ▼                       ▼
    ┌───────────────────────┐   ┌──────────────────┐
    │ FloatingPanelView     │   │ WindowManager    │
    │ (SwiftUI)             │   │ (State Manager)  │
    │                       │   │                  │
    │ • Uses size()         │   │ • panelState     │
    │ • Renders views       │   │ • dockedEdge     │
    └───────────────────────┘   │ • dockedYPos     │
                                └─────────┬────────┘
                                          │
                                          ▼
                            ┌─────────────────────────┐
                            │ FloatingPanelController │
                            │ (AppKit Window Manager) │
                            │                         │
                            │ • Uses calculateFrame() │
                            │ • Manages NSPanel       │
                            └─────────────────────────┘
```

## Key Components

### 1. PanelDimensions (Unified Sizing System)

**Purpose**: Single source of truth for all sizing logic

**Key Functions**:
```swift
// Returns the appropriate size for any panel state
static func size(for state: PanelState, screenHeight: CGFloat) -> CGSize

// Calculates complete frame (size + position)
static func calculateFrame(
    for state: PanelState,
    dockedEdge: DockedEdge,
    yFromTop: CGFloat,
    screen: NSScreen
) -> NSRect
```

**Benefits**:
- ✅ No duplicate switch statements
- ✅ Consistent sizing across SwiftUI and AppKit
- ✅ Easy to modify sizes (change once, updates everywhere)
- ✅ Screen-aware calculations

### 2. WindowManager (State Management)

**Purpose**: Manages panel state and navigation

**Responsibilities**:
- Tracks current `PanelState` (collapsed, folderList, folderOpen, imageFocused)
- Manages docking position (`dockedEdge`, `dockedYPosition`)
- Handles navigation (collapse, showFolderList, openFolder, focusImage, goBack)
- Notifies observers when state changes

**Does NOT**:
- ❌ Calculate sizes
- ❌ Position windows
- ❌ Manage NSPanel directly

### 3. FloatingPanelController (Window Management)

**Purpose**: Manages the AppKit NSPanel window

**Responsibilities**:
- Creates and configures the NSPanel
- Updates panel frame when state changes
- Handles keyboard shortcuts and paste operations
- Manages model container and environment objects

**Key Method**:
```swift
func updatePanelFrame(animated: Bool = false) {
    // Uses PanelDimensions.calculateFrame() - no manual calculations!
    let newFrame = PanelDimensions.calculateFrame(
        for: windowManager.panelState,
        dockedEdge: windowManager.dockedEdge,
        yFromTop: windowManager.dockedYPosition,
        screen: screen
    )
    panel.setFrame(newFrame, display: true)
}
```

### 4. FloatingPanelView (SwiftUI Interface)

**Purpose**: Renders the panel UI

**Responsibilities**:
- Displays icon/header (always visible)
- Shows appropriate content based on state
- Handles drag gestures for repositioning
- Manages drop targets

**Sizing**:
```swift
private var currentWidth: CGFloat {
    let size = PanelDimensions.size(
        for: windowManager.panelState,
        screenHeight: screen.visibleFrame.height
    )
    return size.width
}
```

## State Flow

```
User Action → WindowManager.showFolderList()
              ↓
WindowManager.panelState = .folderList
              ↓
NotificationCenter posts .panelStateChanged
              ↓
FloatingPanelController receives notification
              ↓
controller.updatePanelFrame()
              ↓
PanelDimensions.calculateFrame(...) 
              ↓
NSPanel.setFrame(newFrame)
              ↓
SwiftUI view updates (observes windowManager.panelState)
```

## Panel States

| State | Size | Content |
|-------|------|---------|
| `.collapsed` | 50×50 | Icon only |
| `.folderList` | 220×(55% of screen) | Folder cards list |
| `.folderOpen(folder)` | 220×(55% of screen) | Image grid for folder |
| `.imageFocused(image)` | 340×450 | Large image viewer |

## Positioning System

**Coordinate System**: macOS uses bottom-left origin

**Y Position Storage**: Stored as "distance from top" for consistency
```swift
yFromTop = screen.maxY - window.origin.y - window.height
```

**Docking**: Can dock to left or right edge
```swift
enum DockedEdge { case left, right }
```

**Edge Margin**: Currently 0 (can be changed in PanelDimensions.edgeMargin)

## Migration Notes

### What Changed

**Before**:
- ❌ Size calculations in 3 places (FloatingPanelView, FloatingPanelController, PanelDimensions)
- ❌ Duplicate switch statements for sizing
- ❌ Separate `calculateOrigin()` and `sizeForCurrentState()` methods
- ❌ `CollapsedView.swift` as separate file

**After**:
- ✅ Single unified sizing system in `PanelDimensions`
- ✅ One function: `size(for:screenHeight:)` 
- ✅ One function: `calculateFrame(...)` for complete frame calculation
- ✅ Collapsed icon integrated into `FloatingPanelView` as `PanelIconView`
- ✅ `CollapsedView.swift` marked as deprecated (can be deleted)

### Cleanup Checklist

- [x] Unified sizing in PanelDimensions
- [x] Updated FloatingPanelController to use unified system
- [x] Updated FloatingPanelView to use unified system
- [ ] Delete CollapsedView.swift (currently marked deprecated)
- [ ] Remove any unused imports/references

## Benefits of This Architecture

1. **Maintainability**: Change a size constant once, updates everywhere
2. **Consistency**: Same logic for SwiftUI preview and actual window
3. **Testability**: Pure functions for sizing calculations
4. **Clarity**: Clear separation of concerns (state vs. sizing vs. rendering)
5. **Flexibility**: Easy to add new panel states or modify existing sizes

## Adding a New Panel State

1. Add case to `PanelState` enum in `WindowManager.swift`
2. Add size logic to `PanelDimensions.size(for:screenHeight:)` 
3. Add content view to `FloatingPanelView.expandedContent`
4. Add navigation method to `WindowManager`

That's it! No need to update multiple switch statements or duplicate logic.

## Example: Adding a Settings Panel

```swift
// 1. WindowManager.swift
enum PanelState {
    case collapsed
    case folderList
    case folderOpen(DesignFolder)
    case imageFocused(DesignImage)
    case settings // NEW
}

// 2. PanelDimensions.swift
static func size(for state: PanelState, screenHeight: CGFloat) -> CGSize {
    switch state {
    case .collapsed: return collapsedSize
    case .folderList, .folderOpen: 
        return CGSize(width: folderListWidth, 
                      height: collapsedSize.height + listContentHeight(screenHeight: screenHeight))
    case .imageFocused:
        return CGSize(width: imageDetailWidth, 
                      height: collapsedSize.height + imageDetailContentHeight)
    case .settings: // NEW
        return CGSize(width: 300, height: 400)
    }
}

// 3. FloatingPanelView.swift
@ViewBuilder
private var expandedContent: some View {
    switch windowManager.panelState {
    case .collapsed: EmptyView()
    case .folderList: FolderListContentView()
    case .folderOpen(let folder): FolderDetailContentView(folder: folder)
    case .imageFocused(let image): ImageDetailContentView(image: image)
    case .settings: SettingsContentView() // NEW
    }
}

// 4. WindowManager.swift
func showSettings() {
    panelState = .settings
    notifyStateChanged()
}
```

Done! Everything else updates automatically.

---

**Last Updated**: December 10, 2025
**Architecture Version**: 2.0 (Unified Sizing System)
