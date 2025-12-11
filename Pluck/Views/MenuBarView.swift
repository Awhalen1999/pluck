//
//  MenuBarView.swift
//  Pluck
//

import SwiftUI

struct MenuBarView: View {
    var body: some View {

   
        
        Button("Quit") {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}

#Preview {
    MenuBarView()
}
