import SwiftUI

/// The menu bar item: Settings, Quit, and the latest screenshot.
struct MenuBarMenu: View {
    let notch: NotchController?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Copy Latest Screenshot") { notch?.copyLatest() }
            .disabled(notch.map { $0.library.shots.isEmpty && $0.library.pending.isEmpty } ?? true)
        Divider()
        Button("Settings…") { openSettings() }
            .keyboardShortcut(",")
        #if DEBUG
        Button("Design System…") {
            openWindow(id: DesignSystemView.windowID)
            NSApp.activate()
        }
        Divider()
        #endif
        Button("Quit Pluck") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
