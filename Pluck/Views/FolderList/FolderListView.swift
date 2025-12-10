//
//  FolderListView.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI

/// Public wrapper for the folder list state
struct FolderListView: View {
    var body: some View {
        FolderListBody()
    }
}

// MARK: - Preview

#Preview {
    FolderListView()
        .environment(WindowManager())
        .environment(ClipboardWatcher())
        .environment(PasteController(windowManager: WindowManager(), clipboardWatcher: ClipboardWatcher()))
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 400)
        .background(Theme.backgroundSolid)
}
