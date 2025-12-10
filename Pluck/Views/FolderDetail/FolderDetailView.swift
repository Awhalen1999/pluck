//
//  FolderDetailView.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI

/// Public wrapper for the folder detail state
struct FolderDetailView: View {
    let folder: DesignFolder
    
    var body: some View {
        FolderDetailBody(folder: folder)
    }
}

// MARK: - Preview

#Preview {
    // Preview requires a sample folder
    FolderDetailView(folder: DesignFolder(name: "Sample", colorHex: "#FF6B6B", sortOrder: 0))
        .environment(WindowManager())
        .environment(ClipboardWatcher())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 220, height: 400)
        .background(Theme.backgroundSolid)
}
