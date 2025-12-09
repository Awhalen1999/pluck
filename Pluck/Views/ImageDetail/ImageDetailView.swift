//
//  ImageDetailView.swift
//  Pluck
//

import SwiftUI

struct ImageDetailView: View {
    let image: DesignImage
    
    @Environment(WindowManager.self) private var windowManager
    @Environment(\.modelContext) private var modelContext
    
    @State private var fullImage: NSImage?
    @State private var isHoveringDelete = false
    
    var body: some View {
        VStack(spacing: 0) {
            header
            
            Divider()
                .background(Theme.border)
            
            imageContent
            
            if let sourceURL = image.sourceURL, !sourceURL.isEmpty {
                sourceURLBar(sourceURL)
            }
        }
        .onAppear {
            loadFullImage()
        }
    }
    
    // MARK: - Header
    
    private var header: some View {
        HStack {
            CircleButton.back { windowManager.goBack() }
            
            Text(image.originalName)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)
                .padding(.leading, 8)
            
            Spacer()
            
            deleteButton
            
            CircleButton.close { windowManager.collapse() }
        }
        .padding(.horizontal, PanelDimensions.contentPadding)
        .padding(.top, PanelDimensions.contentPadding)
        .padding(.bottom, 8)
    }
    
    private var deleteButton: some View {
        Button(action: deleteImage) {
            Image(systemName: "trash")
                .font(.system(size: 12))
                .foregroundStyle(isHoveringDelete ? .red : Theme.textSecondary)
        }
        .buttonStyle(.plain)
        .onHover { isHoveringDelete = $0 }
        .padding(.trailing, 8)
    }
    
    // MARK: - Image Content
    
    @ViewBuilder
    private var imageContent: some View {
        if let fullImage = fullImage {
            Image(nsImage: fullImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(PanelDimensions.contentPadding)
                .onDrag {
                    NSItemProvider(object: fullImage)
                }
        } else {
            Spacer()
            ProgressView()
                .scaleEffect(0.8)
            Spacer()
        }
    }
    
    // MARK: - Source URL Bar
    
    private func sourceURLBar(_ urlString: String) -> some View {
        VStack(spacing: 0) {
            Divider()
                .background(Theme.border)
            
            HStack {
                Image(systemName: "link")
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                
                Text(urlString)
                    .font(.system(size: 10))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                
                Spacer()
                
                Button(action: { copyToClipboard(urlString) }) {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 10))
                        .foregroundStyle(Theme.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, PanelDimensions.contentPadding + 4)
            .padding(.vertical, 10)
        }
    }
    
    // MARK: - Actions
    
    private func loadFullImage() {
        DispatchQueue.global(qos: .userInitiated).async {
            let loaded = FileManagerHelper.loadImage(filename: image.filename)
            DispatchQueue.main.async {
                self.fullImage = loaded
            }
        }
    }
    
    private func deleteImage() {
        FileManagerHelper.deleteImage(filename: image.filename)
        modelContext.delete(image)
        windowManager.goBack()
    }
    
    private func copyToClipboard(_ string: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(string, forType: .string)
    }
}

// MARK: - Preview

#Preview {
    let image = DesignImage(filename: "test.png", originalName: "Test Image")
    return ImageDetailView(image: image)
        .environment(WindowManager())
        .modelContainer(for: [DesignFolder.self, DesignImage.self])
        .frame(width: 340, height: 400)
        .background(Theme.backgroundSolid)
}
