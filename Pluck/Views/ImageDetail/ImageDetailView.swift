//
//  ImageDetailView.swift
//  Pluck
//
//  Created by Alex Whalen on 2025-12-10.
//

import SwiftUI

/// Public wrapper for the image detail state
struct ImageDetailView: View {
    let image: DesignImage
    
    var body: some View {
        ImageDetailBody(image: image)
    }
}

// MARK: - Preview

#Preview {
    // Preview requires a sample image
    ImageDetailView(image: DesignImage(
        filename: "sample.png",
        originalName: "Sample Image",
        sortOrder: 0,
        folder: DesignFolder(name: "Sample", colorHex: "#FF6B6B", sortOrder: 0)
    ))
    .environment(WindowManager())
    .modelContainer(for: [DesignFolder.self, DesignImage.self])
    .frame(width: 340, height: 450)
    .background(Theme.backgroundSolid)
}
