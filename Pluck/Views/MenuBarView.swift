//
//  MenuBarView.swift
//  Pluck
//

import SwiftUI

struct MenuBarView: View {
    @Environment(WindowManager.self) private var windowManager
    
    var body: some View {
        // Side switch
        Button(action: toggleSide) {
            Label(
                windowManager.dockedEdge == .right ? "Move to Left" : "Move to Right",
                systemImage: windowManager.dockedEdge == .right ? "rectangle.lefthalf.inset.filled" : "rectangle.righthalf.inset.filled"
            )
        }
        
        Divider()
        
        // Show/Hide panel
        Button(action: togglePanel) {
            Label("Toggle Panel", systemImage: "sidebar.right")
        }
        .keyboardShortcut("\\", modifiers: .command)
        
        Divider()
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
    
    private func toggleSide() {
        let newEdge: DockedEdge = windowManager.dockedEdge == .right ? .left : .right
        windowManager.setDockedEdge(newEdge)
    }
    
    private func togglePanel() {
        FloatingPanelController.shared.togglePanel()
    }
}

#Preview {
    MenuBarView()
        .environment(WindowManager())
}
