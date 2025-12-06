//
//  PluckApp.swift
//  Pluck
//

import SwiftUI
import SwiftData

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Pluck", systemImage: "square.stack.3d.up.fill") {
            MenuBarView()
        }
        .menuBarExtraStyle(.menu)
        
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide from dock
        NSApp.setActivationPolicy(.accessory)
        
        // Show floating panel
        FloatingPanelController.shared.showPanel()
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }
}
