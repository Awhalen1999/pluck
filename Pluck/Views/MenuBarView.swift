//
//  MenuBarView.swift
//  Pluck
//
import SwiftUI

struct MenuBarView: View {
    var body: some View {
        Button("Show/Hide Pluck") {
            FloatingPanelController.shared.togglePanel()
        }
        .keyboardShortcut("p", modifiers: [.command, .shift])
        
        Divider()
        
        Button("Switch Side") {
            let current = FloatingPanelController.shared.windowManager.dockedEdge
            FloatingPanelController.shared.windowManager.setDockedEdge(current == .right ? .left : .right)
        }
        
        Divider()
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    MenuBarView()
}
