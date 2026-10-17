import SwiftUI

/// The menu bar item: the way in when a full-screen app hides the notch.
struct MenuBarMenu: View {
    let library: ShotLibrary?
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("Copy Latest Screenshot") {
            if let library, let latest = library.shots.first { library.copy([latest.id]) }
        }
        .disabled(library?.shots.isEmpty ?? true)
        Divider()
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
