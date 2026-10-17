import SwiftUI

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        MenuBarExtra("Pluck", systemImage: "camera.viewfinder") {
            Button("Quit Pluck") { NSApp.terminate(nil) }
                .keyboardShortcut("q")
        }
    }
}
