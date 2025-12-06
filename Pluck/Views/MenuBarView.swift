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
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    MenuBarView()
}
