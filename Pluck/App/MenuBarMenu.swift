import SwiftUI

/// The menu bar item: the way in when a full-screen app hides the notch.
struct MenuBarMenu: View {
    let library: ShotLibrary?

    var body: some View {
        Button("Copy Latest Screenshot") {
            if let library, let latest = library.shots.first { library.copy([latest.id]) }
        }
        .disabled(library?.shots.isEmpty ?? true)
        Divider()
        Button("Quit Pluck") { NSApp.terminate(nil) }
            .keyboardShortcut("q")
    }
}
