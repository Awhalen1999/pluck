//
//  PluckApp.swift
//  Pluck
//
//  Application entry point with proper lifecycle management.
//

import SwiftUI

// MARK: - App Entry Point

@main
struct PluckApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Pluck", systemImage: "square.stack.3d.up.fill") {
            MenuBarView()
                .environment(FloatingPanelController.shared.windowManager)
        }
        .menuBarExtraStyle(.menu)
        
        // Empty settings window (required for menu bar apps)
        Settings {
            EmptyView()
        }
    }
}

// MARK: - App Delegate

final class AppDelegate: NSObject, NSApplicationDelegate {
    
    // MARK: - Lifecycle
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        Log.info("Application launched", subsystem: .app)
        
        // Configure as accessory app (no dock icon)
        NSApp.setActivationPolicy(.accessory)
        
        // Show the floating panel
        FloatingPanelController.shared.showPanel()
        
        Log.info("Floating panel displayed", subsystem: .app)
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        Log.info("Application terminating", subsystem: .app)
    }
    
    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        // Menu bar apps should not quit when windows close
        false
    }
    
    // MARK: - Reopen Handling
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Show panel if app is reopened
        if !flag {
            FloatingPanelController.shared.showPanel()
        }
        return true
    }
}
