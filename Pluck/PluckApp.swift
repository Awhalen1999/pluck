//
//  PluckApp.swift
//  Pluck
//

import SwiftUI

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Pluck", systemImage: "square.stack.3d.up.fill") {
            MenuBarView()
                .environment(FloatingPanelController.shared.windowManager)
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        FloatingPanelController.shared.showPanel()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
